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
npm run dev
```

## Mobile setup

```bash
cd mobile
flutter pub get
flutter run
```

## Core flow

1. Register/login (`/auth`).
2. Set preferences (`/preferences`).
3. Earn jackpot tickets, spin (`/jackpot/spin`) to reveal a candidate matching your preferences.
4. Like the result; if they've also drawn and liked you, it's a mutual match.
