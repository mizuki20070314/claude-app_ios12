# Claude.ai account login (iOS 12 client)

## Overview

This app supports two authentication modes:

1. **API key** (default): uses `x-api-key` against `https://api.anthropic.com`.
2. **Claude.ai account**: uses a session cookie obtained through Apple's official web authentication API.

Account login does **not** use reverse-engineered cookies, forged tokens, or anti-bot bypass. It relies on `ASWebAuthenticationSession` (iOS 12+) and the system browser cookie store.

## Flow

1. User taps "claude.ai アカウントでログイン" in onboarding or settings.
2. `ClaudeAccountAuth.shared.startLogin(from:)` opens `https://claude.ai/login` in an `ASWebAuthenticationSession` with callback scheme `claudeios12://auth/callback`.
3. After the user completes login in the system browser, the session returns (or the user closes it).
4. `ClaudeAccountAuth.validate(completion:)`:
   - Reads `sessionKey*` and `lastActiveOrg` cookies from `HTTPCookieStorage.shared` only for `claude.ai` HTTPS domains.
   - `sessionKey` may be HttpOnly. `ASWebAuthenticationSession` does not expose cookies to the app on iOS 12; if no cookie is obtainable, validation fails and `authMode` is never set to `claudeAccount`.
   - Stores `claudeSessionKey` and `claudeLastActiveOrg` in the Keychain only when a non-empty session key exists.
   - GETs `https://claude.ai/api/organizations` (and falls back to `https://claude.ai/api/account`) with `Cookie: sessionKey=...`.
   - On HTTP 200, sets `SettingsStore.shared.authMode = "claudeAccount"` and records the account display name/email.
5. If `ASWebAuthenticationSession` is unavailable or cannot start, a `SFSafariViewController` fallback is presented. The user completes login and taps "ログイン完了", which runs the same validation.

## URL scheme

- Callback scheme: `claudeios12`
- Callback URL: `claudeios12://auth/callback`
- Registered in `Info.plist` under `CFBundleURLTypes`.
- `AppDelegate.application(_:open:options:)` accepts the scheme.

## Keychain keys

- `claudeSessionKey`
- `claudeLastActiveOrg`
- (SettingsStore also uses `apiKey`, `accountEmail` in UserDefaults.)

## Logout

- Deletes cookies for `.claude.ai` / `claude.ai` from `HTTPCookieStorage.shared`.
- Deletes Keychain values above.
- Sets `authMode = "apiKey"`.
- No undocumented logout endpoint is called.

## Limitations

- Claude.ai account sessions are consumer web sessions, not a public third-party API. There is no official Anthropic OAuth for third-party clients in this repository.
- Chat completion in this app uses the Anthropic Messages API (`/v1/messages`) with an API key. When `authMode == "claudeAccount"`, `AnthropicClient` refuses to send and surfaces `AnthropicError.accountChatUnsupported`. To chat, use an API key.
- Login may be blocked by anti-abuse (Cloudflare/Play Integrity equivalents) for non-browser clients; the system browser flow is used to maximize compatibility, but success is not guaranteed.
- Exact undocumented endpoints (`/api/organizations`, `/api/account`) are used only for validation as evidenced by docs/SPEC.md and Android. No further undocumented chat endpoints are called.
- Account login is not a way around API billing or Terms of Service.
- Validation never sets `authMode = claudeAccount` unless both a non-empty session key and an HTTP 200 from a claude.ai HTTPS endpoint are obtained.
- Network errors do not clear stored credentials; HTTP 401/403 clear the stored session key.
