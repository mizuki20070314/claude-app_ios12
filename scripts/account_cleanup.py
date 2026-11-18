#!/usr/bin/env python3
"""account_live テストでアプリが作成した会話を削除する。結果ファイルの内容は個人情報を出さずに要約表示する。"""
import json
import os
import sys
import urllib.error
import urllib.request

UA = "ClaudeIOS12Client-Debug/0.1 (+https://github.com/mizuki20070314/claude-app_ios12)"
session = os.environ.get("CLAUDE_SESSION_KEY", "").strip()
org_hint = os.environ.get("CLAUDE_LAST_ACTIVE_ORG", "").strip()
path = sys.argv[1] if len(sys.argv) > 1 else "account_live_result.json"

for v in (session, org_hint):
    if v:
        print(f"::add-mask::{v}", flush=True)

try:
    result = json.load(open(path, encoding="utf-8"))
except Exception as e:
    print(f"result file not readable: {e}")
    sys.exit(0)

chat = result.get("chat_id") or ""
if chat:
    print(f"::add-mask::{chat}", flush=True)
print(f"app result: ok={result.get('ok')} chat_id_present={bool(chat)} error={str(result.get('error') or '')[:300]!r}")

if not (chat and session and org_hint):
    print("cleanup skipped (missing chat id / secrets)")
    sys.exit(0)

req = urllib.request.Request(
    f"https://claude.ai/api/organizations/{org_hint}/chat_conversations/{chat}",
    method="DELETE",
    headers={"Cookie": f"sessionKey={session}; lastActiveOrg={org_hint}", "User-Agent": UA,
             "Origin": "https://claude.ai", "Referer": "https://claude.ai/"},
)
try:
    status = urllib.request.urlopen(req, timeout=30).status
except urllib.error.HTTPError as e:
    status = e.code
print(f"DELETE test conversation: status={status}")
