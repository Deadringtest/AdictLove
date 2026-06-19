import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';
import { sendToUser } from '../ws';

const router = Router();

async function getMatchIfParticipant(matchId: string, userId: number) {
  const result = await pool.query(
    `SELECT m.* FROM matches m
     WHERE m.id = $1 AND (m.user_a_id = $2 OR m.user_b_id = $2)
       AND NOT EXISTS (
         SELECT 1 FROM blocks b
         WHERE (b.blocker_id = $2 AND b.blocked_id = (CASE WHEN m.user_a_id = $2 THEN m.user_b_id ELSE m.user_a_id END))
            OR (b.blocked_id = $2 AND b.blocker_id = (CASE WHEN m.user_a_id = $2 THEN m.user_b_id ELSE m.user_a_id END))
       )`,
    [matchId, userId]
  );
  return result.rows[0] ?? null;
}

router.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    `SELECT m.id AS match_id, m.created_at, m.mega_match,
            u.id AS user_id, u.display_name,
            (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo,
            (SELECT body FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1) AS last_message,
            (SELECT created_at FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1) AS last_message_at,
            (SELECT COUNT(*) FROM messages
             WHERE match_id = m.id AND sender_id = u.id AND read_at IS NULL) AS unread_count
     FROM matches m
     JOIN users u ON u.id = (CASE WHEN m.user_a_id = $1 THEN m.user_b_id ELSE m.user_a_id END)
     WHERE (m.user_a_id = $1 OR m.user_b_id = $1)
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = $1 AND b.blocked_id = u.id)
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE b.blocker_id = u.id AND b.blocked_id = $1)
     ORDER BY COALESCE(
       (SELECT created_at FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1),
       m.created_at
     ) DESC`,
    [req.userId]
  );
  res.json(result.rows);
});

router.get('/:id/messages', requireAuth, async (req: AuthedRequest, res) => {
  const match = await getMatchIfParticipant(req.params.id, req.userId!);
  if (!match) {
    return res.status(404).json({ error: 'Match not found' });
  }

  const result = await pool.query(
    'SELECT id, sender_id, body, created_at, read_at FROM messages WHERE match_id = $1 ORDER BY created_at',
    [req.params.id]
  );
  res.json(result.rows);
});

router.post('/:id/messages', requireAuth, async (req: AuthedRequest, res) => {
  const match = await getMatchIfParticipant(req.params.id, req.userId!);
  if (!match) {
    return res.status(404).json({ error: 'Match not found' });
  }

  const body = (req.body.body as string)?.trim();
  if (!body) {
    return res.status(400).json({ error: 'Message body is required' });
  }

  const result = await pool.query(
    'INSERT INTO messages (match_id, sender_id, body) VALUES ($1, $2, $3) RETURNING id, sender_id, body, created_at, read_at',
    [req.params.id, req.userId, body]
  );

  const message = result.rows[0];
  const recipientId = match.user_a_id === req.userId ? match.user_b_id : match.user_a_id;
  sendToUser(recipientId, 'message', { matchId: match.id, ...message });

  res.status(201).json(message);
});

const MAX_GIFTS_PER_DAY = 3;

router.post('/:id/gift-ticket', requireAuth, async (req: AuthedRequest, res) => {
  const match = await getMatchIfParticipant(req.params.id, req.userId!);
  if (!match) {
    return res.status(404).json({ error: 'Match not found' });
  }
  const recipientId = match.user_a_id === req.userId ? match.user_b_id : match.user_a_id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const ticket = await client.query(
      'SELECT id FROM jackpot_tickets WHERE user_id = $1 AND spent = false ORDER BY id LIMIT 1 FOR UPDATE',
      [req.userId]
    );
    if (ticket.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(402).json({ error: 'No tickets to gift' });
    }

    const giftedToday = await client.query(
      'SELECT COUNT(*) FROM ticket_gifts WHERE from_user_id = $1 AND created_at >= CURRENT_DATE',
      [req.userId]
    );
    if (Number(giftedToday.rows[0].count) >= MAX_GIFTS_PER_DAY) {
      await client.query('ROLLBACK');
      return res.status(429).json({ error: 'Daily gift limit reached' });
    }

    await client.query('UPDATE jackpot_tickets SET spent = true WHERE id = $1', [ticket.rows[0].id]);
    await client.query('INSERT INTO jackpot_tickets (user_id) VALUES ($1)', [recipientId]);
    await client.query(
      'INSERT INTO ticket_gifts (from_user_id, to_user_id, match_id) VALUES ($1, $2, $3)',
      [req.userId, recipientId, match.id]
    );

    await client.query('COMMIT');
    const me = await pool.query('SELECT display_name FROM users WHERE id = $1', [req.userId]);
    sendToUser(recipientId, 'gift_ticket', { fromUserId: req.userId, displayName: me.rows[0].display_name });
    res.json({ gifted: true });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

router.post('/:id/read', requireAuth, async (req: AuthedRequest, res) => {
  const match = await getMatchIfParticipant(req.params.id, req.userId!);
  if (!match) {
    return res.status(404).json({ error: 'Match not found' });
  }

  const result = await pool.query(
    `UPDATE messages SET read_at = now()
     WHERE match_id = $1 AND sender_id != $2 AND read_at IS NULL
     RETURNING id, sender_id`,
    [req.params.id, req.userId]
  );

  if (result.rows.length > 0) {
    const senderId = match.user_a_id === req.userId ? match.user_b_id : match.user_a_id;
    sendToUser(senderId, 'read', { matchId: match.id, messageIds: result.rows.map((r) => r.id) });
  }

  res.json({ markedRead: result.rows.length });
});

export default router;
