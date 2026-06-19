ALTER TABLE users ADD COLUMN ad_tickets_claimed_today INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN last_ad_ticket_date DATE;
