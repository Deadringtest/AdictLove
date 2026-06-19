import { Router } from 'express';
import { PoolClient } from 'pg';
import { pool } from '../db';
import { AuthedRequest, requireAdmin, requireAuth } from '../auth';
import { sendToUser } from '../ws';

const router = Router();

const DAILY_TICKET_CAP = 5;
const BASE_DAILY_TICKETS = 3;
const MAX_AD_TICKETS_PER_DAY = 3;
const STREAK_MILESTONES = [7, 30, 100];
const MILESTONE_BONUS_TICKETS = 2;

router.get('/tickets', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    'SELECT COUNT(*) FROM jackpot_tickets WHERE user_id = $1 AND spent = false',
    [req.userId]
  );
  res.json({ tickets: Number(result.rows[0].count) });
});

// Admin-only manual grant, kept around for support/seeding. Regular players
// get tickets through the daily claim below.
router.post('/tickets/grant', requireAuth, requireAdmin, async (req: AuthedRequest, res) => {
  const targetUserId = req.body.userId ?? req.userId;
  await pool.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [targetUserId]);
  res.status(201).json({ granted: 1 });
});

router.post('/tickets/claim-daily', requireAuth, async (req: AuthedRequest, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const user = await client.query(
      'SELECT ticket_streak, last_ticket_claim, last_streak_milestone FROM users WHERE id = $1 FOR UPDATE',
      [req.userId]
    );
    const { ticket_streak: streak, last_ticket_claim: lastClaim, last_streak_milestone: lastMilestone } = user.rows[0];

    const today = await client.query<{ today: string; isSameDay: boolean; isYesterday: boolean }>(
      `SELECT CURRENT_DATE::text AS today,
              ($1::date = CURRENT_DATE) AS "isSameDay",
              ($1::date = CURRENT_DATE - INTERVAL '1 day') AS "isYesterday"`,
      [lastClaim]
    );
    const { isSameDay, isYesterday } = today.rows[0];

    if (isSameDay) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Already claimed today' });
    }

    const newStreak = isYesterday ? streak + 1 : 1;
    const unspent = await client.query(
      'SELECT COUNT(*) FROM jackpot_tickets WHERE user_id = $1 AND spent = false',
      [req.userId]
    );
    const wanted = BASE_DAILY_TICKETS + Math.floor(newStreak / 3);
    const toGrant = Math.max(0, Math.min(wanted, DAILY_TICKET_CAP - Number(unspent.rows[0].count)));

    for (let i = 0; i < toGrant; i++) {
      await client.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [req.userId]);
    }

    const milestone = STREAK_MILESTONES.find((m) => newStreak >= m && lastMilestone < m);
    let milestoneBonus = 0;
    if (milestone) {
      milestoneBonus = MILESTONE_BONUS_TICKETS;
      for (let i = 0; i < milestoneBonus; i++) {
        await client.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [req.userId]);
      }
    }

    await client.query(
      'UPDATE users SET ticket_streak = $1, last_ticket_claim = CURRENT_DATE, last_streak_milestone = $2 WHERE id = $3',
      [newStreak, milestone ?? lastMilestone, req.userId]
    );

    await client.query('COMMIT');
    res.json({ granted: toGrant + milestoneBonus, streak: newStreak, milestone: milestone ?? null });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// Rewarded ad: client confirms an ad finished playing, server grants one
// ticket, capped per day and independent of the daily-claim streak.
router.post('/tickets/watch-ad', requireAuth, async (req: AuthedRequest, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const user = await client.query(
      `SELECT ad_tickets_claimed_today,
              (last_ad_ticket_date IS NULL OR last_ad_ticket_date < CURRENT_DATE) AS "isNewDay"
       FROM users WHERE id = $1 FOR UPDATE`,
      [req.userId]
    );
    const { ad_tickets_claimed_today: claimedToday, isNewDay } = user.rows[0];
    const claimedSoFar = isNewDay ? 0 : claimedToday;

    if (claimedSoFar >= MAX_AD_TICKETS_PER_DAY) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Daily ad ticket limit reached' });
    }

    await client.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [req.userId]);
    await client.query(
      'UPDATE users SET ad_tickets_claimed_today = $1, last_ad_ticket_date = CURRENT_DATE WHERE id = $2',
      [claimedSoFar + 1, req.userId]
    );

    await client.query('COMMIT');
    res.json({ granted: 1, remainingToday: MAX_AD_TICKETS_PER_DAY - (claimedSoFar + 1) });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// Weighted-random pick: shared categories raise the odds (more "luck") without
// making the draw deterministic, via the standard -ln(random())/weight trick.
// When `boosted`, the pool is narrowed to people who share at least one
// category (if any such candidates exist) before the weighted draw runs.
async function pickCandidate(
  client: PoolClient,
  userId: number,
  pref: { interested_in?: string; min_age?: number; max_age?: number } | undefined,
  boosted: boolean
) {
  const eligible = await client.query(
    `SELECT u.id,
            COALESCE((SELECT COUNT(*) FROM user_categories mine
                      JOIN user_categories theirs ON theirs.category_id = mine.category_id
                      WHERE mine.user_id = $1 AND theirs.user_id = u.id), 0) AS shared_categories
     FROM users u
     LEFT JOIN jackpot_draws d ON d.user_id = $1 AND d.matched_user_id = u.id
     WHERE u.id != $1
       AND ($2 = 'everyone' OR u.gender = $2)
       AND date_part('year', age(u.birthdate)) BETWEEN $3 AND $4
       AND d.id IS NULL
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = $1 AND b.blocked_id = u.id)
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = u.id AND b.blocked_id = $1)`,
    [userId, pref?.interested_in ?? 'everyone', pref?.min_age ?? 18, pref?.max_age ?? 99]
  );

  let pool_ = eligible.rows;
  if (boosted) {
    const shared = pool_.filter((row) => row.shared_categories > 0);
    if (shared.length > 0) pool_ = shared;
  }
  if (pool_.length === 0) return null;


  let best = pool_[0];
  let bestScore = Infinity;
  for (const row of pool_) {
    const score = -Math.log(Math.random()) / (1 + 3 * row.shared_categories);
    if (score < bestScore) {
      bestScore = score;
      best = row;
    }
  }
  return { id: best.id as number, sharedCategories: Number(best.shared_categories) };
}

async function spendTickets(client: PoolClient, userId: number, count: number) {
  const tickets = await client.query(
    `SELECT id FROM jackpot_tickets WHERE user_id = $1 AND spent = false LIMIT $2 FOR UPDATE`,
    [userId, count]
  );
  if (tickets.rows.length < count) return false;
  await client.query(
    'UPDATE jackpot_tickets SET spent = true WHERE id = ANY($1::int[])',
    [tickets.rows.map((r) => r.id)]
  );
  return true;
}

async function performSpin(req: AuthedRequest, res: import('express').Response, cost: number, boosted: boolean) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const spent = await spendTickets(client, req.userId!, cost);
    if (!spent) {
      await client.query('ROLLBACK');
      return res.status(402).json({ error: 'Not enough jackpot tickets available' });
    }

    const prefs = await client.query('SELECT * FROM preferences WHERE user_id = $1', [req.userId]);
    const picked = await pickCandidate(client, req.userId!, prefs.rows[0], boosted);

    if (picked === null) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No new matches available right now' });
    }
    const { id: matchedUserId, sharedCategories } = picked;

    await client.query(
      'INSERT INTO jackpot_draws (user_id, matched_user_id) VALUES ($1, $2)',
      [req.userId, matchedUserId]
    );

    const profile = await client.query(
      `SELECT u.id, u.display_name, u.bio, u.verification_status,
              (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo
       FROM users u WHERE u.id = $1`,
      [matchedUserId]
    );

    const prompt = await client.query(
      `SELECT p.text AS prompt, up.answer FROM user_prompts up
       JOIN prompts p ON p.id = up.prompt_id
       WHERE up.user_id = $1 ORDER BY up.position LIMIT 1`,
      [matchedUserId]
    );

    const decoys = await client.query(
      `SELECT u.id, u.display_name,
              (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo
       FROM users u
       WHERE u.id != $1 AND u.id != $2
         AND EXISTS (SELECT 1 FROM photos WHERE user_id = u.id)
         AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = $1 AND b.blocked_id = u.id)
         AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = u.id AND b.blocked_id = $1)
       ORDER BY random()
       LIMIT 6`,
      [req.userId, matchedUserId]
    );

    await client.query('COMMIT');
    res.json({
      result: { ...profile.rows[0], prompt: prompt.rows[0] ?? null },
      decoys: decoys.rows,
      sharedCategories,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

router.post('/spin', requireAuth, (req: AuthedRequest, res) => performSpin(req, res, 1, false));

// Boost: spend 2 tickets to draw from a pool narrowed to shared interests
// (when any exist) -- still luck, but better odds with people who like what you like.
router.post('/spin/boost', requireAuth, (req: AuthedRequest, res) => performSpin(req, res, 2, true));

router.post('/spin/:resultUserId/like', requireAuth, async (req: AuthedRequest, res) => {
  const otherUserId = Number(req.params.resultUserId);
  const wantsMega = req.body.mega === true;

  let mega = false;
  if (wantsMega) {
    const user = await pool.query(
      `SELECT (last_mega_like_at IS NULL OR last_mega_like_at < CURRENT_DATE) AS available
       FROM users WHERE id = $1`,
      [req.userId]
    );
    if (user.rows[0]?.available) {
      mega = true;
      await pool.query('UPDATE users SET last_mega_like_at = CURRENT_DATE WHERE id = $1', [req.userId]);
      await pool.query(
        'UPDATE jackpot_draws SET mega_like = true WHERE user_id = $1 AND matched_user_id = $2',
        [req.userId, otherUserId]
      );
      await pool.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [otherUserId]);
      const me = await pool.query('SELECT display_name FROM users WHERE id = $1', [req.userId]);
      sendToUser(otherUserId, 'mega_like', { fromUserId: req.userId, displayName: me.rows[0].display_name });
    }
  }

  const reciprocal = await pool.query(
    `SELECT 1 FROM jackpot_draws WHERE user_id = $1 AND matched_user_id = $2`,
    [otherUserId, req.userId]
  );

  if (reciprocal.rows.length > 0) {
    const [a, b] = [req.userId!, otherUserId].sort((x, y) => x - y);
    const inserted = await pool.query(
      `INSERT INTO matches (user_a_id, user_b_id, mega_match) VALUES ($1, $2, $3)
       ON CONFLICT DO NOTHING RETURNING id`,
      [a, b, mega]
    );
    if (inserted.rows.length > 0) {
      const matchId = inserted.rows[0].id;
      const me = await pool.query(
        `SELECT display_name, (SELECT file_path FROM photos WHERE user_id = $1 ORDER BY position LIMIT 1) AS photo
         FROM users WHERE id = $1`,
        [req.userId]
      );
      sendToUser(otherUserId, 'match', { matchId, ...me.rows[0] });
    }
    return res.json({ mutualMatch: true, mega });
  }

  // Not mutual yet -- nudge the liked person to come spin, without revealing
  // who liked them (keeps the luck-based reveal intact on their side too).
  sendToUser(otherUserId, 'admirer_waiting', {});
  res.json({ mutualMatch: false, mega });
});

export default router;
