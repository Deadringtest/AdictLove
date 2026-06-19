import { Router } from 'express';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import { pool } from '../db';
import { signToken } from '../auth';
import { sendVerificationEmail } from '../email';

const router = Router();
const VERIFICATION_TTL_MINUTES = 15;

async function createAndSendVerificationCode(userId: number, email: string) {
  const code = crypto.randomInt(100000, 999999).toString();
  const expiresAt = new Date(Date.now() + VERIFICATION_TTL_MINUTES * 60 * 1000);
  await pool.query(
    'INSERT INTO email_verifications (user_id, code, expires_at) VALUES ($1, $2, $3)',
    [userId, code, expiresAt]
  );
  await sendVerificationEmail(email, code);
}

router.post('/register', async (req, res) => {
  const { email, password, displayName, birthdate, gender, pronouns } = req.body;
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
    `INSERT INTO users (email, password_hash, display_name, birthdate, gender, pronouns)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [email, passwordHash, displayName, birthdate, gender, pronouns ?? null]
  );
  const userId = result.rows[0].id;
  await pool.query(
    `INSERT INTO preferences (user_id, interested_in) VALUES ($1, $2)`,
    [userId, 'everyone']
  );

  await createAndSendVerificationCode(userId, email);

  res.status(201).json({ token: signToken(userId), emailVerified: false });
});

router.post('/verify-email', async (req, res) => {
  const { email, code } = req.body;
  if (!email || !code) {
    return res.status(400).json({ error: 'Missing email or code' });
  }

  const user = await pool.query('SELECT id, email_verified FROM users WHERE email = $1', [email]);
  if (user.rows.length === 0) {
    return res.status(404).json({ error: 'User not found' });
  }
  if (user.rows[0].email_verified) {
    return res.json({ verified: true });
  }

  const verification = await pool.query(
    `SELECT id FROM email_verifications
     WHERE user_id = $1 AND code = $2 AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [user.rows[0].id, code]
  );
  if (verification.rows.length === 0) {
    return res.status(400).json({ error: 'Invalid or expired code' });
  }

  await pool.query('UPDATE users SET email_verified = true WHERE id = $1', [user.rows[0].id]);
  res.json({ verified: true });
});

router.post('/resend-verification', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Missing email' });
  }

  const user = await pool.query('SELECT id, email_verified FROM users WHERE email = $1', [email]);
  if (user.rows.length === 0) {
    return res.status(404).json({ error: 'User not found' });
  }
  if (user.rows[0].email_verified) {
    return res.json({ verified: true });
  }

  await createAndSendVerificationCode(user.rows[0].id, email);
  res.json({ sent: true });
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Missing credentials' });
  }

  const result = await pool.query(
    'SELECT id, password_hash, email_verified FROM users WHERE email = $1',
    [email]
  );
  const user = result.rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  res.json({ token: signToken(user.id), emailVerified: user.email_verified });
});

export default router;
