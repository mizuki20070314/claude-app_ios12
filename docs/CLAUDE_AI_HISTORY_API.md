# Claude.ai チャット履歴 API（Android アプリ逆コンパイル）

対象: `com.anthropic.claude` Android アプリの jadx 出力（`C:\Users\mizuk\work\apk_decoded\base\sources\`、主に `defpackage\`）。  
ベース URL: `https://claude.ai/api/`。認証は Cookie ベース（`sessionKey` / `lastActiveOrg`）。  
本ドキュメントは **読み取り専用の逆コンパイル結果** のメモであり、iOS クライアントが「会話一覧 → 1 件を開く → メッセージ表示」を再現するための仕様をまとめる。

> 不確かな点は `未確認` と明記する。

---

## 1. チャット一覧: `organizations/{organization_uuid}/recents`

実装クラス: `defpackage/gx10.java`（`fx10` 実装）。REST ラッパ: `defpackage/c310.java`（`nx10` 実装）。

### 1.1 エンドポイント

- `GET organizations/{organization_uuid}/recents`
- `organization_uuid` はパスパラメータ。

### 1.2 クエリパラメータ（`gx10.a`）

| 名前 | 型 | 必須 | 説明 |
|---|---|---|---|
| `limit` | int | 任意 | `c310.a`（セクション取得）では `30`、`c310.b`（フラット取得）では `100`。`gx10` では `Integer` で送信。 |
| `section` | string | 任意 | `c310.a` では `"recents"`、`c310.b` では `null`（送信省略）。サーバ側セクション名。クライアントで確認できた値は `"recents"` と省略のみ。他の値は `未確認`。 |
| `cursor` | string | 任意 | ページングカーソル。`RecentsSection.next_cursor` の値を次ページに渡す（`未確認`: セクション単位か全体か）。 |
| `surfaces` | string（繰り返し） | 任意 | `zw10` enum の wire 文字列を複数付与。 |
| `include` | string（繰り返し） | 任意 | 同上（`surfaces` と同じ enum）。 |

`surfaces` / `include` に渡す値（`defpackage/zw10.java`）:

| enum | wire string |
|---|---|
| `CHAT` | `chat` |
| `PROJECT` | `project` |
| `COWORK` | `cowork` |
| `CODE` | `code` |
| `COWORK_CHAT` | `cowork_chat` |
| `ARTIFACT` | `artifact` |
| `ROUTINE` | `routine` |
| `UNKNOWN` | `unknown` |

`c310.a`（セクション取得）は `surfaces` / `include` を同一リストから生成（`vom.Z` / `vom.A`）。`c310.b`（フラット取得、limit=100）は `section=null, cursor=null`。

### 1.3 レスポンス: `RecentsSectionsResponse`（`bz10` / `az10`）

JSON フィールド:

- `sections`: `RecentsSection[]`
- `degraded_surfaces`: string[]（`zw10` wire strings、省略可）
- `incomplete_surfaces`: string[]（同上、省略可）

`RecentsSection`（`yy10` / `xy10`）:

- `id`: string
- `title`: string
- `data`: `RecentsRow[]`
- `next_cursor`: string（nullable）

### 1.4 `RecentsRow` サブタイプ

多相デシリアライザ `defpackage/jy10.java` は JSON の `type` フィールドで分岐する。

| `type` | ラッパクラス | 実データクラス | ソース |
|---|---|---|---|
| `chat` | `by10` | `q68`（`ChatConversationWithProjectReference`） | `jy10`, `p68` |
| `project` | `cy10` | `zhz`（プロジェクト） | `jy10`, `yhz` |
| `cowork_session` | `hy10` | `ey10`（`RecentsRow.Session`） | `jy10`, `dy10` |
| `code_session` | `ey10`（直接） | `ey10` | `jy10`, `dy10` |
| （その他 / 未知） | `gy10`（`Unknown`） | — | `jy10` |

`未確認`: `RecentsRow.Artifact`（`ay10` / `zx10`）のシリアライザは存在するが、`jy10` の分岐には `"artifact"` が無い（hashCode `-1228798510` 未処理）。フィードで `type="artifact"` が返る場合、このバージョンでは `gy10`（Unknown）として扱われる可能性がある。`artifact` 行を必要とする場合は別途キャッシュ層（`yzf.java` が `"artifact"` を処理）を参照。

#### 1.4.1 `chat` 行（`q68` / `p68`）

フィールド（JSON 名）:

- `uuid`
- `created_at`
- `updated_at`
- `name`
- `model`（nullable）
- `settings`（nullable）
- `is_starred`（nullable）
- `project_uuid`（nullable）
- `project`（nullable、プロジェクト参照）
- `is_temporary`（nullable）
- `current_leaf_message_uuid`（nullable）
- `needs_input`（nullable）
- `needs_input_kind`（nullable）
- `live_status`（nullable）
- `unread`（nullable）
- `proxied_session`（nullable）
- `is_scheduled_task_row`（nullable）
- `scheduled_task_id`（nullable）
- `unavailable_actions`（nullable）

#### 1.4.2 `project` 行（`zhz` / `yhz`）

フィールド:

- `uuid`
- `name`
- `description`（nullable）
- `is_private`
- `created_at`
- `updated_at`
- `creator`（nullable）
- `archived_at`（nullable）
- `archiver`（nullable）
- `is_starred`（nullable）
- `is_starter_project`（nullable）
- `type`（nullable）
- `subtype`（nullable）
- `prompt_template`（nullable）
- `docs_count`（nullable）
- `files_count`（nullable）
- `permissions`（nullable）
- `moved_to`（nullable）
- `is_upgraded`（nullable）
- `memory_general_enabled`（nullable）
- `memory_general_switch_visible`（nullable）
- `memory_page_visible`（nullable）

#### 1.4.3 `cowork_session` / `code_session` 行（`ey10` / `dy10`）

フィールド:

- `id`
- `kind`（nullable、`n580` enum）
- `title`
- `preview`（nullable）
- `updated_at`
- `unread`
- `worker_status`（nullable、`t5f` enum）
- `needs_input`
- `is_live`
- `is_starred`（nullable）
- `unavailable_actions`（nullable）
- `created_at`（nullable）
- `routine_fire_reason`（nullable）
- `routine_fired_at`（nullable）

#### 1.4.4 `artifact` 行（`ay10` / `zx10`）（参考）

- `id`
- `title`
- `updated_at`
- `is_starred`
- `is_own`
- `url`（nullable）

#### 1.4.5 未知行（`gy10`）

`Unknown` オブジェクトのみ。

### 1.5 ページング / カーソル規則

- セクションレスポンスの `RecentsSection.next_cursor` を次リクエストの `cursor` に渡す（`未確認`: `section` も同じ値 `"recents"` を維持するか）。
- `degraded_surfaces` / `incomplete_surfaces` で一部サーフェスの取得失敗を通知。クライアントはキャッシュを保持する実装（`cx60.java`）。
- `未確認`: `cursor` が `null` の場合の初回ページと、最終ページ判定（`next_cursor` が `null`）。

### 1.6 クラシックな `organizations/{org}/chat_conversations` 一覧

- `chat_conversations`（`{chat}` なし）のパスは本アプリでは **使用されていない**（grep で `organizations/{organization}/chat_conversations"` 単体は 0 件）。`limit/offset/starred` のクラシック一覧は `未確認`（サーバがサポートしていてもクライアントは recents を使用）。
- 代わりに利用される関連エンドポイント:
  - `POST organizations/{organization}/chat_conversations/delete_many`（複数削除）
  - `POST organizations/{organization}/chat_conversations/move_many`（移動）

### 1.7 検索: `conversation/search/v2`（`v38.b`）

- `GET organizations/{organization_uuid}/conversation/search/v2`
- クエリ:
  - `query`: 検索文字列
  - `n`: 件数（固定 `10`）
- レスポンス: `nce.a`（`未確認`: 詳細フィールドは本調査では展開していない）。

---

## 2. 1 件を開く: `organizations/{organization}/chat_conversations/{chat}`

### 2.1 GET パラメータ（呼び出し箇所別）

共通: パス `organizations/{organization}/chat_conversations/{chat}`、`organization` と `chat` をパス/クエリに設定（`rf1.j("chat", ...)`）。

#### A. `id9.java` / `gp70.java`（raw / window 取得）

クエリ:

- `rendering_mode=raw`（`j730.RAW`）
- `bodies=window`
- `bodies_limit=1`
- `render_all_tools=true`
- `include_extracted_content=false`
- `max_response_bytes=2097152`
- ヘッダ: `Cache-Control: no-cache, no-store`
- `rf1.m = true`（`未確認`: キャッシュ無効化フラグの可能性）

レスポンス型: `ChatTemporaryState`（`dx9`）/ `ServerSavedChatAsk.Answer`（`dp70`）相当（`未確認`: 実際の JSON は `uuid`, `is_temporary`, `current_leaf_message_uuid` を含む軽量応答）。

#### B. `v38.a`（メッセージ本文取得、主にこちらを使用）

シグネチャ: `v38.a(org, chat, return_dangling_human_message?, max_response_bytes?, renders_source_card?, f6l?, ...)`

クエリ:

- `rendering_mode=messages`（`j730.MESSAGES`）
- `render_all_mobile_tools`: boolean（呼び出しにより `true` または `false`。例: `c1l` は true、`wo10` は false）
- `return_dangling_human_message`: boolean（任意、`null` 許容）
- `include_extracted_content=false`
- `max_response_bytes`: long（任意、`null` 許容）
- `renders_source_card`: true（`z` が true の場合のみ送信、それ以外は `null`/省略）

レスポンス型: `ChatConversationWithNestedMessage`（`n68` / `o68`）または `lpf0`（f6l が指定された場合、`未確認`）。

### 2.2 レスポンス: `ChatConversation` / `ChatConversationWithNestedMessage`

`ChatConversation`（`e68` / `d68`）フィールド:

- `uuid`
- `created_at`
- `updated_at`
- `name`
- `model`（nullable）
- `settings`
- `is_starred`（nullable）
- `project_uuid`（nullable）
- `is_temporary`（nullable）
- `current_leaf_message_uuid`（nullable）

`ChatConversationWithNestedMessage`（`o68` / `n68`）は上記に加えて:

- `chat_messages`: `ChatMessage[]`（nullable）
- `workspace_upgraded`（nullable boolean）

### 2.3 `ChatMessage`（`su8` / `ru8`）

フィールド:

- `uuid`
- `parent_message_uuid`（nullable）
- `index`
- `created_at`
- `updated_at`（nullable）
- `text`
- `content`: `ContentBlock[]`（nullable）
- `sender`
- `attachments`
- `files`（nullable）
- `input_mode`（nullable）
- `is_edited`（nullable）
- `chat_feedback`（nullable）
- `stop_reason`（nullable）

### 2.4 ブランチ再構築（current leaf）

- 会話レスポンスの `current_leaf_message_uuid` を起点に、各 `ChatMessage.parent_message_uuid` を辿ってルートまで遡り、現在のブランチ（表示対象メッセージ列）を再構築する。
- `index` は表示順の補助。編集・分岐がある場合は `parent_message_uuid` チェーンが正とする。
- `未確認`: アプリ内の具体的な再構築関数名/アルゴリズム（配列化・キャッシュ）は本調査では特定していない。

### 2.5 `content` 内のブロック型（`ContentBlock`、`aqd`）

多相デシリアライザ `aqd.a()` が `type` で分岐。型文字列とフィールド:

| `type` | 実装クラス | 主なフィールド（JSON 名） |
|---|---|---|
| `text` | `u7d0` / `t7d0` | `start_timestamp`, `stop_timestamp`, `text`, `citations`, `voice_spoken_chars`, `flags`, `collapsible` |
| `thinking` | `iid0` / `hid0` | `start_timestamp`, `stop_timestamp`, `thinking`, `summaries`, `flags` |
| `tool_use` | `lze0` / `jze0` | `start_timestamp`, `stop_timestamp`, `name`, `id`, `input`, `message`, `display_content`, `integration_name`, `integration_icon_url`, `mcp_server_url`, `tool_identifier`, `icon_name`, `approval_key`, `approval_options`, `approval_notices`, `is_mcp_app`, `hidden_in_chat`, `tool_origin`, `memory_op_kind`, `input_incomplete`, `flags`, `connector_rows` |
| `tool_result` | `pve0` / `ove0` | `start_timestamp`, `stop_timestamp`, `name`, `tool_use_id`, `content`, `is_error`, `message`, `display_content`, `integration_name`, `integration_icon_url`, `mcp_server_url`, `icon_name`, `structured_content`, `meta`, `hidden_in_chat`, `tool_origin`, `flags`, `source_card` |
| `voice_note` | `ohh0` / `nhh0` | `start_timestamp`, `stop_timestamp`, `text`, `title`, `flags` |
| `bell` | `az4` / `zy4` | `start_timestamp`, `stop_timestamp`, `text`, `title`, `flags` |
| `flag` | `ckk` / `bkk` | `start_timestamp`, `stop_timestamp`, `flag`, `helpline`, `flags` |
| `unknown` | `mpf0` / `kpf0`（`UnknownContentBlock`） | `start_timestamp`, `stop_timestamp`, `flags` |

`未確認`: 各フィールドの必須/任意の厳密な nullability と、`citations` 等のネスト構造の詳細。

---

## 3. Star / Rename / Delete（一覧から）

### 3.1 更新（Star / Rename / Settings）

- `PUT organizations/{organization}/chat_conversations/{chat}`
- 実装: `w38.j`（`afu.c(3, ...)` = PUT）
- ボディ: `UpdateChatRequest`（`rwf0` / `qwf0`）:

```json
{
  "name": "...",          // nullable
  "is_starred": true,     // nullable
  "settings": { ... }     // nullable, UpdatableChatConversationSettings
}
```

`settings`（`svf0`）フィールド:

- `enabled_mcp_tools`
- `enabled_web_search`
- `compass_mode`
- `tool_search_mode`
- `thinking_mode`
- `effort_level`

Star は `is_starred`、Rename は `name` を送る。

### 3.2 タイトル自動生成（参考）

- `PUT organizations/{organization}/chat_conversations/{chat}/title`
- 実装: `hx9.java`
- ボディ: `GenerateChatTitleRequest`（`w8l`）: `message_content`, `recent_titles`
- 手動リネームとは別系統。

### 3.3 削除

- 単体削除: `DELETE organizations/{organization}/chat_conversations/{chat}`（`td.java`, `afu.c(5, ...)`）。
- 複数削除: `POST organizations/{organization}/chat_conversations/delete_many`
  - ボディ: `DeleteChatsRequest`（`mqg` / `nqg`）: `conversation_uuids`（string[]）
  - レスポンス: `DeleteChatsResponse`（`oqg` / `pqg`）: `deleted`, `failed`（`未確認`: 詳細型）。

### 3.4 移動（参考）

- `POST organizations/{organization}/chat_conversations/move_many`（`w38.f`）。

---

## 4. 必須ヘッダ（`to4` / `cra` / `nl.s`）

すべての claude.ai REST リクエストに付与される（`to4.intercept`）:

- `Cookie: sessionKey=<...>; lastActiveOrg=<org_uuid>`（`fa3.d` で定義）
- `User-Agent: Claude com.anthropic.claude/1.261113.19 (Android <sdk>) Claude/1.261113.19`（`lp0.B`）
- `x-organization-uuid: <org_uuid>`（`to4`）
- `Anthropic-Client-Platform: android`
- `Anthropic-Client-App: com.anthropic.claude`
- `Anthropic-Client-Version: 1.261113.19`
- `Anthropic-Client-Build: 26111319`
- `Anthropic-Client-OS-Version: <Build.VERSION.SDK_INT>`
- `Anthropic-Device-ID: <device_id>`（`axgVar.a`、動的）
- `Content-Type: application/json`（JSON ボディ時）
- `Accept: text/event-stream`（completion 時のみ）

追加ヘッダ（任意/条件付き）:

- `Cache-Control: no-cache, no-store`（`id9` / `gp70` の raw 取得時のみ）
- `anthropic-client-capabilities`（`c9s` / `ll70` インターセプタが追加。本 recents/open フローでの必須性は `未確認`）

`未確認`: `Anthropic-Device-ID` の生成方式（`axg`）と、Cookie の `lastActiveOrg` 更新タイミング。

---

## 5. iOS 実装の最小シーケンス

1. bootstrap で `organization_uuid` 取得（`CLAUDE_AI_API.md` 参照）。
2. `GET organizations/{org}/recents?section=recents&limit=30&surfaces=chat&include=chat`（必要に応じて surfaces を拡張）。
3. 各 `RecentsSection.data` の `type="chat"` 行から `uuid` / `name` / `updated_at` / `is_starred` を取得。
4. `GET organizations/{org}/chat_conversations/{uuid}?rendering_mode=messages&render_all_mobile_tools=true&include_extracted_content=false` でメッセージ取得。
5. `current_leaf_message_uuid` から `parent_message_uuid` チェーンを辿って表示ブランチを構築。
6. Star/Rename は `PUT organizations/{org}/chat_conversations/{uuid}`（`is_starred` / `name`）。
7. 削除は `DELETE organizations/{org}/chat_conversations/{uuid}`。

---

## 6. ソースファイル索引

- `defpackage/gx10.java` — recents GET
- `defpackage/c310.java` — recents ラッパ（limit/section/cursor）
- `defpackage/zw10.java` — surfaces enum
- `defpackage/az10.java`, `bz10.java` — RecentsSectionsResponse
- `defpackage/xy10.java`, `yy10.java` — RecentsSection
- `defpackage/jy10.java` — RecentsRow 多相デシリアライザ
- `defpackage/dy10.java`, `ey10.java` — Session 行
- `defpackage/p68.java`, `q68.java` — Chat 行
- `defpackage/yhz.java`, `zhz.java` — Project 行
- `defpackage/zx10.java`, `ay10.java` — Artifact 行
- `defpackage/id9.java`, `gp70.java`, `v38.java` — chat_conversations GET
- `defpackage/j730.java` — rendering_mode enum
- `defpackage/d68.java`, `n68.java`, `o68.java` — ChatConversation
- `defpackage/ru8.java`, `su8.java` — ChatMessage
- `defpackage/aqd.java` + `t7d0/hid0/jze0/ove0/...` — ContentBlock
- `defpackage/w38.java` — PUT/DELETE/move
- `defpackage/qwf0.java`, `rwf0.java` — UpdateChatRequest
- `defpackage/td.java` — DELETE
- `defpackage/to4.java`, `cra.java`, `nl.java` — ヘッダ
- `defpackage/v38.java` — conversation/search/v2
