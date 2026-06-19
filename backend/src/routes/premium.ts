import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../auth';

// PAUSED: premium tier is scaffolded (see `users.premium_until` in
// migrations/007) but intentionally not wired into index.ts or sold anywhere.
// Idea: cosmetic-only perks (extra accent colors, profile boost in discovery
// pool) so the luck mechanic stays fair. Mount this router and add a real
// payment provider integration when ready to launch it.
const router = Router();

router.get('/status', requireAuth, async (req: AuthedRequest, res) => {
  res.status(501).json({ error: 'Premium is not available yet' });
});

export default router;
