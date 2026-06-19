CREATE INDEX IF NOT EXISTS idx_jackpot_tickets_user_spent ON jackpot_tickets (user_id, spent);
CREATE INDEX IF NOT EXISTS idx_jackpot_draws_user_matched ON jackpot_draws (user_id, matched_user_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_id ON blocks (blocked_id);
CREATE INDEX IF NOT EXISTS idx_ticket_gifts_from_created ON ticket_gifts (from_user_id, created_at);
