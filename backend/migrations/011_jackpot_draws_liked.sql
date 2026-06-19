-- Tracks whether a draw has already been responded to via the like route,
-- so a single draw can't be liked/mega-liked more than once (the route now
-- requires this row to exist before processing a like at all).
ALTER TABLE jackpot_draws ADD COLUMN IF NOT EXISTS liked boolean NOT NULL DEFAULT false;
