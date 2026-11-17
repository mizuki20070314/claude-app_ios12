# Claude Android アプリ (com.anthropic.claude) iOS 12 再実装 UI 仕様書

対象 APK: `com.anthropic.claude` (base) + `config.ja` 等。リソース名は R8 により難読化されているため、文字列リソース名は `APKTOOL_DUMMYVAL_0x7f...` 形式 (実 ID) で記載する。日本語は `config.ja.apk` の aapt2 ダンプから取得した同 ID の値。

---

## 0. 全体構成

- UI: Jetpack Compose (Material3 系カスタムテーマ)。Navigation Compose。
- ルート Destination (`ClaudeAppDestination`):
  - `LoggedOutApp` / `LoginApp`: 未ログイン
  - `ClaudeApp`: ログイン後 (Chat, AllChatsList, AllProjectsList, ProjectDetails, Settings, ArtifactGallery, Code*, AgentChat, Cowork* 等)
- 主要機能: チャット、プロジェクト、Artifacts、添付、Web 検索/リサーチ、音声モード、コード/リモートセッション、共有、記憶 (Memory)、使用量/プラン。

---

## 1. 画面一覧と遷移

### 1.1 ログイン / オンボーディング (`LoginApp`)
- **レイアウト**: フルスクリーン。ロゴ + 説明 + 「続行」ボタン。Google/Apple/Mail サインイン。
- **主な文字列**:
  - `APKTOOL_DUMMYVAL_0x7f140025` "To verify your age, sign in at claude.ai in a web browser..." / ja: "年齢確認のため、Web ブラウザで claude.ai にサインインしてください..."
  - `APKTOOL_DUMMYVAL_0x7f140033` "Sign out" / ja: "サインアウト"
  - `APKTOOL_DUMMYVAL_0x7f14002f` "Open in browser"
- **アクション**: 年齢確認、アカウント追加、同意 (Terms/Usage Policy リンク)。

### 1.2 ホーム / 新規チャット (空状態)
- **レイアウト**: 中央に「Claude に何でも質問してください」+ 入力欄。下部に提案チップ。
- **主な文字列**:
  - `APKTOOL_DUMMYVAL_0x7f140055` "Ask Claude anything" / ja: "Claude に何でも質問してください" (※aapt2 では 0x7f140058)
  - `APKTOOL_DUMMYVAL_0x7f14005a` "Claude works from your computer" / ja: "Claude はパソコンから動作します"
  - `APKTOOL_DUMMYVAL_0x7f140056` "Send tasks from your phone..." / ja: "スマートフォンからタスクを送信できます..."
  - `APKTOOL_DUMMYVAL_0x7f140a01` / `0x7f141542` "New chat" / ja: "新規チャット"
- **アクション**: 新規チャット作成、音声入力開始 (`APKTOOL_DUMMYVAL_0x7f14005b` "Start speech input")。

### 1.3 チャット画面 (`Detail.Chat`)
- **レイアウト**: 上部 AppBar (タイトル、モデル表示、メニュー)、メッセージリスト (ユーザーバブル右、Claude 左)、下部入力欄 + 添付/送信。
- **コンポーネント**: Markdown レンダリング、コードブロック、Artifacts カード、ツール呼び出し表示、Extended thinking 表示 ("Thinking…")。
- **主な文字列**:
  - `APKTOOL_DUMMYVAL_0x7f140707` "Thinking…" / ja: "思考中…"
  - `APKTOOL_DUMMYVAL_0x7f1408f5` "Extended thinking" / ja: "拡張思考"
  - `APKTOOL_DUMMYVAL_0x7f140878` "Claude can’t help with this. Start a new chat to continue."
  - `APKTOOL_DUMMYVAL_0x7f140c4f` "Attachment limit reached for this chat. Start a new chat to add more."
  - `APKTOOL_DUMMYVAL_0x7f140c52` "Claude has ended this conversation. Start a new chat to continue."
- **アクション**: 送信、添付追加、モデル変更、チャットオプション (名前変更/削除/共有/スター)、再試行、コピー、サムズアップ/ダウン、サイドチャット。

### 1.4 サイドバー / ドロワー (`AllChatsList`)
- **レイアウト**: 左ドロワー。上部「新規チャット」、検索、会話リスト (日付グループ)、プロジェクト一覧、設定リンク。
- **主な文字列**:
  - `APKTOOL_DUMMYVAL_0x7f140013` "Search…" / ja: "検索…"
  - `APKTOOL_DUMMYVAL_0x7f140014` "Clear query" / ja: "検索キーワードを削除"
  - `APKTOOL_DUMMYVAL_0x7f140016` "Search" / ja: "検索"
  - `APKTOOL_DUMMYVAL_0x7f14001b` "Collapse" / ja: "折りたたむ"
  - `APKTOOL_DUMMYVAL_0x7f140c40` "Ask Claude anything. Your chats with Claude will show up here." / ja: "Claude に何でも質問してください。Claude とのチャットがここに表示されます。"
- **アクション**: 会話選択、検索、新規チャット、プロジェクトへ移動、設定を開く。

### 1.5 検索
- `AllChatsList` 内の検索モード。上記文字列を使用。フィルタ結果リスト。

### 1.6 プロジェクト一覧 (`AllProjectsList`)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f1405ba` "Go to projects" / ja: "プロジェクトに移動"
  - `APKTOOL_DUMMYVAL_0x7f1405be` "Projects aren’t available to you right now."
  - `APKTOOL_DUMMYVAL_0x7f1405c0` "This project couldn’t be found..."
- **アクション**: プロジェクト作成/参加。

### 1.7 プロジェクト詳細 (`ProjectDetails`)
- **レイアウト**: プロジェクト名/アイコン、説明、ファイル/ナレッジ、チャット一覧。
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f1406a6` "Project name and icon" / ja: "プロジェクト名とアイコン"
  - `APKTOOL_DUMMYVAL_0x7f1406a8` "Project name" / ja: "プロジェクト名"
  - `APKTOOL_DUMMYVAL_0x7f1406a7` "Project icon" / ja: "プロジェクトアイコン"
  - `APKTOOL_DUMMYVAL_0x7f1406aa` "Couldn’t update the project’s name or icon. Try again."
  - `APKTOOL_DUMMYVAL_0x7f1405c1` "Project" / ja: "プロジェクト"
  - `APKTOOL_DUMMYVAL_0x7f140864` "Add to project" / ja: "プロジェクトに追加"
  - `APKTOOL_DUMMYVAL_0x7f140868` "Change project" / ja: "プロジェクトを変更"
  - `APKTOOL_DUMMYVAL_0x7f140770` "Always allow for this project" / ja: "このプロジェクトでは常に許可"
- **アクション**: 名前/アイコン編集、ナレッジ追加、メンバー管理、設定。

### 1.8 プロジェクトナレッジ / メモリ
- `ProjectKnowledge`, `ProjectMemory`, `ProjectMemoryFile`, `ProjectAccountMemoryFiles`。
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f141173` "Memory settings" / ja: "メモリ設定"
  - `APKTOOL_DUMMYVAL_0x7f141170` "Claude uses memory to build your reflection..."
  - `APKTOOL_DUMMYVAL_0x7f14114a` "Couldn’t delete your stored reflections..."

### 1.9 設定 (`Settings`)
- **レイアウト**: セクションリスト (アカウント、プライバシー、記憶、通知、音声モード言語、使用量/プラン、フィードバック、ヘルプ、ログアウト)。
- **主な文字列**:
  - `APKTOOL_DUMMYVAL_0x7f14029b` / `0x7f14029c` / `0x7f140ca4` "Settings"
  - `APKTOOL_DUMMYVAL_0x7f140a9a` / `0x7f140a9b` "Sharing settings"
  - `APKTOOL_DUMMYVAL_0x7f140c7e` "Couldn’t save your notification settings. Try again."
  - `APKTOOL_DUMMYVAL_0x7f140fc3` "Voice mode language" / ja: "音声モードの言語"
  - `APKTOOL_DUMMYVAL_0x7f141578` "Privacy settings" / ja: "プライバシー設定"
  - `APKTOOL_DUMMYVAL_0x7f140fcf` "Allow the use of your chats... Change anytime in privacy settings."
- **サブページ**: アカウントオプション、プラン使用量 (`PlanUsage`, `PlanUsageTransactions`)、個人財務、通知設定、音声モード設定。

### 1.10 モデルピッカー (`ModelSelectorBottomSheet`)
- **レイアウト**: ボトムシート。モデル一覧 (Opus/Sonnet/Haiku) + Extended thinking トグル。
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f1408f5` "Extended thinking" / ja: "拡張思考"
  - `APKTOOL_DUMMYVAL_0x7f140f96` "You can turn off automatic model switching in settings."
- **モデル ID (コード内)**: `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`。その他 Opus 系はサーバー駆動で名称表示。

### 1.11 添付メニュー (`ChatScreenFileSheet` / input/files)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f14004a` "Add attachment" / ja: "添付ファイルを追加"
  - `APKTOOL_DUMMYVAL_0x7f14004b` "Image attachment" / ja: "画像の添付"
  - `APKTOOL_DUMMYVAL_0x7f140080` "Remove attachment"
  - `APKTOOL_DUMMYVAL_0x7f14089a` "You can add at most %1$d attachments to a message."
  - `APKTOOL_DUMMYVAL_0x7f1408a1` "This file was changed, moved or deleted after you attached it. Attach it again."
  - `APKTOOL_DUMMYVAL_0x7f1408aa` "Show attachments"
  - `APKTOOL_DUMMYVAL_0x7f1408b7` "Waiting for attachments to upload"
  - `APKTOOL_DUMMYVAL_0x7f1408bd` "Couldn’t upload attachment. Tap it to try again."
  - `APKTOOL_DUMMYVAL_0x7f1408be` "Voice Mode" (添付メニュー内の音声?)
  - `APKTOOL_DUMMYVAL_0x7f140cb7` "File attachment preview"
  - `APKTOOL_DUMMYVAL_0x7f140cb8` "Image attachment preview"
  - `APKTOOL_DUMMYVAL_0x7f1418f7` "Show next attachment"
  - `APKTOOL_DUMMYVAL_0x7f1418f8` "Show previous attachment"
- **アクション**: カメラ/写真/ファイル選択、アップロード進捗、プレビュー、削除。

### 1.12 アーティファクトビューア (`ArtifactGallery` / `ChatScreenArtifactSheet`)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f1400c3` "This artifact can’t be opened from the home screen right now."
  - `APKTOOL_DUMMYVAL_0x7f1400c5` "Report artifact"
  - `APKTOOL_DUMMYVAL_0x7f1400c8` "Artifact Warning"
  - `APKTOOL_DUMMYVAL_0x7f1400ca` "Artifact comment sent to Claude"
  - `APKTOOL_DUMMYVAL_0x7f1400ef` "This artifact can add comments with your name attached..."
  - `APKTOOL_DUMMYVAL_0x7f1400f1` "Show in artifact"
  - `APKTOOL_DUMMYVAL_0x7f1400fe` / `0x7f1400ff` "This artifact is over the 1 MB limit..."
  - `APKTOOL_DUMMYVAL_0x7f14010a` "Your account doesn’t allow editing artifacts."
  - `APKTOOL_DUMMYVAL_0x7f14010b` ... `0x7f140114` 削除確認系
  - `APKTOOL_DUMMYVAL_0x7f14012d` "No artifacts yet"
  - `APKTOOL_DUMMYVAL_0x7f14014a` "Choose a type of artifact to list"
  - `APKTOOL_DUMMYVAL_0x7f140167` "New artifact"
  - `APKTOOL_DUMMYVAL_0x7f140168` "New artifact or folder"
  - `APKTOOL_DUMMYVAL_0x7f140169` "No artifacts match"
  - `APKTOOL_DUMMYVAL_0x7f14016a` "Open artifact"
  - `APKTOOL_DUMMYVAL_0x7f14016b` / `0x7f14016e` ... `0x7f14017e` ピン/リネーム/検索/選択系
  - `APKTOOL_DUMMYVAL_0x7f140180` "This artifact’s own icon"
- **アクション**: 開く、共有、公開、コメント送信、削除、名前変更、ピン。

### 1.13 ボイスモード (Voice Mode)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f140254` "Starting voice mode…"
  - `APKTOOL_DUMMYVAL_0x7f140260` "Please enable the microphone permission to use voice mode."
  - `APKTOOL_DUMMYVAL_0x7f1408be` "Voice Mode"
  - `APKTOOL_DUMMYVAL_0x7f140d19` "speech, dictation, voice mode, language"
  - `APKTOOL_DUMMYVAL_0x7f140fc3` "Voice mode language"
  - `APKTOOL_DUMMYVAL_0x7f1418bd` "Claude will not ask you to share audio recordings..."
  - `APKTOOL_DUMMYVAL_0x7f1418c4` "Voice mode ended while you were away"
  - `APKTOOL_DUMMYVAL_0x7f1418c5` "You’re offline. Voice mode needs an internet connection."
  - `APKTOOL_DUMMYVAL_0x7f1418c6` "Your device can’t play audio right now. Exit voice mode and try again."
  - `APKTOOL_DUMMYVAL_0x7f1418cc` "Voice mode can’t start during a call"
  - `APKTOOL_DUMMYVAL_0x7f1418d3` "Voice mode unavailable"
  - `APKTOOL_DUMMYVAL_0x7f1418d4` "Voice mode needs an internet connection."
  - `APKTOOL_DUMMYVAL_0x7f1418d5` "Exit voice mode and try again later"
  - `APKTOOL_DUMMYVAL_0x7f1418e8` "Voice mode is on in another window"
  - `APKTOOL_DUMMYVAL_0x7f1418ea` / `0x7f1418eb` / `0x7f1418ec` / `0x7f1418ed` / `0x7f1418ee` / `0x7f1418ef` / `0x7f1418f0` / `0x7f1418f1` / `0x7f1418f2` / `0x7f1418f3` / `0x7f1418f5` 移動/終了系
  - `APKTOOL_DUMMYVAL_0x7f141902` "Voice mode from your home screen"
- **アクション**: 開始/終了、ミュート、割り込み、移動 (別ウィンドウ)、通知。

### 1.14 共有 (`ChatShareDestination` / `SharedChatModalBottomSheet`)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f1408eb` "This chat’s project was upgraded. Keep working in the new project."
  - `APKTOOL_DUMMYVAL_0x7f140970` "Shared snapshot may contain attachments and data not displayed here..."
  - `APKTOOL_DUMMYVAL_0x7f1409ee` "Ask Claude to build a feature, fix a bug, or explain your code."
- **アクション**: リンク共有、スナップショット作成、権限設定。

### 1.15 チャットオプション (`ChatOptionsBottomSheet`)
- **文字列**: 名前変更、削除、スター、共有、プロジェクト移動、モデル変更。
  - `APKTOOL_DUMMYVAL_0x7f140770` "Always allow for this project"
  - `APKTOOL_DUMMYVAL_0x7f140762` "To review and save it, open this project on claude.ai."
  - `APKTOOL_DUMMYVAL_0x7f14075f` "Only the project’s owner can answer this."

### 1.16 コード / リモートセッション (`CodeRemoteSession`, `CodeSessionOverview` 等)
- **文字列**:
  - `APKTOOL_DUMMYVAL_0x7f14032b` "Your computer is busy with other sessions. Ask Claude again in a few minutes."
  - `APKTOOL_DUMMYVAL_0x7f14032d` "That folder isn’t available from your computer right now..."
  - `APKTOOL_DUMMYVAL_0x7f14032e` "Claude on your computer needs an update..."
  - `APKTOOL_DUMMYVAL_0x7f140331` "Your computer isn’t connected right now..."
  - `APKTOOL_DUMMYVAL_0x7f140332` "Remote Control is off on your computer..."
  - `APKTOOL_DUMMYVAL_0x7f140333` "Your computer couldn’t start the connection..."
  - `APKTOOL_DUMMYVAL_0x7f140335` "Ask Claude to use your computer again."
  - `APKTOOL_DUMMYVAL_0x7f140336` "Your computer can’t do this right now..."
  - `APKTOOL_DUMMYVAL_0x7f140394` / `0x7f140395` / `0x7f140396` シークレット関連
  - `APKTOOL_DUMMYVAL_0x7f1403b8` / `0x7f1403ce` / `0x7f1403da` / `0x7f1403dd` ターミナル手順
- **アクション**: 接続、セッション開始/停止、PR 作成、環境設定。

---

## 2. カラーパレット

### 主要色 (Compose)
| 用途 | Hex | リソース ID |
|---|---|---|
| アクセント (Claude Clay) | #D97757 | `0x7f060036` |
| アクセント (dark) | #C6613F | `0x7f060038` |
| 背景 (light) | #F0EFEC | `0x7f06001e` |
| 背景 (dark) | #0B0B0B | `0x7f060035` |
| サーフェス (light) | #FFFFFF | `0x7f060034` |
| テキスト primary (light) | #141413 | `0x7f06044e` |
| テキスト secondary | #616161 | `0x7f06044f` |
| ボーダー | #E7E6E1 | `0x7f060042` |
| ユーザーバブル | #F3F3F0 | `0x7f06003d` |
| エラー | #D93025 | `0x7f06002e` |
| 成功 | #1D873B | `0x7f06002d` |

### 全色リソース (colors.xml 抜粋)
#00000000, #14000000, #1A29261B, #1F000000, #1FFFFFFF, #26000000, #33FFFFFF, #39000000, #4DFFFFFF, #DE000000, #E6616161, #E6FFFFFF, #FF006876, #FF008577, #FF028394, #FF051221, #FF0B0B0B, #FF131313, #FF131314, #FF132539, #FF141413, #FF198639, #FF1C1B1F, #FF1C2B42, #FF1D192B, #FF1D873B, #FF1F1F1F, #FF1F3F28, #FF21005D, #FF212121, #FF303030, #FF31111D, #FF313033, #FF410E0B, #FF424242, #FF474747, #FF485C75, #FF49454F, #FF4A2F27, #FF5A595B, #FF5E5E5E, #FF616161, #FF625B71, #FF6750A4, #FF6DD58C, #FF757575, #FF75D4E6, #FF79747E, #FF7B7974, #FF7D5260, #FF7FA87F, #FF80CBC4, #FF875334, #FF91674D, #FF949494, #FF9FEFFF, #FFABABAB, #FFB3261E, #FFBA8F63, #FFBB33D7, #FFBDBDBD, #FFC4EED0, #FFC6613F, #FFCE3B3B, #FFD0BCFF, #FFD2F7FF, #FFD6D7D7, #FFD93025, #FFD97757, #FFDC362E, #FFE0F3FF, #FFE3E3E3, #FFE7E0EC, #FFE7E6E1, #FFE8DEF8, #FFEADDFF, #FFEDBD82, #FFF0EFEC, #FFF1F1F1, #FFF2B8B5, #FFF2DDF9, #FFF2F2F2, #FFF3F3F0, #FFF4EFF4, #FFF5F5F5, #FFF5F5FF, #FFF9DEDC, #FFF9F9F7, #FFFAF9F5, #FFFCF0FF, #FFFF5722, #FFFF7043, #FFFFBB29, #FFFFD8E4, #FFFFFBF0, #FFFFFBFE, #FFFFFFFF

---

## 3. タイポグラフィ

- **フォント (assets)**:
  - Anthropic Sans (`anthropic_sans.ttf`, `anthropic_sans_italic.ttf`)
  - Anthropic Serif (`anthropic_serif.ttf`, `anthropic_serif_italic.ttf`)
  - JetBrains Mono (`jetbrains_mono.ttf`) — コードブロック
  - trimmed-math (`trimmed-math.otf`) — 数式
- **フォント (res/font)**: Google Sans / Google Sans Text (GMS ダウンロードフォント)
- **サイズ**: Compose の Typography は難読化済みで正確な sp 値は未抽出。一般的に body 14–16sp、見出し 20–28sp。dimens.xml には 14sp (`0x7f07002b`) 等。

---

## 4. 機能一覧

- モデル: Claude Sonnet 4.6, Claude Haiku 4.5 (2025-10-01)、その他サーバー駆動 (Opus 系)。
- Extended thinking (拡張思考) トグル。
- プロジェクト: 作成/参加、ナレッジ/ファイル、メモリ、メンバー、アイコン/名前編集。
- Artifacts: 作成/表示/共有/公開/コメント/削除/ピン/名前変更。
- 添付: 画像/ファイル、カメラ、アップロード進捗、プレビュー、制限 (メッセージあたり最大 N)。
- Web 検索 / リサーチ (Research)、コネクタ (Notion 等)。
- 音声モード (Voice Mode): マイク、割り込み、言語設定、移動 (別ウィンドウ)。
- コード / リモートセッション (Claude Code 連携): セッション一覧、PR、環境、シークレット。
- 共有: チャット共有リンク、スナップショット。
- 会話管理: 名前変更、削除、スター、アーカイブ。
- 記憶 (Memory): リフレクション、設定。
- 使用量/プラン: Plan usage、トランザクション。
- 通知、プライバシー設定、フィードバック、ヘルプ。

---

## 5. API エンドポイント (参考)

- `https://api.anthropic.com` / `https://api.claude.ai`
- `https://claude.ai` ( `/artifacts/my`, `/connect/github/callback`, `/customize/connectors`, `/login?via=open_on_web`, `/report`, `/settings/billing` )
- `/api/v2/profile`, `/api/v2/rum`, `/api/v2/spans`
- `/api/organizations/{organization_uuid}/projects/{project_uuid}/files`
- `/api/organizations/.../grantable_share_groups`, `.../members/display_info`, `.../members_v2`
- `/api/enterprise_auth/sso_callback`, `/api/mcp/auth_callback`, `/mobile/api/mcp/auth_callback`
- `/api/yoti/age-verification/start`
- `/api/frame/`, `/api/tokens/`, `/api/RateLimit`
- `v1/code/triggers/{triggerId}/api-token`
- `https://claude.ai/code/artifact/...`, `https://claude.ai/artifact/...`
- ディープリンク: `claude://claude.ai/chat/`, `claude://claude.ai/settings/usage`

---

## 6. アイコン

主要ベクターアイコンの pathData は `docs/ICONS.md` を参照。代表的な drawable 名:

- `cds_icon_create` (プラス/新規作成)
- `cds_icon_search`
- `cds_icon_microphone`, `cds_icon_microphone_slash`
- `cds_icon_caret_right`
- `cds_icon_arrow_clockwise` (再試行)
- `cds_icon_chats`, `cds_icon_projects`, `cds_icon_artifacts`, `cds_icon_code`, `cds_icon_file`, `cds_icon_image`, `cds_icon_globe`, `cds_icon_voice`, `cds_icon_camera`, `cds_icon_tasks`, `cds_icon_shapes`, `cds_icon_dispatch`, `cds_icon_scroll`
- `claude_spark_icon` (Claude ロゴ, #D97757)
- `claude_logotype`
- `onboarding_x`, `onboarding_check`
- `plaid_ic_close`, `plaid_ic_error_warning`
- `ic_shortcut_new_chat`, `ic_shortcut_voice`, `ic_shortcut_code`, `ic_shortcut_cowork`

送信矢印・星・設定ギア・サムズアップ/ダウン・コピーは Compose Material Icons を使用 (APK drawables には無し)。iOS では SF Symbols で代替推奨。

---

## 7. ギャップ / 未抽出項目

- リソース名は難読化されており、元の `R.string.xxx` 名は復元不可。
- Compose Typography の正確な sp 値は難読化のため未抽出 (dimens.xml から一部)。
- 一部の ja 文字列は config.ja.apk に存在しない (英語フォールバック)。
- ダークテーマの Compose ColorScheme 全体は未抽出 (colors.xml と主要 hex から推定)。
- コード内のモデル一覧はサーバー駆動のため、完全なモデルリストは API レスポンス依存。
