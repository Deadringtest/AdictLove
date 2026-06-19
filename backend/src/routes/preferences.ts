import { Router } from 'express';
import { pool } from '../db';
import { AuthedRequest, requireAuth } from '../auth';

const router = Router();

const VALID_INTERESTED_IN = ['everyone', 'men', 'women'];
const VALID_LOOKING_FOR = ['unsure', 'casual', 'serious', 'friends'];
const MIN_AGE_FLOOR = 18;
const MAX_AGE_CEILING = 100;
const MAX_DISTANCE_CEILING_KM = 20000;

router.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const result = await pool.query('SELECT * FROM preferences WHERE user_id = $1', [req.userId]);
  res.json(result.rows[0] ?? null);
});

router.put('/', requireAuth, async (req: AuthedRequest, res) => {
  const { interestedIn, minAge, maxAge, maxDistanceKm, lookingFor } = req.body;

  if (!VALID_INTERESTED_IN.includes(interestedIn)) {
    return res.status(400).json({ error: 'Invalid interestedIn value' });
  }
  if (!VALID_LOOKING_FOR.includes(lookingFor)) {
    return res.status(400).json({ error: 'Invalid lookingFor value' });
  }
  if (
    !Number.isInteger(minAge) || !Number.isInteger(maxAge) ||
    minAge < MIN_AGE_FLOOR || maxAge > MAX_AGE_CEILING || minAge > maxAge
  ) {
    return res.status(400).json({ error: 'Invalid age range' });
  }
  if (!Number.isFinite(maxDistanceKm) || maxDistanceKm < 0 || maxDistanceKm > MAX_DISTANCE_CEILING_KM) {
    return res.status(400).json({ error: 'Invalid distance' });
  }

  const result = await pool.query(
    `UPDATE preferences SET interested_in = $1, min_age = $2, max_age = $3, max_distance_km = $4, looking_for = $5
     WHERE user_id = $6 RETURNING *`,
    [interestedIn, minAge, maxAge, maxDistanceKm, lookingFor, req.userId]
  );
  res.json(result.rows[0]);
});

export default router;
