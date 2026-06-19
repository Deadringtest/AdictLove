import { Router } from 'express';
import { pool } from '../db';
import { requireAdmin, requireAuth } from '../auth';
import { parsePositiveInt } from '../validation';

const router = Router();

router.get('/verifications/pending', requireAuth, requireAdmin, async (_req, res) => {
  const result = await pool.query(
    `SELECT id, display_name, verification_photo, verification_pose FROM users WHERE verification_status = 'pending'`
  );
  res.json(result.rows);
});

router.post('/verifications/:userId/approve', requireAuth, requireAdmin, async (req, res) => {
  const userId = parsePositiveInt(req.params.userId);
  if (userId === null) {
    return res.status(400).json({ error: 'Invalid user id' });
  }
  const result = await pool.query(
    `UPDATE users SET verification_status = 'approved' WHERE id = $1 RETURNING id, display_name, verification_status`,
    [userId]
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
  res.json(result.rows[0]);
});

router.post('/verifications/:userId/reject', requireAuth, requireAdmin, async (req, res) => {
  const userId = parsePositiveInt(req.params.userId);
  if (userId === null) {
    return res.status(400).json({ error: 'Invalid user id' });
  }
  const result = await pool.query(
    `UPDATE users SET verification_status = 'rejected' WHERE id = $1 RETURNING id, display_name, verification_status`,
    [userId]
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
  res.json(result.rows[0]);
});

router.get('/reports', requireAuth, requireAdmin, async (_req, res) => {
  const result = await pool.query(
    `SELECT r.id, r.reason, r.created_at,
            reporter.display_name AS reporter_name,
            reported.display_name AS reported_name, reported.id AS reported_id
     FROM reports r
     JOIN users reporter ON reporter.id = r.reporter_id
     JOIN users reported ON reported.id = r.reported_id
     ORDER BY r.created_at DESC`
  );
  res.json(result.rows);
});

export default router;
