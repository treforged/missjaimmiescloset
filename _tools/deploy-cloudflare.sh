#!/usr/bin/env bash
# Direct-upload deploy to Cloudflare Pages. No GitHub involved.
# Needs: `npx wrangler login` once (Tre's browser) or CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID in the env.
# Undo: Cloudflare dashboard > Pages > missjaimmiescloset > Deployments > roll back, or delete the project.
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d)"
cp index.html og-image.jpg "$stage"/
[ "${1:-}" = "--stage-only" ] && { ls -l "$stage"; exit 0; }
npx --yes wrangler@4 pages deploy "$stage" --project-name missjaimmiescloset --branch main
