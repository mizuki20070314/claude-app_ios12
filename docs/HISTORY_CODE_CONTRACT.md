# サーバー履歴同期 & Claude Code (/rc) セッション表示 — 実装契約

前提: `docs/PLAN.md` (iOS 12 / Swift 5 / UIKit のみ / 外部ライブラリなし) を厳守。
アカウントモード = `SettingsStore.shared.authMode == "claudeAccount" && ClaudeAccountAuth.shared.isLoggedIn`。
認証は `ClaudeAccountClient` と同じ Cookie (`sessionKey=...; lastActiveOrg=...`)。User-Agent は既定のまま (公式アプリを名乗るヘッダ `Anthropic-Client-Platform` 等は送らない)。
組織 ID は `ClaudeAccountClient.shared.resolveOrganizationId(completion:)` を使う (chat 権限の組織が選ばれる)。

## 実 API で確認済みの事実 (2026-11-18, 実アカウントで疎通確認)
### チャット履歴 (base `https://claude.ai/api`)
- 一覧: `GET /organizations/{org}/recents?section=recents&limit=30&surfaces=chat&include=chat[&cursor=...]`
  → `{"sections":[{"id","title","data":[row...],"next_cursor": String?}], "degraded_surfaces":[]}`
  - row (`type == "chat"`): `uuid, name, created_at, updated_at (ISO8601 小数秒あり), is_starred, model, project_uuid, current_leaf_message_uuid, summary, platform`。`type` が chat 以外の行は無視。
  - `next_cursor` を `cursor` に渡すと次ページ。null で終端。
  - 代替 (簡易): `GET /organizations/{org}/chat_conversations?limit=N` は会話オブジェクトの配列を返す (同じフィールド)。
- 1件: `GET /organizations/{org}/chat_conversations/{uuid}?tree=True&rendering_mode=messages&render_all_tools=true`
  → `{uuid, name, model, is_starred, current_leaf_message_uuid, chat_messages:[{uuid, parent_message_uuid, index, sender:"human"|"assistant", text, content:[block], created_at, attachments, files}]}`
  - 数 MB になる場合あり (ツール結果を含む)。
  - 表示ブランチ: `current_leaf_message_uuid` から `parent_message_uuid` を辿ってルートまで → 逆順。leaf が無ければ index 順。
  - content block `type`: `text{text}`, `thinking{thinking}`, `tool_use{name,input,message?}`, `tool_result{name,content,is_error}`, その他 (`voice_note`,`bell`,`flag`,`unknown`) は無視。
- 更新: `PUT /organizations/{org}/chat_conversations/{uuid}` body `{"name": "..."}` / `{"is_starred": true}`
- 削除: `DELETE /organizations/{org}/chat_conversations/{uuid}` → 204

### Claude Code セッション (base `https://claude.ai` — `/api` は付けない!)
- 必須ヘッダ: `Anthropic-Version: 2023-06-01`, `Anthropic-Beta: ccr-byoc-2025-07-29`, `X-Organization-Uuid: {org}` + Cookie。
- 一覧: `GET /v1/code/sessions?limit=50[&cursor=...]` → `{"data":[session], "next_cursor", "resume_token"}`
  - session: `id (String, "session_..." 形式の可能性), title, status ("archived" 等), status_bucket ("completed" 等), worker_status ("idle"/"running"/"requires_action"/"failed"), connection_status ("connected"/"disconnected"), environment_kind ("bridge" = /rc でPCから共有されたリモートコントロール, それ以外 = クラウド), config.origin ("claude_code_cli" 等), config.model, status_line, created_at, updated_at, last_event_at, unread, user_message_count (文字列), external_metadata.post_turn_summary.{status_category,status_detail,recent_action}`。
- イベント: `GET /v1/code/sessions/{id}/events?limit=100&sort_order=asc[&cursor=...]` → `{"data":[event], "next_cursor", "resume_cursor"}`
  - event: `event_id, sequence_num (文字列の数値), event_type, source ("worker"/"client"), created_at, payload`
  - `event_type == "user"`: `payload.message.role == "user"`, `payload.message.content` は **String または block 配列** (`text` / `tool_result{tool_use_id, content (String or [ {type:text,text} ]), is_error}` / `image`)。`payload.isSynthetic == true` はシステム生成 (薄く表示 or 非表示)。
  - `event_type == "assistant"`: `payload.message.content` は block 配列 (`text{text}`, `thinking{thinking}`(空文字のことあり→非表示), `tool_use{id,name,input}`)。`payload.message.model`, `stop_reason`。
  - その他 (`control_request`, `system`, `result` など): 本文には出さない。`result` があれば完了表示に使ってよい。
- ライブ: `GET /v1/code/sessions/{id}/events/stream?from_sequence_num={最後のseq+1}` (`Accept: text/event-stream`, SSE の data は event JSON)。未検証のため、失敗したら 5 秒間隔ポーリング (`events?sort_order=asc&cursor=<resume_cursor>`) にフォールバック。
- 送信 (入力) は今回スコープ外 (表示のみ)。

## 担当と公開 API (シグネチャ厳守)
### Agent H — 履歴サービス (Services/ClaudeHistoryService.swift, Models/Conversation.swift, Services/ConversationStore.swift)
```swift
// Conversation に追加 (Codable, 旧データ互換: decodeIfPresent)
var origin: String?          // nil/"local" = ローカル, "claudeAi" = サーバー
var remoteLoaded: Bool?      // メッセージ本文を取得済みか

final class ClaudeHistoryService {
    static let shared: ClaudeHistoryService
    static let didSync = Notification.Name("ClaudeHistoryService.didSync")
    private(set) var isSyncing: Bool
    var isAvailable: Bool                      // アカウントモードか
    func syncRecents(maxPages: Int = 3, completion: ((Error?) -> Void)? = nil)   // 一覧を取得し ConversationStore にマージ
    func loadConversation(id: String, completion: @escaping (Result<Conversation, Error>) -> Void) // 本文取得→保存→返す
    func rename(id: String, title: String, completion: ((Error?) -> Void)? = nil)
    func setStarred(id: String, starred: Bool, completion: ((Error?) -> Void)? = nil)
    func delete(id: String, completion: ((Error?) -> Void)? = nil)
}
// ConversationStore に追加
func mergeRemote(_ items: [Conversation])     // origin=="claudeAi" を upsert。既存の messages/remoteLoaded は保持、title/updatedAt/isStarred/model は更新。サーバーから消えたものは削除しない。
```
- サーバー会話の `Conversation.id` = サーバー uuid (小文字)。ローカルで作ったアカウントモード会話も送信後は origin="claudeAi" にする (ChatViewController 側)。
- Message 変換: human→.user, assistant→.assistant, text は text ブロックを連結 (無ければ `text` フィールド), thinking ブロックは `thinking` に連結, tool_use は本文末尾に `\n\n> 🔧 ツール: name` の引用行として追加, tool_result は省略。`serverUuid` = サーバー message uuid。日付は ISO8601 (小数秒あり/なし両対応)。
- 失敗時のエラーは `ClaudeAccountError` を再利用 (401/403 は `ClaudeAccountAuth.shared.clearSession()`)。

### Agent C — Code セッションサービス (Services/ClaudeCodeService.swift, Models/CodeSession.swift)
```swift
struct CodeSession { let id: String; var title: String; var status: String; var statusBucket: String?; var workerStatus: String?
    var connectionStatus: String?; var environmentKind: String?; var origin: String?; var model: String?; var statusLine: String?
    var updatedAt: Date?; var lastEventAt: Date?; var unread: Bool
    var isRemoteControl: Bool { environmentKind == "bridge" }   // /rc で共有された PC のセッション
    var isLive: Bool { connectionStatus == "connected" || workerStatus == "running" || workerStatus == "requires_action" } }
enum CodeTranscriptItem {
    case user(text: String, isSynthetic: Bool, date: Date?)
    case assistant(text: String, date: Date?)
    case thinking(text: String)
    case toolUse(id: String, name: String, summary: String)        // summary: input の主要値 (command / file_path / pattern / url / description) を1行で
    case toolResult(toolUseId: String, text: String, isError: Bool) // text は最大 2000 文字に切り詰め
    case status(text: String)                                        // result 等の補助表示
}
final class ClaudeCodeService {
    static let shared: ClaudeCodeService
    func listSessions(cursor: String? = nil, completion: @escaping (Result<(sessions: [CodeSession], nextCursor: String?), Error>) -> Void)
    func loadTranscript(sessionId: String, completion: @escaping (Result<(items: [CodeTranscriptItem], lastSequence: Int), Error>) -> Void) // 全ページ取得 (最大 3000 イベント)
    func subscribe(sessionId: String, fromSequence: Int, onItems: @escaping ([CodeTranscriptItem]) -> Void, onSessionUpdate: ((CodeSession) -> Void)?) -> CodeSessionSubscription // SSE、失敗時ポーリング
}
final class CodeSessionSubscription { func cancel() }
```
- コールバックはすべてメインスレッド。

### Agent U — UI (UI/Code/*, UI/Sidebar/*, UI/Chat/ChatViewController.swift, App/AppRouter.swift, App/DemoData.swift, Resources/*/Code.strings)
- サイドバー: アカウントモードでは起動時と下引き更新 (UIRefreshControl) で `ClaudeHistoryService.shared.syncRecents()`。ナビ項目に「Claude Code」(アイコン `.code`) を追加 → `AppRouter.shared.openCodeSessions()`。
- `CodeSessionsListViewController`: セクション「リモートコントロール」(isRemoteControl) と「クラウド」。行: タイトル, ステータスバッジ (接続中=緑 / 実行中=アクセント / 要対応=赤 / 完了・アイドル=グレー), status_line or post_turn_summary の1行, 相対日時。下引き更新・次ページ読み込み。アカウントモードでない場合は「claude.ai アカウントでログインすると表示されます」。
- `CodeSessionViewController(session:)`: transcript をチャット風に表示 (user=右バブル, assistant=Markdown 全幅, thinking=折りたたみ, toolUse=小さな等幅の行「⏺ Bash(ls -la)」, toolResult=折りたたみ可能なグレーのボックス、エラーは赤)。ヘッダにステータス・環境 (「PC (リモートコントロール)」/「クラウド」)・モデル。isLive なら subscribe して追記、自動スクロール。入力欄は無し (「表示のみ」注記)。
- ChatViewController: origin=="claudeAi" かつ remoteLoaded != true の会話を開いたらローディング表示して `loadConversation`。アカウントモードで新規作成した会話は送信後 origin="claudeAi"。会話の名前変更/スター/削除はサイドバーから `ClaudeHistoryService` 経由でサーバーにも反映。
- AppRouter: `func openCodeSessions()`, `func openCodeSession(_ session: CodeSession)`。スクリーンショット画面 `code_sessions`, `code_session` (デモデータ, ネットワークなし) と、DEBUG ライブ画面 `account_history` (同期→サイドバー表示) / `account_code` (Code 一覧→先頭セッションを開く)。ライブ画面は完了時 `Documents/account_live_result.json` に `{"ok":Bool,"error":String,"stage":String,"counts":{...件数のみ}}` を書く (内容・タイトルは書かない)。
