import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAdmin, requireAuth } from '../auth';

const router = Router();

router.get('/', requireAuth, async (_req, res) => {
  const result = await pool.query(
    `SELECT id, name FROM categories WHERE status = 'approved' ORDER BY name`
  );
  res.json(result.rows);
});

router.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const name = (req.body.name as string)?.trim();
  if (!name) {
    return res.status(400).json({ error: 'Category name is required' });
  }

  const existing = await pool.query('SELECT id, status FROM categories WHERE name ILIKE $1', [name]);
  if (existing.rows.length > 0) {
    return res.status(409).json({ error: 'Category already exists', category: existing.rows[0] });
  }

  const result = await pool.query(
    `INSERT INTO categories (name, status, created_by) VALUES ($1, 'pending', $2)
     RETURNING id, name, status`,
    [name, req.userId]
  );
  res.status(201).json(result.rows[0]);
});

router.get('/pending', requireAuth, requireAdmin, async (_req, res) => {
  const result = await pool.query(
    `SELECT id, name, created_by, created_at FROM categories WHERE status = 'pending' ORDER BY created_at`
  );
  res.json(result.rows);
});

router.post('/:id/approve', requireAuth, requireAdmin, async (req, res) => {
  const result = await pool.query(
    `UPDATE categories SET status = 'approved' WHERE id = $1 RETURNING id, name, status`,
    [req.params.id]
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
  res.json(result.rows[0]);
});

router.post('/:id/reject', requireAuth, requireAdmin, async (req, res) => {
  const result = await pool.query(
    `UPDATE categories SET status = 'rejected' WHERE id = $1 RETURNING id, name, status`,
    [req.params.id]
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
  res.json(result.rows[0]);
});

export default router;
