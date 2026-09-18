#!/bin/sh
set -e

echo "Waiting for PostgreSQL..."
python wait_for_db.py

echo "Running Alembic migrations..."
# This repo's migration graph has two independent roots: `fresh_local`
# (builds the full schema from an empty DB — what a fresh container's
# Postgres actually is) and `shared_legacy` (reconciles the pre-existing
# shared Neon DB's legacy tables; its own baseline is a deliberate no-op
# and cannot bootstrap an empty database). The bare `head` keyword is
# ambiguous between them, so the target is explicit — see
# alembic/versions/83f9966ec583_create_initial_schema.py. Defaults to
# `fresh_local@head` for a brand-new empty Postgres (local Docker); set
# ALEMBIC_TARGET=shared_legacy@head in the environment when running
# against the pre-existing shared Neon database (e.g. Render, if it
# reuses that DB) instead of duplicating this script per deploy target.
alembic upgrade "${ALEMBIC_TARGET:-fresh_local@head}"

echo "Seeding default roles (idempotent)..."
python -m app.db.init_db

echo "Starting Uvicorn..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
