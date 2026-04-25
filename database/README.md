# Database Layer

This folder contains schema design, migrations, seeds, and DB automation scripts.

## Tooling

- DB client: DBeaver
- DB engine: SQLite

## Structure
- `schema/` canonical SQL schema definitions and ERD sources
- `migrations/` versioned migration files
- `seeds/` deterministic seed data for local/dev environments
- `scripts/` DB bootstrap, backup, and maintenance scripts

## DBeaver Setup Flow

1. Create/connect to a SQLite database in DBeaver.
2. Open `assets/health_app.db` as a SQLite connection in DBeaver.
3. Open and execute `migrations/20260425_001_baseline.sql`.
4. Open and execute `seeds/001_demo_seed.sql` for local test data.

## Current Core Tables

- `user_profiles`: stores mental-health profile data, calming strategies, favorites, and emergency contact.
- `check_ins`: stores mood/anxiety/panic check-ins, optional heart-rate/location, and AI response suggestions.

## Next implementation steps
1. Add auth-linked ownership (`auth_user_id`) in `user_profiles`.
2. Add encrypted-at-rest handling for sensitive columns.
3. Add audit/event tables for agent interactions.
4. Introduce formal migration runner in CI.
