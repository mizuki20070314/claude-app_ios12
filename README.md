# Claude for iOS 12

iOS 12 (iPod touch 第6世代 / iPad mini 2) 向けの Claude アプリのスキャフォールドです。UIKit のみ、Swift 5、外部依存なし。

## ビルド

GitHub Actions (macos-15 / Xcode 16.4) でビルドします。ローカル (Windows) ではビルドできません。

```bash
# XcodeGen でプロジェクト生成
xcodegen generate
# 実機用 unsigned IPA
xcodebuild -project ClaudeApp.xcodeproj -scheme ClaudeApp -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

## 未署名 IPA のインストール

生成された `ClaudeApp-ios12-unsigned.ipa` は AltStore / Sideloadly / TrollStore 等でサイドロードして利用できます。
