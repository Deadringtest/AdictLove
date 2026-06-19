import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { pool } from './db';

const JWT_SECRET = process.env.JWT_SECRET as string;

export interface AuthedRequest extends Request {
  userId?: number;
}

export function signToken(userId: number): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '30d' });
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing token' });
  }
  try {
    const payload = jwt.verify(header.slice(7), JWT_SECRET) as { userId: number };
    req.userId = payload.userId;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

export async function requireAdmin(req: AuthedRequest, res: Response, next: NextFunction) {
  const result = await pool.query('SELECT is_admin FROM users WHERE id = $1', [req.userId]);
  if (!result.rows[0]?.is_admin) {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}
