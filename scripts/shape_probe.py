#!/usr/bin/env python3
"""任意の claude.ai API エンドポイントの「応答の構造」だけを表示する (内容は表示しない)。

公開リポジトリの Actions ログに出るため、文字列値は原則伏せる。表示するのは
キー名・型・配列長・列挙値らしき短い値 (kind/type/status 等の許可リストのキーのみ)。

PROBE_PATHS: 改行区切り。例 "GET /organizations/{org}/recents?section=chats"
  プレースホルダ: {org} = チャット組織, {chat} / {session} = 直前の応答から拾った最初の ID
  (CAPTURE_CHAT_KEY / CAPTURE_SESSION_KEY で拾うキー名を指定、既定 uuid / id)
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

BASE = "https://claude.ai/api"
UA = "ClaudeIOS12Client-Debug/0.1 (+https://github.com/mizuki20070314/claude-app_ios12)"
SESSION = os.environ.get("CLAUDE_SESSION_KEY", "").strip()
ORG_HINT = os.environ.get("CLAUDE_LAST_ACTIVE_ORG", "").strip()
PATHS = [p.strip() for p in re.split(r"[\n|]", os.environ.get("PROBE_PATHS", "")) if p.strip()]
ENUM_KEYS = {"kind", "type", "sender", "role", "status", "worker_status", "section", "surface", "stop_reason",
             "rendering_mode", "input_mode", "source", "state", "event", "subtype", "mode", "environment_kind",
             "session_status", "connection_status", "platform", "object", "has_more", "is_live", "needs_input",
             "unread", "is_starred", "is_temporary", "truncated", "name_kind", "category"}
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
captured = {}


def mask(v):
    if v:
        print(f"::add-mask::{v}", flush=True)


def shape(obj, key=None, depth=0, max_depth=6):
    pad = "  " * depth
    if depth > max_depth:
        return f"{pad}…"
    if isinstance(obj, dict):
        lines = []
        dynamic = [k for k in obj.keys() if re.search(r"[0-9a-f]{8}-[0-9a-f]{4}", k) or len(k) > 48]
        if dynamic:
            lines.append(f"{pad}<{len(dynamic)} dynamic keys (ID を含むため非表示)>")
        for k in sorted(k for k in obj.keys() if k not in dynamic):
            v = obj[k]
            if isinstance(v, (dict, list)):
                lines.append(f"{pad}{k}: {type(v).__name__}" + (f"[{len(v)}]" if isinstance(v, list) else ""))
                lines.append(shape(v, k, depth + 1, max_depth))
            else:
                lines.append(f"{pad}{k}: {scalar(k, v)}")
        return "\n".join(l for l in lines if l)
    if isinstance(obj, list):
        if not obj:
            return ""
        out = [f"{pad}[0]:", shape(obj[0], key, depth + 1, max_depth)]
        kinds = sorted({str(x.get(k2)) for x in obj if isinstance(x, dict) for k2 in ("kind", "type") if k2 in x})
        if kinds:
            out.append(f"{pad}(kinds/types in list: {kinds[:15]})")
        return "\n".join(l for l in out if l)
    return f"{pad}{scalar(key, obj)}"


def scalar(k, v):
    if v is None or isinstance(v, bool):
        return repr(v)
    if isinstance(v, (int, float)):
        return f"{type(v).__name__}"
    if isinstance(v, str):
        if UUID_RE.match(v):
            mask(v)
            return "uuid"
        if k in ENUM_KEYS and len(v) <= 40 and re.match(r"^[A-Za-z0-9_.\-:]*$", v):
            return repr(v)
        return f"str(len={len(v)})"
    return type(v).__name__


def find_first(obj, keys):
    if isinstance(obj, dict):
        for k in keys:
            v = obj.get(k)
            if isinstance(v, str) and v:
                return v
        for v in obj.values():
            r = find_first(v, keys)
            if r:
                return r
    elif isinstance(obj, list):
        for x in obj:
            r = find_first(x, keys)
            if r:
                return r
    return None


def request(method, path, org):
    hdr = {"Cookie": f"sessionKey={SESSION}" + (f"; lastActiveOrg={org}" if org else ""),
           "Accept": "application/json", "Content-Type": "application/json", "User-Agent": UA,
           "Origin": "https://claude.ai", "Referer": "https://claude.ai/"}
    # PROBE_HEADERS: "Name: value;;Name2: value2" ({org} 置換可)
    for item in os.environ.get("PROBE_HEADERS", "").split(";;"):
        if ":" in item:
            name, value = item.split(":", 1)
            hdr[name.strip()] = value.strip().replace("{org}", org or "")
    url = path if path.startswith("http") else BASE + path
    req = urllib.request.Request(url, method=method, headers=hdr)
    try:
        r = urllib.request.urlopen(req, timeout=60)
        return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()


def resolve_org():
    st, h, raw = request("GET", "/organizations", None)
    if st != 200:
        print(f"organizations status={st}")
        return None
    orgs = json.loads(raw)
    for o in orgs:
        mask(o.get("uuid"))
    if ORG_HINT and any(o.get("uuid") == ORG_HINT for o in orgs):
        return ORG_HINT
    for o in orgs:
        if "chat" in (o.get("capabilities") or []):
            return o["uuid"]
    return orgs[0]["uuid"] if orgs else None


def main():
    if not SESSION:
        print("no session secret")
        return 1
    mask(SESSION)
    mask(ORG_HINT)
    org = resolve_org()
    if not org:
        return 2
    chat_keys = os.environ.get("CAPTURE_CHAT_KEY", "uuid").split(",")
    sess_keys = os.environ.get("CAPTURE_SESSION_KEY", "id").split(",")
    for line in PATHS:
        method, path = (line.split(" ", 1) + [""])[:2] if " " in line else ("GET", line)
        if "{chat}" in path and "chat" not in captured or "{session}" in path and "session" not in captured:
            print(f"\n== {method} {path} ==\n  skipped (placeholder not captured)")
            continue
        real = path.replace("{org}", org).replace("{chat}", captured.get("chat", "")).replace("{session}", captured.get("session", ""))
        st, h, raw = request(method, real, org)
        ctype = h.get("content-type", "") if h else ""
        print(f"\n== {method} {path} ==\n  status={st} content-type={ctype} bytes={len(raw)}", flush=True)
        if "json" in ctype:
            try:
                j = json.loads(raw)
            except Exception as e:
                print(f"  json error {e}")
                continue
            if st >= 400:
                err = j.get("error") if isinstance(j, dict) else None
                if isinstance(err, dict):
                    print(f"  error.type={err.get('type')} message={str(err.get('message'))[:200]}")
                    continue
            print(shape(j, depth=1))
            if "chat" not in captured:
                c = find_first(j, chat_keys)
                if c and UUID_RE.match(c):
                    captured["chat"] = c
                    mask(c)
                    print("  (captured {chat})")
            if "session" not in captured:
                s = find_first(j, sess_keys)
                if s:
                    captured["session"] = s
                    mask(s)
                    print("  (captured {session})")
        else:
            text = raw[:300].decode("utf-8", "replace")
            print(f"  non-JSON (starts with {text[:60]!r})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
