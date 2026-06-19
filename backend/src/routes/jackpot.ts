import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';

const router = Router();

router.get('/tickets', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    'SELECT COUNT(*) FROM jackpot_tickets WHERE user_id = $1 AND spent = false',
    [req.userId]
  );
  res.json({ tickets: Number(result.rows[0].count) });
});

router.post('/tickets/grant', requireAuth, async (req: AuthedRequest, res) => {
  await pool.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [req.userId]);
  res.status(201).json({ granted: 1 });
});

router.post('/spin', requireAuth, async (req: AuthedRequest, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const ticket = await client.query(
      `SELECT id FROM jackpot_tickets WHERE user_id = $1 AND spent = false LIMIT 1 FOR UPDATE`,
      [req.userId]
    );
    if (ticket.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(402).json({ error: 'No jackpot tickets available' });
    }

    const prefs = await client.query('SELECT * FROM preferences WHERE user_id = $1', [req.userId]);
    const pref = prefs.rows[0];

    const candidates = await client.query(
      `SELECT u.id FROM users u
       LEFT JOIN jackpot_draws d ON d.user_id = $1 AND d.matched_user_id = u.id
       WHERE u.id != $1
         AND ($2 = 'everyone' OR u.gender = $2)
         AND date_part('year', age(u.birthdate)) BETWEEN $3 AND $4
         AND d.id IS NULL
       ORDER BY random()
       LIMIT 1`,
      [req.userId, pref?.interested_in ?? 'everyone', pref?.min_age ?? 18, pref?.max_age ?? 99]
    );

    if (candidates.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'No new matches available right now' });
    }

    const matchedUserId = candidates.rows[0].id;

    await client.query('UPDATE jackpot_tickets SET spent = true WHERE id = $1', [ticket.rows[0].id]);
    await client.query(
      'INSERT INTO jackpot_draws (user_id, matched_user_id) VALUES ($1, $2)',
      [req.userId, matchedUserId]
    );

    const profile = await client.query(
      `SELECT u.id, u.display_name, u.bio,
              (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo
       FROM users u WHERE u.id = $1`,
      [matchedUserId]
    );

    const decoys = await client.query(
      `SELECT u.id, u.display_name,
              (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo
       FROM users u
       WHERE u.id != $1 AND u.id != $2
         AND EXISTS (SELECT 1 FROM photos WHERE user_id = u.id)
       ORDER BY random()
       LIMIT 6`,
      [req.userId, matchedUserId]
    );

    await client.query('COMMIT');
    res.json({ result: profile.rows[0], decoys: decoys.rows });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

router.post('/spin/:resultUserId/like', requireAuth, async (req: AuthedRequest, res) => {
  const otherUserId = Number(req.params.resultUserId);
  const reciprocal = await pool.query(
    `SELECT 1 FROM jackpot_draws WHERE user_id = $1 AND matched_user_id = $2`,
    [otherUserId, req.userId]
  );

  if (reciprocal.rows.length > 0) {
    const [a, b] = [req.userId!, otherUserId].sort((x, y) => x - y);
    await pool.query(
      `INSERT INTO matches (user_a_id, user_b_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [a, b]
    );
    return res.json({ mutualMatch: true });
  }

  res.json({ mutualMatch: false });
});

export default router;
