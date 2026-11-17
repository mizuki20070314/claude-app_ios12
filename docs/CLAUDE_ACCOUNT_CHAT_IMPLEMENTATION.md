# Claude.ai account-mode chat implementation

## Overview

Account-mode chat uses the claude.ai cookie session instead of the Anthropic API key.
It is enabled only when all of the following hold:

- `SettingsStore.shared.authMode == "claudeAccount"`
- `ClaudeAccountAuth.shared.isLoggedIn == true`
- `ClaudeAccountAuth.shared.sessionKey` is non-empty

When these conditions are not met, `AnthropicClient.streamMessage` falls back to the
existing API-key path or surfaces `AnthropicError.accountChatUnsupported`.

## Files

- `ClaudeApp/Services/ClaudeAccountClient.swift` (new) — organization resolution, completion streaming, title generation.
- `ClaudeApp/Services/AnthropicClient.swift` — delegates account-mode chat from `streamMessage` / `generateTitle`; `StreamHandle` gained optional task/session and `onCancel`.
- `ClaudeApp/Services/ClaudeAccountAuth.swift` — public `storeLastActiveOrg(_:)` and org extraction in `parseProfile`.
- `ClaudeApp/UI/Chat/ChatViewController.swift` — passes `conversationId` / `isNewConversation`; silent cancel cleanup.
- `docs/CLAUDE_ACCOUNT_CHAT_IMPLEMENTATION.md` (this file).

## Organization resolver

1. If `ClaudeAccountAuth.shared.lastActiveOrg` is non-empty, use it as the org UUID.
2. Otherwise `GET https://claude.ai/api/organizations` with the session cookie and parse the
   first available organization UUID from `account.memberships[].organization.uuid`,
   `memberships[].organization.uuid`, `organizations[].uuid`, or top-level `uuid` /
   `organization_uuid` / `organizationId`.
3. Store the resolved UUID in Keychain via `ClaudeAccountAuth.storeLastActiveOrg(_:)`.
4. Best-effort `GET https://claude.ai/api/bootstrap/{org}/app_start?growthbook_format=sdk&include_system_prompts=false`
   is fired (non-blocking) for validation.

## Conversation creation

No separate create endpoint is required. For a new conversation, `create_conversation_params`
is included in the completion body:

```json
{ "uuid": "<chat>", "name": "", "model": "<selected model>" }
```

The client UUID is `UUID().uuidString.lowercased()` (or the lowercased local conversation id).

## Completion request

`POST https://claude.ai/api/organizations/{org}/chat_conversations/{chat}/completion`

Body fields:

- `prompt`: user text (text-file attachments prefixed, max 32k)
- `timezone`: `TimeZone.current.identifier`
- `model`: selected model id
- `attachments`: `[]`
- `files`: `[]`
- `rendering_mode`: `"messages"`
- `input_mode`: `"text"`
- `parent_message_uuid`: `null` (or last leaf uuid if available)
- `create_conversation_params`: new-chat object or `null`
- `tools`: `[]`
- `effort`: `null`
- `thinking_mode`: `"adaptive"` if extended thinking else `null`
- `completion_request_id`: client UUID
- `turn_message_uuids`: `null`
- `tool_allowlist`: `[]`
- `skip_completion_notification`: `false`

Headers (no API key, no Bearer):

```
Cookie: sessionKey=<session>; lastActiveOrg=<org>
Accept: text/event-stream
Content-Type: application/json
Origin: https://claude.ai
Referer: https://claude.ai/
```

## SSE parsing

Uses the existing `SSEParser`. Handles `message_start`, `content_block_start`,
`content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`,
`error`, `message_limit`, `ping`, `mutation_accepted`.
Text and thinking deltas are extracted from `content_block_delta.delta.text/thinking`
(and direct `delta.text/thinking`).

## Attachments

- Images: returns `ClaudeAccountError.attachmentsUnsupported` (clear error, no upload guessing).
- Text files: content prefixed to the prompt (max 32k). No server upload.

## Stop / cancel

`StreamHandle.cancel()` POSTs
`POST /api/organizations/{org}/chat_conversations/{chat}/stop_response`
with body `{ "completion_request_id": "<id>" }`, then cancels the task and invalidates
the session. Cancel is silent: no `onError` callback. `ChatViewController` performs
cleanup in `composerDidTapStop`.

## Title generation

Account mode uses
`POST /api/organizations/{org}/chat_conversations/{chat}/title`
with body `{ "message_content": <first user text>, "recent_titles": [] }`
and parses `title`. No API title model call.

## Errors

`ClaudeAccountError` cases:
`notLoggedIn`, `missingSession`, `missingOrganization`, `attachmentsUnsupported`,
`invalidResponse`, `cancelled`, `network(String)`, `serverError(String)`,
`decoding(String)`. Each case provides a Japanese `errorDescription`.

## Limitations

- Multi-turn threading relies on server state; `parent_message_uuid` is currently `null`.
- Server message UUIDs are not persisted locally.
- Image attachments are unsupported in account mode.
- Bootstrap/org endpoints are best-effort; network failures surface as errors.
- On iOS 12, `ASWebAuthenticationSession` may not expose the claude.ai session cookie to the app; the Safari fallback + manual validation is used in that case.
- No unit tests compiled (iOS build verified in CI only).

## Unit sanity skeleton (comments only)

```swift
// resolveOrganizationId: cookie present -> success without network
// resolveOrganizationId: no cookie -> GET organizations -> parse uuid
// extractOrganizationId: supports uuid / organization_uuid / organizationId / nested
// streamMessage: image attachment -> attachmentsUnsupported
// streamMessage: text attachment -> prompt prefixed, attachments []
// cancel: posts stop_response, no onError
// generateTitle: parses title from response
```
