import { Router } from 'express';
import { pool } from '../db';
import { requireAuth } from '../auth';

const router = Router();

router.get('/:id/photos', requireAuth, async (req, res) => {
  const result = await pool.query(
    'SELECT id, file_path, position FROM photos WHERE user_id = $1 ORDER BY position',
    [req.params.id]
  );
  res.json(result.rows);
});

export default router;
