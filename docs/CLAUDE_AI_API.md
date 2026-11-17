# claude.ai バックエンド API（チャット関連）

対象アプリ: `com.anthropic.claude`（Android, jadx 逆コンパイル）。
ベース URL: `https://claude.ai/api/`（`ze1.a()` で `le1.a()` + `/api/`）。  
認証: **Cookie ベース**。`sessionKey` と `lastActiveOrg` の 2 クッキー（`fa3.d`）を `Cookie` ヘッダに載せる。Bearer トークンは不要。`anthropic-client-*` 系ヘッダは本フローでは確認できず（capabilities 追加インターセプタ `c9s`/`ll70` は存在するが任意）。

組織 UUID は bootstrap レスポンスの `account.memberships[].organization.uuid` から取得する（後述）。

---

## 1. 組織 / アカウント bootstrap

`GET bootstrap/{organizationUuid}/app_start?growthbook_format=sdk&include_system_prompts=false`

- レスポンス `AppStartResponse`（`hs1`）:
  - `account`（`Account` / `k8`）: `uuid`, `email_address`, `full_name`, `display_name`, `created_at`, `updated_at`, `memberships`（`Membership[]`）, `settings`（`AccountSettings`）, `is_verified`, `onboarding_complete`, ...
  - `org_growthbook`
  - `current_user_access`
  - `personalized_greeting`
  - `model_selector_state`
  - `model_selector_config`
- `Membership`（`e7t`）: `organization`（`Organization`）, `role`, `created_at`, `updated_at`, `notification_preferences`, `seat_tier`
- `Organization`（`biw`）: `uuid`, `name`, `settings`, `capabilities`, `raven_type`, `plan_display_name`, `rate_limit_tier`, `billing_type`, `claude_ai_bootstrap_models_config`, `has_hosted_code_environments`, ...
- `AccountSettings`（`mh`）: `enabled_web_search`, `tool_search_mode`, `thinking_mode`, `effort_level`, `grove_enabled`, `voice_preference`, ...

`current_user_access` は別途 `GET bootstrap/{organizationUuid}/current_user_access`。

---

## 2. 会話（Conversations）

### 取得

- `GET organizations/{organization}/chat_conversations/{chat}` — 1 件取得（`ChatConversation` / `d68`）  
  フィールド: `uuid`, `created_at`, `updated_at`, `name`, `model`, `settings`, `is_starred`, `project_uuid`, `is_temporary`, `current_leaf_message_uuid`
- `GET organizations/{organization}/chat_conversations/{chat}/latest` — 最新リーフ取得
- `GET organizations/{organization}/chat_conversations/{chat}/serving` — `ChatServing`（`yr9`）: `connector_domains_withheld`, `send_refusal`, `takes_side_questions`

クエリ: `tree_mode`, `rendering_mode`, `render_all_tools` は `GET .../chat_conversations/{chat}` のリクエストで使われる（逆コンパイルでは query 名として確認; パラメータ化は `rf1.n`）。

### 一覧

- `GET organizations/{organization_uuid}/recents?section=...&cursor=...&surfaces=...&include=...`  
  レスポンス `RecentsSectionsResponse`（`az10`）: `sections`（`RecentsSection[]`）, `degraded_surfaces`, `incomplete_surfaces`  
  `RecentsSection`（`xy10`）: `id`, `title`, `data`, `next_cursor`  
  `RecentsRow.Session`（`dy10`）: `id`, `kind`, `title`, `preview`, `updated_at`, `unread`, `worker_status`, `needs_input`, `is_live`, `is_starred`, ...
- プロジェクト内: `GET organizations/{organization_uuid}/projects/{project_uuid}/conversations` / `conversations_v2`

### 作成

`POST organizations/{organization}/chat_conversations/{chat}` は更新（PUT）用。新規作成は completion の `create_conversation_params`、または `CreateChatRequest`。

`CreateChatRequest`（`g6f`）:
- `uuid`（クライアント側生成 UUID）, `name`, `model`, `project_uuid`, `compass_mode`, `is_temporary`, `include_conversation_preferences`, `enabled_imagine`, `chat_memory_mode`, `chat_started_from`, `cardinal_cta_action`, `started_as_artifact_type_id`

### 更新 / 削除 / その他

- `PUT organizations/{organization}/chat_conversations/{chat}`（`UpdateChatRequest` / `qwf0`）: `name`, `is_starred`, `settings`（`UpdatableChatConversationSettings` / `svf0`: `enabled_mcp_tools`, `enabled_web_search`, `compass_mode`, `tool_search_mode`, `thinking_mode`, `effort_level`）
- `DELETE organizations/{organization}/chat_conversations/{chat}`
- `POST organizations/{organization}/chat_conversations/delete_many`（`DeleteChatsRequest` / `mqg`: `conversation_uuids`）→ `DeleteChatsResponse`（`oqg`）: `deleted`, `failed`
- `POST organizations/{organization}/chat_conversations/move_many`（`MoveChatsRequest` / `v8u`: `conversation_uuids`, `project_uuid`）→ `MoveChatsResponse`（`y8u`）: `moved`, `failed`
- `POST organizations/{organization}/chat_conversations/{chat}/star` は未確認（star は PUT の `is_starred` で実施）
- タイトル生成: `POST organizations/{organization}/chat_conversations/{chat}/title`（`GenerateChatTitleRequest` / `w8l`）: `message_content`, `recent_titles` → `GenerateChatTitleResponse`（`y8l`）: `title`
- 既読: `POST .../read_state`（`ReadStateRequest` / `sj10`）: `state`
- 共有: `POST .../share`, `POST .../share_access`

---

## 3. メッセージ送信とストリーミング

エンドポイント:

- `POST organizations/{organization}/chat_conversations/{chat}/completion`
- `POST organizations/{organization}/chat_conversations/{chat}/retry_completion`

リクエストボディ `ChatCompletionRequest`（`p58` / `q58`）:
- `prompt`（必須）, `timezone`（必須）
- `model`（任意）, `attachments`（任意, `MessageAttachment[]`）, `files`（任意, `MessageAttachment[]`?）
- `rendering_mode`（任意）, `input_mode`（必須）, `tools`（任意）
- `parent_message_uuid`（任意）, `create_conversation_params`（任意）
- `tool_states`（任意, `ToolState[]`）, `effort`（任意）, `thinking_mode`（任意）
- `completion_request_id`（任意）, `turn_message_uuids`（任意, `TurnMessageUuids`）, `tool_allowlist`（任意）, `skip_completion_notification`（任意）

`completion_request_id` はキャンセル用にクライアント生成 UUID を入れる。

ストリーミング: `Accept: text/event-stream`。SSE イベント:

- `message_start`: `{ "message": {uuid, parent_uuid}, "discarded_parent_message_uuid" }`（`lrt` / `CompletionMessage` / `joc`）
- `content_block_start`: `{ "index": int, "content_block": { type, ... } }`（`vqd`）
- `content_block_delta`: `{ "index": int, "delta": { text | thinking | ... } }`（`oqd`）
  - `text_delta`: `{ "text": "..." }`（`d9d0`）
  - `thinking_delta`: `{ "thinking": "..." }`（`qid0`）
- `content_block_stop`: `{ "index": int }`（`zqd`）
- `message_delta`: `{ "delta": { "stop_reason", "stop_sequence", "stop_details" } }`（`pjt` / `MessageDelta.Wire` / `mjt`）
- `message_stop`: 完了
- `message_limit`: 使用量制限（`baq` が `"type":"message_limit"` のイベントを検出; 本文は `approaching_limit` / `exceeded_limit` / `within_limit` のいずれか）
- `error`: エラー

キャンセル: `POST organizations/{organization}/chat_conversations/{chat}/stop_response`（`StopResponseRequest` / `dnb0`）: `{ "completion_request_id": "..." }`

---

## 4. メッセージツリー

`ChatMessage`（`ru8`）:
- `uuid`, `parent_message_uuid`, `index`, `created_at`, `updated_at`, `text`, `content`, `sender`（`"human"` / `"assistant"`）, `attachments`, `files`, `input_mode`, `is_edited`, `chat_feedback`, `stop_reason`

現在のブランチは `ChatConversation.current_leaf_message_uuid` から `parent_message_uuid` を辿って復元する。`message_start` の `discarded_parent_message_uuid` は破棄された親を示す。

`content` ブロックはテキスト / thinking / tool_use など。`attachments` は `MessageAttachment`（`vgt`）: `id`, `file_name`, `file_size`, `file_type`, `extracted_content`, `document_id`, `path`, `download_path`, `session_path`, `customization_kind`, `file_kind`, `unavailable`, `session_image`, `text_extracted`, `thumbnail_path`, ...

---

## 5. ファイル / 画像アップロード

1. `POST organizations/{organization_uuid}/conversations/{conversation_uuid}/files/prepare-upload`  
   ボディ: `{ "files": ["filename.png"] }`（`PrepareUploadRequest` / `vzy`）  
   レスポンス: `{ "uploads": [ { "file_uuid", "filesystem_id", "path", "file_name" } ] }`（`PrepareUploadResult` / `zzy`）

2. ドキュメント変換: `POST organizations/{organization}/convert_document`（multipart, フィールド名 `file`）→ `MessageAttachment` 相当

3. プロジェクト用: `POST organizations/{organization_uuid}/projects/{project_uuid}/upload`, `POST .../projects/{project_uuid}/docs`

completion リクエストでは `attachments` / `files` に `MessageAttachment` を載せる。

---

## 6. モデル一覧と使用量

モデルは bootstrap の `model_selector_state` / `model_selector_config` から取得。`ModelSelectorEntry`（`o3u`）: `id`, `name`, `short_name`, `voice_model`, `description`, `notice`, `selection_notice`, `section`, `disabled`, `disabled_reason`, `billing`, `capabilities`, `thinking`（`ThinkingState`）, `ultracode`, `badge`, `started_chat_note`, `tooltip`

`ThinkingState`（`akd0`）は `effort` / `effort_and_mode` / `mode` / `none` / `unknown` のいずれか。

使用量は SSE の `message_limit` イベントおよび `PersistedRateLimit`（`s0y`）で管理。

---

## 7. プロジェクト

- `GET organizations/{organization_uuid}/projects` / `projects_v2`
- `GET organizations/{organization_uuid}/projects/{project_uuid}`
- `PUT organizations/{organization_uuid}/projects/{project_uuid}`
- `DELETE organizations/{organization_uuid}/projects/{project_uuid}`
- `GET .../projects/{project_uuid}/conversations` / `conversations_v2`
- `GET .../projects/{project_uuid}/docs`
- `POST .../projects/{project_uuid}/docs`
- `DELETE .../projects/{project_uuid}/docs/{doc_uuid}`
- `POST .../projects/{project_uuid}/upload`

`Project`（`yhz` / `zhz`）: `uuid`, `name`, `description`, `is_private`, `created_at`, `updated_at`, `creator`, `archived_at`, `is_starred`, `is_starter_project`, `type`, `subtype`, `prompt_template`, `docs_count`, `files_count`, `permissions`, `moved_to`, `is_upgraded`, `memory_general_enabled`, ...

`ProjectChatsPage`（`znz`）: `data`, `pagination`。`ProjectDoc`（`ssz`）: ドキュメント。

---

## 8. 必須ヘッダ

- `Cookie: sessionKey=<...>; lastActiveOrg=<org_uuid>`（`fa3.d` で定義）
- `Accept: text/event-stream`（completion 時）
- `Content-Type: application/json`（JSON ボディ時）

---

## 最小呼び出しシーケンス

1. `GET bootstrap/{org}/app_start` → `account.memberships[0].organization.uuid` を取得
2. `GET organizations/{org}/recents` → チャット一覧（セクション）
3. `GET organizations/{org}/chat_conversations/{chat}` → メッセージツリー
4. `POST organizations/{org}/chat_conversations/{chat}/completion`（`Accept: text/event-stream`）→ SSE でストリーミング受信
5. 必要に応じて `POST .../stop_response` でキャンセル