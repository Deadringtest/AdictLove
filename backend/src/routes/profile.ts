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
  const prompts = await pool.query(
    `SELECT up.id, up.prompt_id, p.text AS prompt, up.answer
     FROM user_prompts up JOIN prompts p ON p.id = up.prompt_id
     WHERE up.user_id = $1 ORDER BY up.position`,
    [req.userId]
  );
  res.json({ ...user.rows[0], photos: photos.rows, categories: categories.rows, prompts: prompts.rows });
});

router.get('/prompts', requireAuth, async (_req, res) => {
  const result = await pool.query('SELECT id, text FROM prompts ORDER BY id');
  res.json(result.rows);
});

router.put('/prompts', requireAuth, async (req: AuthedRequest, res) => {
  const { answers } = req.body as { answers: { promptId: number; answer: string }[] };
  if (!Array.isArray(answers) || answers.length > 3) {
    return res.status(400).json({ error: 'Provide up to 3 prompt answers' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM user_prompts WHERE user_id = $1', [req.userId]);
    for (let i = 0; i < answers.length; i++) {
      const { promptId, answer } = answers[i];
      const trimmed = (answer ?? '').trim();
      if (!trimmed) continue;
      await client.query(
        'INSERT INTO user_prompts (user_id, prompt_id, answer, position) VALUES ($1, $2, $3, $4)',
        [req.userId, promptId, trimmed, i]
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

const VERIFICATION_POSES = [
  'Hold up 2 fingers next to your face',
  'Give a thumbs up next to your face',
  'Touch your nose with one hand',
  'Hold up 3 fingers next to your face',
];

// Liveness check: ask for a random pose before the selfie is taken, so a
// recycled/stolen photo can't be reused for verification. The admin review
// step (in admin.ts) checks the submitted photo against this stored pose.
router.get('/verification/pose', requireAuth, async (req: AuthedRequest, res) => {
  const pose = VERIFICATION_POSES[Math.floor(Math.random() * VERIFICATION_POSES.length)];
  await pool.query('UPDATE users SET verification_pose = $1 WHERE id = $2', [pose, req.userId]);
  res.json({ pose });
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
