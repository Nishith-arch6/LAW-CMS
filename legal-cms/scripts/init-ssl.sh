#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  Initial Let's Encrypt certificate request
#  Run once before first production deploy.
#  Usage:  ./scripts/init-ssl.sh yourdomain.com your@email.com
# =============================================================

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 DOMAIN EMAIL"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "=== Requesting certificate for $DOMAIN ==="

docker compose -f docker-compose.prod.yml run --rm \
    -v "$(pwd)/docker/nginx.prod.conf:/tmp/nginx.conf:ro" \
    certbot certonly --webroot \
    --webroot-path /var/lib/letsencrypt \
    --domain "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

echo "=== Certificate obtained ==="
echo "Update nginx.prod.conf server_name to '$DOMAIN' if not done already."
echo "Then run:  docker compose -f docker-compose.prod.yml up -d"
