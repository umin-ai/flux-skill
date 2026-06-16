#!/usr/bin/env bash
#
# Create a card on a Flux board (found by title) in its first column.
#
#   FLUX_API_KEY=flux_... ./create-card.sh "Board Title" "Card title" ["description"]
#
# Env:
#   FLUX_API_KEY   required, starts with flux_
#   FLUX_BASE_URL  optional, defaults to https://flux.umin.ai
#
# Requires: curl, python3, uuidgen
set -euo pipefail

: "${FLUX_API_KEY:?Set FLUX_API_KEY (it starts with flux_)}"
BASE="${FLUX_BASE_URL:-https://flux.umin.ai}"
BOARD_TITLE="${1:?usage: create-card.sh <board title> <card title> [description]}"
CARD_TITLE="${2:?usage: create-card.sh <board title> <card title> [description]}"
DESCRIPTION="${3:-}"
AUTH="Authorization: Bearer ${FLUX_API_KEY}"

# 1. Find the board by title (/api/boards lists the active workspace) and grab its
#    UUID + the id of its first column.
read -r BOARD_ID COLUMN_ID < <(
  curl -fsS -H "$AUTH" "$BASE/api/boards" \
  | BOARD_TITLE="$BOARD_TITLE" python3 -c '
import sys, json, os
boards = json.load(sys.stdin)["boards"]
b = next((x for x in boards if x["title"] == os.environ["BOARD_TITLE"]), None)
if not b:               sys.exit("Board not found: " + os.environ["BOARD_TITLE"])
cols = b.get("columns") or []
if not cols:            sys.exit("Board has no columns")
print(b["id"], cols[0]["id"])
'
)

# 2. Create the card. X-Idempotency-Key makes a retry safe (no duplicate card).
curl -fsS -X POST -H "$AUTH" \
  -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards" \
  -d "$(BOARD_ID="$BOARD_ID" COLUMN_ID="$COLUMN_ID" TITLE="$CARD_TITLE" DESC="$DESCRIPTION" python3 -c '
import json, os
body = {"boardId": os.environ["BOARD_ID"], "columnId": os.environ["COLUMN_ID"], "title": os.environ["TITLE"]}
if os.environ.get("DESC"): body["description"] = os.environ["DESC"]
print(json.dumps(body))
')"
echo
