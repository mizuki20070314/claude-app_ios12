# Claude Code Remote Control / Code セッション API（Android app decompile より）

ソース: `C:\Users\mizuk\work\apk_decoded\base\sources\`（jadx 出力、難読化あり）。  
対象: Android Claude アプリが「Code」/ リモートセッションを一覧・表示・購読するための通信。  
不確実なものは `未確認` と明記する。

## 0. 共通

- 通信クライアント: `defpackage.we1`（`sessions_api_client` 修飾子）。
- Production ベース URL: `https://claude.ai`（`defpackage.ie1.f`）。
  - `defpackage.ze1.a(..., 32)` の分岐により、sessions client のベースは `https://claude.ai/`（`/api/` なし）にパスを結合する実装。
  - 実際の最終 URL が `/api/` 付きになるかどうかは `未確認`。
- 主な共通ヘッダ（`defpackage.ju80`, `defpackage.njf`, `defpackage.cra`）:
  - `X-Organization-Uuid: {organization_uuid}`
  - `Anthropic-Version: 2023-06-01`
  - `Anthropic-Beta: ccr-byoc-2025-07-29`（エンドポイント側で上書きされる場合あり。例: triggers は `ccr-triggers-2026-01-30`）
  - `User-Agent: {App名/バージョン}`（`cra` 由来）
  - `Accept-Language: ...`
  - `X-Client-Request-Id: {uuid}`
  - `Anthropic-Client-Platform: android`
  - `Anthropic-Client-App`
  - `Anthropic-Client-Version`
  - `Anthropic-Client-Build`
  - `Anthropic-Client-OS-Version`
  - `Anthropic-Device-ID`
- 認証: claude.ai の `sessionKey` クッキー（Web と同じセッション）。OkHttp のクッキージャー経由で送信される。追加の Bearer / `x-api-key` は本クライアントでは確認されない。`x-session-key` / `X-Trusted-Device-Token` を付ける経路（`defpackage.to4`）は別クライアント向けで、sessions API クライアントには確認されない。
- レスポンスの JSON は kotlinx.serialization。フィールド名は下記の通り。

---

## 1. セッション一覧

アプリは少なくとも 2 系統で Code セッションを取得する。

### 1.1 Recents フィード（ホーム/一覧）

- クライアント: `defpackage.gx10`（`fx10` 実装）
- エンドポイント: `GET organizations/{organization_uuid}/recents`
- クエリ:
  - `limit` (Integer)
  - `section` (String, 例: `"recents"`)
  - `cursor` (String)
  - `surfaces` (複数可): `chat`, `project`, `cowork`, `code`, `cowork_chat`, `artifact`, `routine`, `unknown`（`defpackage.zw10`）
  - `include` (複数可): 同じ `zw10` 値
- レスポンス: `RecentsSectionsResponse` (`defpackage.az10` / `bz10`)
  - `sections`: `RecentsSection[]`
    - `id`, `title`, `data`: `RecentsRow[]`, `next_cursor`
  - `degraded_surfaces`, `incomplete_surfaces`
- `RecentsRow` は type で分岐（`defpackage.jy10`）:
  - `"code_session"` → `RecentsRow.Session` (`defpackage.ey10`, serializer `dy10`)
  - `"chat"`, `"cowork_session"`, `"project"` など
- `code_session` 行のフィールド（`defpackage.dy10` / `ey10`）:
  - `id` (String)
  - `kind` (Enum: `COWORK` / `CODE`, `defpackage.n580`)
  - `title` (String)
  - `preview` (String, nullable)
  - `updated_at` (`bgo`, nullable)
  - `unread` (Boolean)
  - `worker_status` (Enum: `RUNNING`, `IDLE`, `REQUIRES_ACTION`, `FAILED`, `UNKNOWN`, `defpackage.t5f`)
  - `needs_input` (Boolean)
  - `is_live` (Boolean)
  - `is_starred` (Boolean)
  - `unavailable_actions` (List)
  - `created_at` (`bgo`, nullable)
  - `routine_fire_reason` (`xm40`, nullable)
  - `routine_fired_at` (`bgo`, nullable)

### 1.2 Code セッション直接一覧

- クライアント: `defpackage.gu80`
- エンドポイント: `GET v1/code/sessions`
- クエリ（`gu80.j`）:
  - `cursor`
  - `limit`
  - `tags` (複数可)
  - `include_trigger_sessions` (Boolean)
  - `trigger_id`
  - `grouping_scope`
  - `statuses` (複数可)
  - `only_trigger_sessions` (Boolean)
- レスポンス: `ListSessionsV2Response` (`defpackage.t2r` / `u2r`)
  - `data`: `SessionSummaryV2[]` (`defpackage.kl80`)
  - `next_cursor`
  - `resume_token`
- `SessionSummaryV2` フィールド:
  - `id`, `environment_id`, `self_hosted_runner_pool_id`, `environment_kind`, `title`, `status`, `tags`, `config`, `worker_status`, `connection_status`, `status_bucket`, `created_at`, `updated_at`, `last_event_at`, `external_metadata`, `unread`, `trigger_id`, `chat_project_id`, `agent_id`, `started_by_account_id`, `session_grouping_id`, `bound_device`
  - `status` は `UNKNOWN/PENDING/REQUIRES_ACTION/RUNNING/IDLE/ARCHIVED`（`defpackage.ni80`）
  - `worker_status` は `RUNNING/IDLE/REQUIRES_ACTION/FAILED/UNKNOWN`（`defpackage.t5f`）

### 1.3 新しい Recents (gRPC) の可能性

- `defpackage.jen` は `RecentsService/ListRecentGroups` を gRPC で呼ぶ実装。
- `RecentsRow` の `"code_session"` を含むかは `未確認`。少なくとも REST 側 (`organizations/.../recents`) と並存している。
- `未確認`: 現在の Code 画面が REST / gRPC どちらを主に使うか。

---

## 2. 1 セッションの transcript 読み込み

- クライアント: `defpackage.gu80`
- 一覧/ページング:
  - `GET v1/code/sessions/{sessionId}/events`
  - クエリ: `cursor`, `sort_order` (例: `"desc"`), `limit` (Integer), `exclude_types` (複数可)
  - レスポンス: `ListClientEventsResponseV2` (`defpackage.ixq` / `jxq`)
    - `data`: `ClientEventV2[]` (`defpackage.yqa` / `zqa`)
    - `next_cursor`
- イベントモデル `ClientEventV2` (`defpackage.zqa`):
  - `event_id`
  - `sequence_num`
  - `event_type` (String)
  - `source`
  - `payload` (任意 JSON オブジェクト `mxo`)
  - `created_at`, `processing_at`, `processed_at`
  - `sent_by_account_id`
- `payload` は `mxo`（JSON object）で、text/content blocks の構造は `未確認`（サーバー側の Claude Code transcript 形式に依存）。アプリ側ではイベント型ごとの分岐が `未確認`。
- `StreamClientEventV2` (`defpackage.vsb0`) も存在し、SSE 用に `received_at` を追加。

---

## 3. ライブ更新（SSE）

### 3.1 セッション transcript のストリーム

- エンドポイント: `GET v1/code/sessions/{sessionId}/events/stream`
- ヘッダ: `Accept: text/event-stream`
- クエリ: `from_sequence_num` (Long)
- 実装: `defpackage.gu80.m(Long from_sequence_num, String sessionId)`
- 用途: 特定セッションの新規イベントを SSE で受信。

### 3.2 セッション一覧のストリーム

- エンドポイント: `GET v1/code/sessions/watch`
- ヘッダ: `Accept: text/event-stream`
- クエリ（`gu80.q`）:
  - `resume_token`
  - `tags` (複数可)
  - `include_trigger_sessions` (Boolean)
  - `trigger_id`
  - `session_ids` (複数可)
- 用途: セッション一覧のライブ更新/再開。

WebSocket は Code セッション用途では確認されない（`未確認`）。

---

## 4. 入力送信（任意）

- セッション作成: `POST v1/code/sessions`（`gu80.b`, body `w9f`）
- セッション更新: `PATCH v1/code/sessions/{sessionId}`（`gu80.p`, body `txf0`）
- イベント送信の正確なエンドポイント/ボディは本解析では `未確認`（`pt80` 内に 409 ハンドリングあり）。
- Channels の remote-control session に対する permission decision:
  - `GET v1/code/channels/{channel_id}/remote-control-sessions/{session_id}/me`
  - `POST v1/code/channels/{channel_id}/remote-control-sessions/{session_id}/me/decision`
- その他: `v1/code/sessions/{sessionId}/share`, `preview-status`, `teleport-events` などが存在（`未確認`）。

---

## 5. ヘッダ一覧（Code API client）

`defpackage.ju80` + `defpackage.njf` + `defpackage.cra` により、実質的に付与されるヘッダ:

- `X-Organization-Uuid`
- `Anthropic-Version: 2023-06-01`
- `Anthropic-Beta: ccr-byoc-2025-07-29`（triggers など一部エンドポイントでは別値）
- `User-Agent`
- `Accept-Language`
- `X-Client-Request-Id`
- `Anthropic-Client-Platform: android`
- `Anthropic-Client-App`
- `Anthropic-Client-Version`
- `Anthropic-Client-Build`
- `Anthropic-Client-OS-Version`
- `Anthropic-Device-ID`
- Cookie: `sessionKey=...`（OkHttp クッキージャー）

---

## 6. Remote Control セッション vs Cloud セッションの区別

- `RecentsRow.Session.kind` (`defpackage.n580`) は `COWORK` / `CODE` の 2 値のみ。
- `SessionResource.tags` に `"cowork-remote"` が含まれるケースがある（`defpackage.wg80.n()`）。
- `SessionResource` には `origin`, `environment_kind`, `bridge_spawn_path` などのフィールドがあり、remote-control / cloud の識別に使われる可能性があるが、正確な enum 値は `未確認`。
- Channels 配下の `remote-control-sessions` は別系統（`v1/code/channels/{channel_id}/remote-control-sessions/...`）。

---

## 7. 主要ソースファイル

- `defpackage.gx10.java` — recents REST
- `defpackage.dy10.java`, `ey10.java` — RecentsRow.Session
- `defpackage.zw10.java` — surfaces enum
- `defpackage.gu80.java` — v1/code/sessions, events, stream, watch
- `defpackage.t2r.java`, `u2r.java` — ListSessionsV2Response
- `defpackage.kl80.java` — SessionSummaryV2
- `defpackage.vg80.java`, `wg80.java` — SessionResource
- `defpackage.yqa.java`, `zqa.java` — ClientEventV2
- `defpackage.ixq.java`, `jxq.java` — ListClientEventsResponseV2
- `defpackage.ts...` etc
- `defpackage.ju80.java`, `njf.java`, `cra.java` — headers
- `defpackage.ze1.java`, `ie1.java` — base URL
}