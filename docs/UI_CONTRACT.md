# UI 実装の共通契約 (フェーズ2: 4エージェント並列)

`docs/PLAN.md` (iOS 12 制約), `docs/SPEC.md` (Android版の解析), `docs/SERVICES.md` (モデル/サービス API), `docs/ICONS.md` (アイコン path) を先に読むこと。
他エージェントのファイルは編集しない。必要な型・メソッドは **このファイルのシグネチャ通り** に存在する前提でコードを書く (実装は担当者が行う)。

## 再現する Android 版 Claude アプリの UI (要点)
- 全体: 温かみのあるオフホワイト背景 (`Theme.current.background`)、アクセントはクレイ (#D97757)。ナビバーは背景と同色でボーダーなし (影なし)。
- **ホーム (新規チャット)**: 上部バー = 左にハンバーガー(≡)、中央は空 or "Claude"、右に新規チャット(ペン)アイコン。中央に Claude スパーク(放射状のオレンジ ✻ ロゴ)と挨拶 (セリフ体 28pt 程度):「こんにちは、{userName}さん」/ 名前が空なら「今日はどのようなお手伝いができますか？」。下部にコンポーザー。
- **コンポーザー**: 角丸 (24pt) のカード (`composerBackground`, 1px `border`, 薄い影)。上段に複数行 UITextView (プレースホルダー「Claude に何でも質問してください」, 最大 ~6行で内部スクロール)、下段に左から「＋」(添付) ボタン, 「⏱/思考」トグル(拡張思考オン時アクセント色), 右側にモデル名ボタン (例 "Sonnet 5.5 ⌄", 小さいグレー文字), 送信ボタン (丸 32pt, `sendButton` 背景に白い↑矢印。テキスト空なら非表示にしてマイク(音声入力)アイコン表示…音声は iOS 12 では未対応メッセージで可)。ストリーミング中は送信ボタンが停止(■)ボタンになる。添付がある場合はテキスト上部にサムネイル横スクロール (×で削除)。
- **チャット**: 上部バー = ≡ / 中央に会話タイトル (タップでチャットオプション) / 右に新規チャット。ユーザーメッセージは右寄せのバブル (`userBubble`, 角丸 18, 最大幅 80%)。アシスタントは**バブルなしの全幅テキスト** (Markdown, 本文 16pt)。アシスタント応答下にアクション行: コピー, 再試行(↻), 👍, 👎 (小さいグレーアイコン)。ストリーミング中はアシスタント先頭にスパークがパルス(アニメ)。拡張思考は折りたたみ可能な「思考プロセス」ボックス (`thinkingBackground`, タップで展開, ストリーミング中「思考中…」)。エラーは赤系テキスト + 「再試行」ボタン。
- **サイドバー (ドロワー)**: 左からスライド (iPhone: 幅 = min(画面幅*0.82, 320), 背景を暗幕で覆い、タップ/左スワイプで閉じる。画面左端からのスワイプで開く)。iPad (横幅 >= 700pt) は常時表示の左カラム (300pt)。内容: 上部に "Claude" ロゴタイプ(セリフ体) と検索アイコン、「＋ 新規チャット」(アクセント色の丸アイコン)、ナビ項目「チャット」「プロジェクト」「アーティファクト」、セクション見出し「スター付き」「最近」の会話リスト (タイトル1行, 選択中は `sidebarSelected`)、最下部にユーザー行 (イニシャルの丸アバター + 名前 + 歯車→設定)。会話行の長押しでメニュー (スター/名前変更/削除)。
- **ボトムシート**: Android の ModalBottomSheet 相当。上部角丸 16, グラバー, 暗幕。モデル選択・チャットオプション・添付メニューで使用。
- 文字列は日本語優先 (ja.lproj)、en.lproj も用意。キーは各エージェントで接頭辞を分ける (`home.` `chat.` `sidebar.` `settings.` `onboarding.` `projects.` `artifact.` `common.`)。**Localizable.strings は衝突回避のため各エージェント専用ファイル** を使う: `Resources/ja.lproj/<Area>.strings` を作り `NSLocalizedString(key, tableName: "<Area>", comment: "")` で読む。ヘルパー `L(_ key: String, _ table: String = "Localizable")` に拡張する (Localization.swift は Agent A が変更)。

## 担当とファイル所有権
### Agent A — 基盤/ナビゲーション/サイドバー
- `Theme/Icons.swift`: `enum IconName { case menu, newChat, plus, send, stop, mic, search, close, chevronRight, chevronDown, chevronLeft, copy, retry, thumbsUp, thumbsDown, star, starFill, settings, trash, pencil, share, chat, project, artifact, image, camera, file, globe, thinking, check, more, sparkle, sidebar, back, info, key, moon, sun, logout, folder, code, eye }`
  `enum Icons { static func image(_ name: IconName, size: CGFloat = 20, color: UIColor) -> UIImage }` (SVG path 文字列パーサ→UIBezierPath, 描画結果キャッシュ。ICONS.md の pathData を利用、無いものは自作)
  `final class SparkView: UIView` (Claude スパークロゴ, `color`, `func startPulsing()`, `func stopPulsing()`)
- `App/AppDelegate.swift`, `App/AppRouter.swift`, `App/Localization.swift`, `App/DemoData.swift`
- `UI/Common/`: `BottomSheetController`, `IconButton`, `ThemedNavigationController`, 共通ヘルパー
  - `final class BottomSheetController: UIViewController { static func present(_ content: UIViewController, from presenter: UIViewController) }` content は `preferredContentSize.height` で高さを指定 (最大 画面の 85%)。
  - `final class IconButton: UIButton { init(icon: IconName, size: CGFloat = 22, tint: UIColor? = nil) ; var icon: IconName ; func refreshColor() }`  (44x44 タップ領域)
  - `final class ThemedNavigationController: UINavigationController` (背景色/タイトル色/影なしを Theme から適用, `Theme.didChange` 追従, preferredStatusBarStyle)
- `UI/Root/RootViewController.swift`: ドロワー/分割レイアウトのコンテナ。
- `UI/Sidebar/SidebarViewController.swift`, `UI/Sidebar/SearchViewController.swift`, `UI/Sidebar/ConversationListViewController.swift` (「チャット」一覧, スター/最近, 日付グループ)
- **AppRouter API (他エージェントが呼ぶ)**:
  ```swift
  final class AppRouter {
      static let shared: AppRouter
      static var screenshotScreen: String? { get }
      var window: UIWindow?
      func start(window: UIWindow)
      func startNewChat(projectId: String? = nil)     // ChatViewController(conversationId: nil, projectId:)
      func openConversation(id: String)
      func openSettings()                              // SettingsViewController をモーダル(ThemedNavigationController)で
      func openProjects()                              // ProjectsListViewController をメイン領域に
      func openProject(id: String)
      func openArtifacts()                             // ArtifactsGalleryViewController
      func openSearch()
      func toggleSidebar()
      func closeSidebar()
      func finishOnboarding()                          // オンボーディング完了→ホーム
      func signOut()                                   // APIキー削除→オンボーディング
      var topViewController: UIViewController? { get }
  }
  ```
  メイン領域の VC は `ThemedNavigationController` に包み、左に ≡ ボタン (`IconButton(icon: .menu)` → `AppRouter.shared.toggleSidebar()`) を各 VC が自分で置く (iPad 常時表示時は非表示にするため `AppRouter.shared.isSidebarPersistent: Bool` を参照)。
- **スクリーンショットモード** (`-screenshot <name>`): DemoData でストアにデモデータを投入 (ディスクに書かない), APIキーはダミー扱いでオンボーディングをスキップ (onboarding 以外)。
  `onboarding` → OnboardingViewController / `home` → 新規チャット / `chat` → `openConversation(id: "demo-chat")` / `sidebar` → home + ドロワーを開いた状態 / `models` → chat + `ModelPickerViewController` をシート表示 / `settings` → openSettings / `projects` → openProjects / `project_detail` → openProject(id: "demo-project") / `search` → openSearch (クエリ「Swift」入力済み) / `artifact` → `ArtifactViewController(title: "Todo アプリ", language: "html", code: DemoData.sampleHTML)` / `dark_chat`, `dark_home` → `Theme.forcedDark = true` で chat/home。
  DemoData: 会話 8件程度 (日本語タイトル, 日付分散, 2件スター, 1件 projectId="demo-project")。"demo-chat" は: ユーザー「SwiftでFizzBuzzを書いて」→ 思考あり → 見出し・箇条書き・太字・インラインコード・```swift コードブロック・番号付きリストを含む応答 → ユーザー2通目(画像添付1つ: 単色で生成した UIImage を JPEG base64) → アシスタント短い応答。プロジェクト3件 ("demo-project" = 「iOS アプリ開発」, 指示文とナレッジ2件)。

### Agent B — チャット/ホーム/コンポーザー/モデル選択
- `UI/Chat/ChatViewController.swift`: `init(conversationId: String?, projectId: String?)` — conversationId nil ならホーム(空状態=挨拶)を表示し、最初の送信で会話を作成。
- `UI/Chat/ComposerView.swift`, `UI/Chat/MessageCells.swift` (または複数ファイル), `UI/Chat/ThinkingView.swift`, `UI/Chat/AttachmentStripView.swift`, `UI/Chat/ChatOptionsSheet.swift` (名前変更/スター/プロジェクトに追加/共有(UIActivityViewController でテキスト)/削除), `UI/Chat/AttachmentMenuSheet.swift` (写真ライブラリ/カメラ/ファイル(UIDocumentPickerViewController, テキスト系 UTI))
- `UI/Chat/ModelPickerViewController.swift`: `init(selectedId: String, onSelect: @escaping (ModelOption) -> Void)` — モデル一覧 (名前+説明, 選択中にチェック) + 下部に「拡張思考」スイッチ。BottomSheetController で表示。
- 送信処理: AnthropicClient.streamMessage, ストリーミング更新は 1/20 秒程度にスロットル, 最下部追従スクロール, 完了時 ConversationStore.save, 初回応答後 generateTitle。停止, 再試行(最後のアシスタント応答を作り直し), メッセージ長押しでコピー/編集。
- `Markdown/MarkdownContentView` を使用 (既存, 変更不要。必要ならラップする)。
- アーティファクト: アシスタント応答内の 15 行以上のコードブロック、または html/svg のコードブロックの下に「アーティファクトカード」(タイトル=言語名/最初の見出し, 「開く」) を表示し、タップで `ArtifactViewController(title:language:code:)` を push。

### Agent C — オンボーディング/設定
- `UI/Onboarding/OnboardingViewController.swift`: ウェルカム (スパークロゴ, セリフ体「Claude へようこそ」, 説明) → API キー入力 (secure text field, 貼り付けボタン, console.anthropic.com への説明, 「続行」で `AnthropicClient.shared.validateKey`, 成功で `SettingsStore.shared.apiKey = key` → `AppRouter.shared.finishOnboarding()`), 失敗時はエラー表示。表示名(任意)入力ステップ。
- `UI/Settings/SettingsViewController.swift` (grouped UITableView, Android の設定画面構成): プロフィール(名前), アカウント(APIキー: マスク表示/変更/削除), 外観(テーマ: システム/ライト/ダーク → `SettingsStore.shared.themeMode` と `Theme.setMode`), モデル(デフォルトモデル, 拡張思考, 思考予算, 最大トークン), スタイル(ノーマル/簡潔/説明的/フォーマル), チャット(Return で送信, 触覚フィードバック), データ(すべての会話を削除 確認アラート), 詳細(API ベース URL), 情報(バージョン, 「Android版 Claude を参考にした非公式クライアント」), サインアウト。サブページは同ディレクトリに作成。
- Theme 初期化: `Theme.setMode` は SettingsStore の値で起動時に呼ぶ必要あり → Agent A の AppDelegate が `Theme.setMode(ThemeMode(rawValue: SettingsStore.shared.themeMode) ?? .system)` を呼ぶ。

### Agent D — プロジェクト/アーティファクト
- `UI/Projects/ProjectsListViewController.swift`: 「プロジェクト」一覧 (検索バー, 並び替え: 最近/名前, 「＋ 新規プロジェクト」, カード: 名前/説明/更新日/スター)。空状態。
- `UI/Projects/ProjectDetailViewController.swift`: `init(projectId: String)` — ヘッダ (名前, 説明), 「＋ 新規チャット」(→ `AppRouter.shared.startNewChat(projectId:)`), 「指示」(編集画面), 「ナレッジ」(テキストファイル追加/貼り付けテキスト追加/削除), プロジェクト内チャット一覧 (→ openConversation)。
- `UI/Projects/ProjectEditViewController.swift` (作成/編集: 名前, 説明), `UI/Projects/ProjectInstructionsViewController.swift`
- `UI/Artifacts/ArtifactViewController.swift`: `init(title: String, language: String?, code: String)` — 上部にセグメント「プレビュー / コード」(html/svg/markdown のみプレビュー可; WKWebView でローカル表示, markdown は MarkdownContentView), コードは CodeBlockView 相当で全画面, 右上に共有/コピー。
- `UI/Artifacts/ArtifactsGalleryViewController.swift`: 全会話のアシスタント応答から抽出したコードブロック(アーティファクト候補)一覧 → タップで ArtifactViewController。抽出関数 `static func extractArtifacts(from: [Conversation]) -> [ArtifactItem]` を `UI/Artifacts/ArtifactItem.swift` に (Agent B も使う可能性あり)。
