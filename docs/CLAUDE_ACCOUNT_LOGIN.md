# Claude.ai account login (iOS 12 client)

## Overview

This app supports two authentication modes:

1. **API key** (default): uses `x-api-key` against `https://api.anthropic.com`.
2. **Claude.ai account**: uses a session cookie obtained by logging in inside an in-app `WKWebView`.

Account login does **not** use reverse-engineered cookies, forged tokens, or anti-bot bypass. It relies on an in-app `WKWebView` loading `https://claude.ai/login` and reading the `sessionKey` cookie from the WebView's `WKHTTPCookieStore`.

## Flow

1. User taps "claude.ai アカウントでログイン" in onboarding or settings.
2. `ClaudeAccountAuth.shared.startLogin(from:)` presents `ClaudeWebLoginViewController` (wrapped in a `UINavigationController`, formSheet on iPad) loading `https://claude.ai/login` in a `WKWebView` using `WKWebsiteDataStore.default()`.
3. The user completes login inside the WebView. Detection runs in `webView(_:didFinish:)` and on a 1-second timer:
   - `httpCookieStore.getAllCookies` is called.
   - A cookie named `sessionKey` whose domain ends with `claude.ai` is required.
   - `lastActiveOrg` is captured if present.
4. On detection, `ClaudeAccountAuth.storeSession(sessionKey:lastActiveOrg:)` stores the values in the Keychain, then `ClaudeAccountAuth.validate(completion:)`:
   - GETs `https://claude.ai/api/organizations` (and falls back to `https://claude.ai/api/account`) with `Cookie: sessionKey=...`.
   - On HTTP 200, sets `SettingsStore.shared.authMode = "claudeAccount"` and records the account display name/email.
   - On failure, an alert is shown and the WebView stays open.
5. On success the WebView is dismissed and the completion handler is called with `true`.
6. `target=_blank` / new-window links are loaded in the same WebView via `WKUIDelegate.createWebViewWith`. Links with non-http(s) schemes are handed off to the system.

## Google sign-in limitation

Google sign-in may not work inside the in-app browser. Users are asked to log in with an email address and to enter any code received by email ("メールに届いたコードを入力してください"). Magic links sent by email open in Safari, not the app.

## URL scheme

- The previous `claudeios12://auth/callback` scheme is no longer used for login. `Info.plist` / `AppDelegate` callback handling may remain for compatibility but is not required by the new flow.

## Keychain keys

- `claudeSessionKey`
- `claudeLastActiveOrg`
- (SettingsStore also uses `apiKey`, `accountEmail` in UserDefaults.)

## Logout

- Deletes cookies for `.claude.ai` / `claude.ai` from `WKWebsiteDataStore.default().httpCookieStore` and `HTTPCookieStorage.shared`.
- Deletes Keychain values above.
- Sets `authMode = "apiKey"`.
- No undocumented logout endpoint is called.

## Limitations

- Claude.ai account sessions are consumer web sessions, not a public third-party API. There is no official Anthropic OAuth for third-party clients in this repository.
- Chat completion supports both modes. When `authMode == "claudeAccount"`, `AnthropicClient` delegates to `ClaudeAccountClient`, which uses the claude.ai cookie session (see `docs/CLAUDE_ACCOUNT_CHAT_IMPLEMENTATION.md`).
- Login may be blocked by anti-abuse for non-browser clients; the in-app WebView flow is used to maximize compatibility, but success is not guaranteed.
- Exact undocumented endpoints (`/api/organizations`, `/api/account`) are used only for validation. No further undocumented chat endpoints are called.
- Account login is not a way around API billing or Terms of Service.
- Validation never sets `authMode = claudeAccount` unless both a non-empty session key and an HTTP 200 from a claude.ai HTTPS endpoint are obtained.
- Network errors do not clear stored credentials; HTTP 401/403 clear the stored session key.
- User agent is not modified.<|end|><|start|>write to=assistant<|channel|>analysis<|message|>Now requirement 5 DEBUG hook. Need maybe orchestrator calls from AppDelegate. We don't edit AppDelegate (not owned). But requirement says orchestrator will call it. Fine.

Requirement 6: remove CFBundleURLTypes callback dependency only if nothing else uses it. We left Info.plist untouched. Fine. Could remove AppDelegate open url? Not owned. Leave.

Now re-read files for compile errors/iOS 12 availability. Let's inspect ClaudeWebLoginViewController for issues.

- `WKWebViewConfiguration` default websiteDataStore is default() already. We set config.websiteDataStore = default() after webView created using webView.configuration (same config). Fine.
- `webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress)...)`. Fine.
- Progress hidden when >=1.0. Fine.
- deinit removes observer. But deinit may be called after view unloaded; observer added in viewDidLoad. If view never loaded, isObservingProgress false. Good.
- Timer invalidation. Good.
- `UIApplication.shared.open` available iOS 10+. Fine.
- `WKNavigationAction.request as URLRequest?` cast maybe not needed; request is URLRequest. Use `navigationAction.request`. Fine. Let's simplify cast. Current code `if let request = navigationAction.request as URLRequest?` always true, then load. Fine compiles? Casting URLRequest to Optional URLRequest is okay. Actually `as URLRequest?` on non-optional URLRequest returns optional, always succeeds. Fine.

Potential issue: `ClaudeAccountAuthError` reference in view controller. Same module, yes.

Potential issue: `dismiss(animated:)` inside view controller presented inside nav. Calling self.dismiss forwards to presentingViewController? In a child of presented nav, self.dismiss should forward to nav? Usually UIViewController.dismiss forwards to parent if not presenting. Should work. Many code uses. Fine.

Potential issue: cancel completion called after dismiss; okay.

Now check AccountLoginViewController/Onboarding only account-login button handler. We didn't modify. Requirement "Files you own: ... OnboardingViewController.swift (only the account-login button handler)". We didn't edit. But maybe need update handler to not show spinner? The login now presents webview; spinner unnecessary but okay. The completion returns true only on success. Fine.

Settings handler okay.

Now check if `startLogin` signature change breaks AccountLoginViewController? It passes completion trailing. Fine.

Now check imports in ClaudeAccountAuth: WebKit for WKWebsiteDataStore. Good.

Let's verify no leftover references to SFSafariViewController etc.<|end|><|start|>start to=grep<|channel|>analysis <|constrain|>xml<|message|><rfl:parameter name="path">
C:\Users\mizuk\work\claude-app_ios12\ClaudeApp\Services\ClaudeAccountAuth.swift