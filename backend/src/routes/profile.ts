import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import crypto from 'crypto';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';

const router = Router();
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');

const storage = multer.diskStorage({
  destination: UPLOAD_DIR,
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!/^image\/(jpeg|png|webp)$/.test(file.mimetype)) {
      return cb(new Error('Only JPEG, PNG, or WEBP images are allowed'));
    }
    cb(null, true);
  },
});

router.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const user = await pool.query(
    `SELECT id, email, display_name, birthdate, gender, pronouns, bio, email_verified, verification_status
     FROM users WHERE id = $1`,
    [req.userId]
  );
  const photos = await pool.query(
    'SELECT id, file_path, position FROM photos WHERE user_id = $1 ORDER BY position',
    [req.userId]
  );
  const categories = await pool.query(
    `SELECT c.id, c.name FROM categories c
     JOIN user_categories uc ON uc.category_id = c.id
     WHERE uc.user_id = $1`,
    [req.userId]
  );
  res.json({ ...user.rows[0], photos: photos.rows, categories: categories.rows });
});

router.put('/', requireAuth, async (req: AuthedRequest, res) => {
  const { bio, pronouns } = req.body;
  const result = await pool.query(
    `UPDATE users SET bio = $1, pronouns = $2 WHERE id = $3
     RETURNING id, display_name, bio, pronouns`,
    [bio ?? null, pronouns ?? null, req.userId]
  );
  res.json(result.rows[0]);
});

router.post('/photos', requireAuth, upload.single('photo'), async (req: AuthedRequest, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No photo uploaded' });
  }
  const count = await pool.query('SELECT COUNT(*) FROM photos WHERE user_id = $1', [req.userId]);
  const result = await pool.query(
    'INSERT INTO photos (user_id, file_path, position) VALUES ($1, $2, $3) RETURNING id, file_path, position',
    [req.userId, `/uploads/${req.file.filename}`, Number(count.rows[0].count)]
  );
  res.status(201).json(result.rows[0]);
});

router.delete('/photos/:id', requireAuth, async (req: AuthedRequest, res) => {
  await pool.query('DELETE FROM photos WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
  res.status(204).end();
});

router.post('/verification', requireAuth, upload.single('photo'), async (req: AuthedRequest, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No verification photo uploaded' });
  }
  const result = await pool.query(
    `UPDATE users SET verification_photo = $1, verification_status = 'pending'
     WHERE id = $2 RETURNING id, verification_status`,
    [`/uploads/${req.file.filename}`, req.userId]
  );
  res.status(201).json(result.rows[0]);
});

router.put('/categories', requireAuth, async (req: AuthedRequest, res) => {
  const { categoryIds } = req.body;
  if (!Array.isArray(categoryIds)) {
    return res.status(400).json({ error: 'categoryIds must be an array' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM user_categories WHERE user_id = $1', [req.userId]);
    for (const categoryId of categoryIds) {
      await client.query(
        `INSERT INTO user_categories (user_id, category_id)
         SELECT $1, id FROM categories WHERE id = $2 AND status = 'approved'`,
        [req.userId, categoryId]
      );
    }
    await client.query('COMMIT');
    res.json({ updated: true });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

router.get('/completion', requireAuth, async (req: AuthedRequest, res) => {
  const user = await pool.query(
    'SELECT email_verified, bio FROM users WHERE id = $1',
    [req.userId]
  );
  const photoCount = await pool.query('SELECT COUNT(*) FROM photos WHERE user_id = $1', [req.userId]);
  const categoryCount = await pool.query(
    'SELECT COUNT(*) FROM user_categories WHERE user_id = $1',
    [req.userId]
  );

  res.json({
    emailVerified: user.rows[0].email_verified,
    hasPhoto: Number(photoCount.rows[0].count) > 0,
    hasBio: !!user.rows[0].bio,
    hasCategory: Number(categoryCount.rows[0].count) > 0,
    complete:
      user.rows[0].email_verified &&
      Number(photoCount.rows[0].count) > 0,
  });
});

export default router;
