#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  Legal CMS — Production Deploy Script
#  Usage:  ./scripts/deploy.sh [--no-migrate] [--env-file path]
# =============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

DO_MIGRATE=true
ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-migrate) DO_MIGRATE=false; shift ;;
        --env-file)   ENV_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Pulling latest changes ==="
git pull origin main

echo "=== Exporting environment ==="
if [[ -n "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

echo "=== Running database migrations ==="
if [[ "$DO_MIGRATE" == true ]]; then
    docker compose -f docker-compose.prod.yml run --rm backend \
        alembic upgrade head
fi

echo "=== Rebuilding and restarting services ==="
docker compose -f docker-compose.prod.yml build --pull

echo "=== Stopping old containers ==="
docker compose -f docker-compose.prod.yml down --remove-orphans

echo "=== Starting production stack ==="
docker compose -f docker-compose.prod.yml up -d

echo "=== Cleaning up unused images ==="
docker image prune -f

echo "=== Deploy complete ==="
echo "Backend:   http://localhost:8000/health"
echo "Frontend:  http://localhost"
echo ""
echo "To tail logs:  docker compose -f docker-compose.prod.yml logs -f"
