# PIN / Effort API（Android Claude アプリ decompiled）

## 1. Pin / Unpin

- UI 文字列: `0x7f140202` "Pin", `0x7f140728` "Unpin", `0x7f140565` "Pinned (%1$d)", `0x7f14016c` "Pinned"。
- アクション種別: `defpackage/icu.java` — `PIN("pin")`, `UNPIN("unpin")`。
- ネットワーク: `defpackage/w38.java` `j()` → `PUT organizations/{organization}/chat_conversations/{chat}`（rf1 method 3 = PUT）。ボディは `UpdateChatRequest`（`defpackage/qwf0.java` / `defpackage/rwf0.java`）で、ピン時は `{"is_starred": true/false}`（`name`/`settings` は null のため省略）。根拠: `defpackage/z3a.java` case 1 で `new rwf0((String) null, Boolean.valueOf(z), (tvf0) null, 5)`。
- 最大ピン数: 未確認（クライアント側の上限は見当たらず、サーバ側制限の可能性）。

## 2. チャット一覧の順序

- recents 応答はセクション配列（`defpackage/az10.java` / `defpackage/bz10.java`）。先頭セクション id `"pinned"`（行は `is_starred=true`）、続いて通常 recents セクション（ライブ API で確認済み）。
- クライアント側ソートは見当たらず（`defpackage/cx60.java` に Comparator なし）、サーバ返却順をそのまま使用。ピン内もサーバ返却順。未確認: `updated_at` 等による二次ソートの有無。

## 3. Effort

- completion ボディ: `defpackage/p58.java` `ChatCompletionRequest` に `effort` フィールド（serializer `uid0` = `ThinkingEffort` 文字列）。値は `'low','medium','high','xhigh','max'` を受容。
- チャット設定: `ChatConversationSettings`（`defpackage/i68.java`）と `UpdatableChatConversationSettings`（`defpackage/svf0.java`）に `effort_level`（`ThinkingEffort` 文字列）。更新は同じ `PUT organizations/{organization}/chat_conversations/{chat}` の `settings`（`rwf0`/`tvf0`）経由。effort 変更のたびに必ず PUT されるかは未確認（per-turn の completion `effort` 送信は確認済み）。
- モデル別: `ModelSelectorEntry`（`defpackage/o3u.java`）の `thinking` = `ThinkingOptions`（`defpackage/hjd0.java`）で、`effort_options`（`ThinkingOption`: `id`, `name`, `description`, `recommended`, `badge`）と `mode_options` を持つ。`ThinkingState`（`defpackage/akd0.java` / `defpackage/rjd0.java`）の種別は `effort`（tjd0）/ `effort_and_mode`（vjd0）/ `mode`（xjd0）/ `none`（yjd0）/ `unknown`（zjd0）。許容 effort レベルは `effort_options[].id`、デフォルトは `recommended: true` の候補と推定（未確認）。
- JSON 形（モデル選択状態/設定）:
```json
{
  "thinking": {
    "effort_options": [
      {"id": "high", "name": "...", "description": "...", "recommended": true, "badge": "..."}
    ],
    "mode_options": [...],
    "description": "..."
  }
}
```