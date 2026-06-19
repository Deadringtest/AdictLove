import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query('SELECT * FROM preferences WHERE user_id = $1', [req.userId]);
  res.json(result.rows[0] ?? null);
});

router.put('/', requireAuth, async (req: AuthedRequest, res) => {
  const { interestedIn, minAge, maxAge, maxDistanceKm, lookingFor } = req.body;
  const result = await pool.query(
    `UPDATE preferences SET interested_in = $1, min_age = $2, max_age = $3, max_distance_km = $4, looking_for = $5
     WHERE user_id = $6 RETURNING *`,
    [interestedIn, minAge, maxAge, maxDistanceKm, lookingFor, req.userId]
  );
  res.json(result.rows[0]);
});

export default router;
