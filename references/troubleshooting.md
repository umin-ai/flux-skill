# Troubleshooting

## HTTP status codes

| Status | Meaning | What to do |
|---|---|---|
| `401` | API key missing or invalid | Check the `Authorization: Bearer flux_...` header. |
| `403` | Key is valid but not permitted | The key lacks the scope (e.g. read-only key doing a write), **not** a missing resource. Use a key with write scope. |
| `404` | Board/card not found | Check the id, and that it isn't soft-deleted. |
| `409` | Version conflict | You sent `expectedVersion` and the record changed. Re-read it and retry. |
| `422` | Validation error | The body is malformed or has no recognized fields. See below. |
| `429` | Rate limited | Back off and retry. |

## `422 "No updates provided"` when updating a card

The PATCH `/api/cards` write field for assignees is **`assignees`**, not `assigneeIds`.
Board *reads* expose the same data as `assigneeIds`, which is an easy trap. Sending
`assigneeIds` is silently ignored, and if it's the only field you sent you get
`422 "No updates provided"`.

```jsonc
// wrong — ignored, 422
{ "cardId": "...", "assigneeIds": ["..."] }
// right
{ "cardId": "...", "assignees": ["..."] }
```

## A `403` before your request reaches Flux

Flux is served behind a CDN/WAF. Some HTTP clients send a default `User-Agent` that the
edge blocks with a generic `403` (body like `error code: 1010`) — this happens *before*
the request reaches the API, so it is **not** an auth or scope problem. Flux's own
rejections are JSON, e.g. `{ "error": "write scope required", "code": "FORBIDDEN" }`.

Fix: use a normal client. `curl` works out of the box. If you script with a library, set a
real `User-Agent` header rather than the library default.

## Idempotency

Send `X-Idempotency-Key: <uuid-v4>` on every write. On a retry with the same key, Flux
returns the original result instead of repeating the action. Use a fresh key per distinct
action; reuse the same key only when retrying the *same* action.

## IDs: shortId vs UUID vs humanId

- **Boards** have a UUID (`id`) and a short URL id (`shortId`, e.g. `av-tX6qQ`). Path
  params accept either; use the UUID in request bodies (`boardId`).
- **Cards** have a UUID (`id`) and a `humanId` (e.g. `TB-1`) used in share URLs. Use the
  UUID for API writes.
- Resolve a board's columns, labels, and members from `GET /api/boards/{shortId}` *before*
  creating or moving cards — you need their IDs.

## Soft deletes

`DELETE` never destroys data; it sets `deletedAt`, and queries filter it out. Recover with
`POST /api/undo { boardId }`, which reverses the last action on that board.

## Active workspace

Board and card lists are scoped to the key's **active workspace**. If a board seems
missing, it may live in another workspace: list everything with `GET /api/boards/all`, or
switch with `POST /api/workspaces/switch { workspaceId }`.
