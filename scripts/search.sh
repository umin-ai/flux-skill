#!/usr/bin/env bash
#
# Full-text search across Flux cards and boards.
#
#   FLUX_API_KEY=flux_... ./search.sh "query" [card|board]
#
# Env:
#   FLUX_API_KEY   required, starts with flux_
#   FLUX_BASE_URL  optional, defaults to https://flux.umin.ai
#
# Requires: curl, python3
set -euo pipefail

: "${FLUX_API_KEY:?Set FLUX_API_KEY (it starts with flux_)}"
BASE="${FLUX_BASE_URL:-https://flux.umin.ai}"
QUERY="${1:?usage: search.sh <query> [card|board]}"
TYPE="${2:-}"

URL="$BASE/api/search?q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$QUERY")"
[ -n "$TYPE" ] && URL="${URL}&type=${TYPE}"

curl -fsS -H "Authorization: Bearer $FLUX_API_KEY" "$URL"
echo
