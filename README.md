# Claude for iOS 12

iOS 12 (iPod touch 第6世代 / iPad mini 2 など) 向けの **非公式** Claude クライアントです。Android 版 Claude アプリ (`com.anthropic.claude`) の UI / 機能を参考に、Swift 5 + UIKit のみ (外部依存なし) で実装しています。

> **注意**: 本アプリは Anthropic とは無関係の非公式クライアントです。Anthropic の商標・サービスとは関係ありません。

## 概要

- 参考: Android 版 Claude アプリ (`com.anthropic.claude`)
- 対象: iOS 12.0 以上 / arm64 (A7/A8 世代以降)
- 実装: Swift 5, UIKit のみ, 依存ゼロ, AppDelegate + `UIWindow` 手動生成

## 機能一覧 (実装済み)

- ストリーミングチャット (SSE)
- Markdown / コードブロック表示とコピー
- 拡張思考 (thinking) 表示
- モデル選択
- 画像 / テキストファイル添付
- 会話のスター / 名前変更 / 削除 / 検索
- プロジェクト (指示・ナレッジ)
- アーティファクト表示 (HTML / SVG / Markdown プレビュー)
- ライト / ダークテーマ
- iPad の常時表示サイドバー
- 日本語 / 英語

## Android 版との違い

- claude.ai アカウントではなく **Anthropic API キー** (`console.anthropic.com`) を使用。API 料金が発生します。
- 会話は端末内 (Application Support の JSON) に保存されます。
- 音声モード / Web 検索 / Claude Code 連携などは未対応です。

## 動作要件

- iOS 12.0 以上
- arm64

## インストール

1. GitHub Actions の Artifacts から `ClaudeApp-ios12-unsigned` (未署名 IPA) をダウンロード。
2. AltStore / Sideloadly / Xcode などで自分の Apple ID で署名してインストール。
   - iOS 12 では TrollStore は使用できません。
   - 無料 Apple ID の場合、7 日ごとに再署名が必要です。

## ビルド方法

macOS + Xcode 16.x (iOS 12 をターゲットにできる最後の系統) が必要です。

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ClaudeApp.xcodeproj -scheme ClaudeApp \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

生成された `.app` を `Payload/` に置いて zip すれば IPA になります (CI と同じ手順)。

## CI

- push ごとに `macos-15` / Xcode 16.4 でビルドします。
- iOS 18 シミュレータ (iPhone SE 第3世代, iPad mini) で `-screenshot <screen>` 起動引数を使いスクリーンショットを撮影します。
- 画面一覧: `onboarding`, `home`, `chat`, `sidebar`, `models`, `settings`, `projects`, `project_detail`, `search`, `artifact`, `dark_chat`, `dark_home`
- 注意: GitHub Actions には iOS 12 シミュレータがないため、iOS 12 実機での動作確認は別途必要です。

## ディレクトリ構成

```
project.yml
ClaudeApp/
  Info.plist
  Resources/   # LaunchScreen.storyboard, Assets.xcassets, ja.lproj/, en.lproj/
  App/         # AppDelegate, AppRouter, DemoData, Localization
  Theme/       # Theme, Icons, Fonts
  Models/      # Conversation, Message, Project, ModelOption
  Services/    # AnthropicClient, SSEParser, KeychainStore, ConversationStore, SettingsStore, ImageUtil
  Markdown/    # MarkdownRenderer など
  UI/
    Common/    # BottomSheetController, IconButton, ThemedNavigationController など
    Onboarding/
    Home/
    Chat/      # ChatViewController, ComposerView, MessageCells など
    Sidebar/   # ドロワー, 検索, 会話一覧
    Projects/
    Settings/
    Artifacts/
    Root/      # RootViewController
docs/          # PLAN.md, UI_CONTRACT.md, SERVICES.md など
scripts/       # screenshots.sh
.github/workflows/build.yml
```