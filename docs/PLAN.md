# Claude for iOS 12 — 実装計画 / 共通規約

対象端末: iPod touch (第6世代, 4インチ 320x568pt), iPad mini 2 (768x1024pt)。どちらも iOS 12.5.x / arm64 (A8 / A7)。
参考: Android版 Claude アプリ (com.anthropic.claude, xapk)。解析結果は `docs/SPEC.md`。

## 技術方針 (厳守)
- 言語: **Swift 5** (Swift Language Version 5.0), **UIKit のみ**。
- **禁止 (iOS 13+ API)**: SwiftUI, Combine, async/await, `Task`, actor, UIScene/SceneDelegate, SF Symbols (`UIImage(systemName:)`), `UIColor.systemBackground` 等の dynamic system colors, `UICollectionViewCompositionalLayout`, `UICollectionViewDiffableDataSource`, `UIContextMenuInteraction`, `overrideUserInterfaceStyle`, `UIActivityIndicatorView.Style.medium/.large`(→ `.gray`/`.white`/`.whiteLarge` を使う), `UISearchTextField`, `URLSessionWebSocketTask`, `UIFont.monospacedSystemFont`(→ `Menlo`), `NSDiffableDataSourceSnapshot`, `UINavigationBarAppearance`, `@main`(→ `@UIApplicationMain`)。
  - どうしても使う場合は `if #available(iOS 13.0, *)` で囲み、iOS 12 用フォールバックを必ず用意。
- 外部ライブラリ禁止 (依存ゼロ)。
- AppDelegate + `UIWindow` 手動生成。Storyboard は LaunchScreen.storyboard のみ。UI はコードで Auto Layout。
- アイコンはコードで描画 (`UIBezierPath` → `UIImage`) する `Icons.swift` に集約。
- 文字列は `Localizable.strings` (ja / en) を使用。`L("key")` ヘルパー経由。
- ダークモード: iOS 12 にはシステムのダークモードがないため、アプリ内設定 (ライト/ダーク/…) で `Theme` を切り替え、通知 `Theme.didChange` で再描画。

## バックエンド
- 主: **Anthropic Messages API** (`https://api.anthropic.com/v1/messages`) をユーザーの API キーで直接呼ぶ。`stream: true` の SSE を `URLSessionDataDelegate` で逐次パース。
  - ヘッダ: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`。
  - 画像添付: base64 `image` ブロック (JPEG 圧縮, 長辺 1568px 以下)。
  - 拡張思考 (thinking) トグル, モデル選択, システムプロンプト(プロジェクト指示/スタイル)。
- API キーは Keychain に保存。会話・プロジェクトは `Application Support/` の JSON に保存 (ローカル)。
- 会話タイトルは最初の応答後に小さいモデルで自動生成。

## ディレクトリ構成 (XcodeGen: `project.yml`)
```
project.yml
ClaudeApp/
  Info.plist
  Resources/ (LaunchScreen.storyboard, Assets.xcassets(AppIcon), ja.lproj/, en.lproj/)
  App/        AppDelegate.swift, AppRouter.swift, DemoData.swift (スクショ用)
  Theme/      Theme.swift, Icons.swift, Fonts.swift
  Models/     Conversation.swift, Message.swift, Project.swift, ModelOption.swift
  Services/   AnthropicClient.swift, SSEParser.swift, KeychainStore.swift, ConversationStore.swift, SettingsStore.swift
  Markdown/   MarkdownRenderer.swift (NSAttributedString 生成; 見出し/太字/斜体/inline code/コードブロック/リスト/引用/リンク/表の簡易表示)
  UI/
    Common/     (再利用コンポーネント)
    Onboarding/ (ウェルカム, APIキー入力)
    Home/       (新規チャット画面: 挨拶 + 入力欄)
    Chat/       (ChatViewController, MessageCell群, ComposerView)
    Sidebar/    (会話一覧ドロワー, 検索)
    Projects/
    Settings/
```

## スクリーンショット検証モード
- 起動引数 `-screenshot <screen>` で、ネットワークなしでデモデータを読み込み指定画面を表示する。
  - `screen` 例: `onboarding`, `home`, `chat`, `sidebar`, `models`, `settings`, `projects`, `project_detail`, `search`, `artifact`, `dark_chat`
- CI (`.github/workflows/build.yml`): macos-15 / Xcode 16.4 / XcodeGen
  1. 実機用 unsigned IPA (arm64, iOS 12.0 target) をビルドしアーティファクト化
  2. Simulator (iPhone SE 3rd gen, iPad mini) で各画面を起動→ `simctl io screenshot` → アーティファクト化

## コーディング規約
- 1 ファイル 1 主要型。`final class` 優先。
- 強制アンラップ禁止 (IBOutlet なし)。
- 他担当のファイルを編集する必要がある場合は最小限にし、報告すること。
- ローカル(Windows)ではビルドできない。Swift の構文・型を慎重に確認すること。CI で検証する。
