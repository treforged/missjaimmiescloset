#!/usr/bin/env bash
# Direct-upload deploy to Cloudflare Pages. No GitHub involved.
# Needs: `npx wrangler login` once (Tre's browser) or CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID in the env.
# Undo: Cloudflare dashboard > Pages > missjaimmiescloset > Deployments > roll back, or delete the project.
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d)"
cp index.html og-image.jpg "$stage"/
[ "${1:-}" = "--stage-only" ] && { ls -l "$stage"; exit 0; }
# `pages project create` made a Worker, so deploy as a Worker. NEVER point --assets at the repo root (it published handoff.md on 10-17).
npx --yes wrangler@4 deploy --name missjaimmiescloset --assets "$stage" --compatibility-date 2026-10-12
