# AdictLove

A dating/social app with a luck-based "Jackpot" match reveal: instead of (or alongside) swiping, users spend tickets to spin and reveal a potential match from people fitting their preferences. No real-money wagering — purely gamified.

## Structure

- `mobile/` — Flutter (Dart) app
- `backend/` — Node.js + TypeScript + Express + PostgreSQL API

## Backend setup

```bash
cd backend
cp .env.example .env   # fill in DATABASE_URL and JWT_SECRET
npm install
psql "$DATABASE_URL" -f migrations/001_init.sql
psql "$DATABASE_URL" -f migrations/002_signup_profile.sql
npm run dev
```

Email verification codes are logged to the console (`src/email.ts`) instead of actually emailed — swap in a real provider there when ready.

## Mobile setup

```bash
cd mobile
flutter pub get
flutter run
```

## Core flow

1. Sign up (`/auth/register`) — requires birthdate 18+, then verify email (`/auth/verify-email`).
2. Upload at least one profile photo (`POST /profile/photos`) — required to finish signup.
3. Pick interests/categories (`/categories`, `PUT /profile/categories`); propose new ones (`POST /categories`) for moderator review (`/categories/pending`, `/categories/:id/approve`).
4. Add a description and pronouns (`PUT /profile`).
5. Set preferences (`/preferences`).
6. Earn jackpot tickets, spin (`/jackpot/spin`) to reveal a candidate matching your preferences.
7. Like the result; if they've also drawn and liked you, it's a mutual match.
