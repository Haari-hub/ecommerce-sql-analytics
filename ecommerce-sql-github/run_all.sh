#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_all.sh — build the database and run every analysis end to end.
# Usage:   ./run_all.sh [dbname]        (default dbname: ecommerce)
# Requires: PostgreSQL (createdb, psql) on PATH. Run from the repo root.
# ---------------------------------------------------------------------------
set -euo pipefail
DB="${1:-ecommerce}"

echo ">> (re)creating database '$DB'"
dropdb --if-exists "$DB"
createdb "$DB"

echo ">> building schema"
psql -d "$DB" -v ON_ERROR_STOP=1 -f sql/00_schema.sql

echo ">> loading data"
psql -d "$DB" -v ON_ERROR_STOP=1 -f sql/01_load_data.sql

echo ">> data-quality checks"
psql -d "$DB" -v ON_ERROR_STOP=1 -f sql/02_data_quality_checks.sql

echo ">> running analyses"
for f in sql/analysis/*.sql; do
  echo "   -- $f"
  psql -d "$DB" -v ON_ERROR_STOP=1 -f "$f" > "results/$(basename "${f%.sql}").out" 2>&1
done

echo ">> done. Per-query output written to results/*.out"
