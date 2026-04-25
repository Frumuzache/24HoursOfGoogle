# Database Layer

This folder contains schema design, migrations, seeds, and DB automation scripts.

## Structure
- `schema/` canonical SQL schema definitions and ERD sources
- `migrations/` versioned migration files
- `seeds/` deterministic seed data for local/dev environments
- `scripts/` DB bootstrap, backup, and maintenance scripts

## Next implementation steps
1. Choose DB engine (PostgreSQL recommended for transactional workloads).
2. Add migration tool config (Flyway, Prisma, Alembic, Liquibase, etc.).
3. Create baseline schema migration.
4. Add seed strategy for test and development environments.
