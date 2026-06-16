# Worked examples

Copy-paste `curl` for every common operation. All commands assume:

```bash
export FLUX_API_KEY=flux_your_key
export BASE=${FLUX_BASE_URL:-https://flux.umin.ai}
auth="Authorization: Bearer $FLUX_API_KEY"
```

Every write below sends `X-Idempotency-Key: $(uuidgen)` so a retry never duplicates the
action. Dates are ISO 8601.

## List boards and read one

```bash
# Boards in the active workspace
curl -fsS -H "$auth" "$BASE/api/boards"

# Full board: columns, cards, labels, members (accepts shortId or UUID)
curl -fsS -H "$auth" "$BASE/api/boards/av-tX6qQ"
```

## Create a card

```bash
curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards" \
  -d '{"boardId":"<board-uuid>","columnId":"<column-uuid>","title":"Ship v2","description":"**Markdown** supported"}'
```

## Move a card to another column

`reorder` sets both the column and the position. `position: 0` drops it at the top.

```bash
curl -fsS -X PUT -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards/reorder" \
  -d '{"boardId":"<board-uuid>","moves":[{"cardId":"<card-uuid>","columnId":"<target-column-uuid>","position":0}]}'
```

## Assign members

The write field is **`assignees`** (an array of user IDs) and it replaces the whole set.
Get user IDs from the board's `members` array.

```bash
curl -fsS -X PATCH -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards" \
  -d '{"cardId":"<card-uuid>","assignees":["<user-uuid-1>","<user-uuid-2>"]}'
```

## Label a card

Labels are defined per board, then toggled onto cards. Get label IDs from the board's
`boardLabels` array (or create one first).

```bash
# Create a board label
curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/boards/<board-uuid>/labels" \
  -d '{"text":"Urgent","color":"#ef4444"}'

# Toggle it onto a card
curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards/<card-uuid>/labels" \
  -d '{"labelId":"<label-uuid>"}'
```

## Add a checklist item and a comment

```bash
curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards/<card-uuid>/checklist" -d '{"text":"Write tests"}'

curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards/<card-uuid>/comments" -d '{"content":"Looks good to me"}'
```

## Search

```bash
curl -fsS -H "$auth" "$BASE/api/search?q=onboarding&type=card"
```

## Undo the last action

Every write is reversible. If you delete or move the wrong thing, undo it:

```bash
curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" \
  "$BASE/api/undo" -d '{"boardId":"<board-uuid>"}'
```

## Recipe: triage incoming cards

A multi-step pattern an agent can run end to end — read a board, then route each card in
the first ("Inbox") column to a destination column by keyword.

1. `GET /api/boards/{shortId}` — read `board.columns` and `cards`.
2. For each card in the Inbox column, decide a target column (e.g. title contains "bug"
   → "Bug Fix").
3. Batch the moves into one call:

```bash
curl -fsS -X PUT -H "$auth" -H "Content-Type: application/json" \
  -H "X-Idempotency-Key: $(uuidgen)" \
  "$BASE/api/cards/reorder" \
  -d '{"boardId":"<board-uuid>","moves":[
        {"cardId":"<c1>","columnId":"<bugfix-col>","position":0},
        {"cardId":"<c2>","columnId":"<review-col>","position":0}
      ]}'
```

If a routing rule misfires, `POST /api/undo` rolls back the last action on that board.
