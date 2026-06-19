import { Router } from 'express';
import bcrypt from 'bcrypt';
import { pool } from '../db';
import { signToken } from '../auth';

const router = Router();

router.post('/register', async (req, res) => {
  const { email, password, displayName, birthdate, gender } = req.body;
  if (!email || !password || !displayName || !birthdate || !gender) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const age = Math.floor((Date.now() - new Date(birthdate).getTime()) / (365.25 * 24 * 60 * 60 * 1000));
  if (age < 18) {
    return res.status(403).json({ error: 'Must be 18 or older to register' });
  }

  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    return res.status(409).json({ error: 'Email already registered' });
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const result = await pool.query(
    `INSERT INTO users (email, password_hash, display_name, birthdate, gender)
     VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [email, passwordHash, displayName, birthdate, gender]
  );
  const userId = result.rows[0].id;
  await pool.query(
    `INSERT INTO preferences (user_id, interested_in) VALUES ($1, $2)`,
    [userId, 'everyone']
  );

  res.status(201).json({ token: signToken(userId) });
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Missing credentials' });
  }

  const result = await pool.query('SELECT id, password_hash FROM users WHERE email = $1', [email]);
  const user = result.rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  res.json({ token: signToken(user.id) });
});

export default router;
