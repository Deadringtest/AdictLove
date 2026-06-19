import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';

const router = Router();
const MAX_REPORTS_PER_DAY = 5;

router.get('/:id/photos', requireAuth, async (req, res) => {
  const result = await pool.query(
    'SELECT id, file_path, position FROM photos WHERE user_id = $1 ORDER BY position',
    [req.params.id]
  );
  res.json(result.rows);
});

router.get('/blocked', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query(
    `SELECT u.id, u.display_name FROM blocks b
     JOIN users u ON u.id = b.blocked_id
     WHERE b.blocker_id = $1
     ORDER BY b.created_at DESC`,
    [req.userId]
  );
  res.json(result.rows);
});

router.post('/:id/block', requireAuth, async (req: AuthedRequest, res) => {
  const blockedId = Number(req.params.id);
  if (blockedId === req.userId) {
    return res.status(400).json({ error: 'Cannot block yourself' });
  }
  await pool.query(
    `INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [req.userId, blockedId]
  );
  res.status(201).json({ blocked: true });
});

router.delete('/:id/block', requireAuth, async (req: AuthedRequest, res) => {
  await pool.query('DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2', [
    req.userId,
    req.params.id,
  ]);
  res.status(204).end();
});

router.post('/:id/report', requireAuth, async (req: AuthedRequest, res) => {
  const reportedId = Number(req.params.id);
  const reason = (req.body.reason as string)?.trim();
  if (!reason) {
    return res.status(400).json({ error: 'A reason is required' });
  }
  if (reportedId === req.userId) {
    return res.status(400).json({ error: 'Cannot report yourself' });
  }
  const todayCount = await pool.query(
    `SELECT COUNT(*) FROM reports WHERE reporter_id = $1 AND created_at >= CURRENT_DATE`,
    [req.userId]
  );
  if (Number(todayCount.rows[0].count) >= MAX_REPORTS_PER_DAY) {
    return res.status(429).json({ error: 'Daily report limit reached' });
  }
  await pool.query('INSERT INTO reports (reporter_id, reported_id, reason) VALUES ($1, $2, $3)', [
    req.userId,
    reportedId,
    reason,
  ]);
  res.status(201).json({ reported: true });
});

export default router;
