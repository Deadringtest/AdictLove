import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';
import { sendToUser } from '../ws';

const router = Router();

async function getMatchIfParticipant(matchId: string, userId: number) {
  const result = await pool.query(
    'SELECT * FROM matches WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2)',
    [matchId, userId]
  );
  return result.rows[0] ?? null;
}

router.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    `SELECT m.id AS match_id, m.created_at,
            u.id AS user_id, u.display_name,
            (SELECT file_path FROM photos WHERE user_id = u.id ORDER BY position LIMIT 1) AS photo,
            (SELECT body FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1) AS last_message,
            (SELECT created_at FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1) AS last_message_at
     FROM matches m
     JOIN users u ON u.id = (CASE WHEN m.user_a_id = $1 THEN m.user_b_id ELSE m.user_a_id END)
     WHERE m.user_a_id = $1 OR m.user_b_id = $1
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
    'SELECT id, sender_id, body, created_at FROM messages WHERE match_id = $1 ORDER BY created_at',
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
    'INSERT INTO messages (match_id, sender_id, body) VALUES ($1, $2, $3) RETURNING id, sender_id, body, created_at',
    [req.params.id, req.userId, body]
  );

  const message = result.rows[0];
  const recipientId = match.user_a_id === req.userId ? match.user_b_id : match.user_a_id;
  sendToUser(recipientId, 'message', { matchId: match.id, ...message });

  res.status(201).json(message);
});

export default router;
