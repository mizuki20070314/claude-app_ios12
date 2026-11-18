#!/usr/bin/env python3
"""claude.ai アカウントセッションの疎通確認 (手動実行のデバッグ用)。

公開リポジトリの Actions ログに出るため、個人情報 (メール・氏名・組織ID・会話本文) は出力しない。
出力するのは HTTP ステータス、JSON のキー名、SSE イベント種別、テスト応答の短いテキストのみ。
ブラウザの偽装や bot 対策の回避は行わない。拒否された場合はそのまま報告して終了する。
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = "https://claude.ai/api"
UA = "ClaudeIOS12Client-Debug/0.1 (+https://github.com/mizuki20070314/claude-app_ios12)"
SESSION = os.environ.get("CLAUDE_SESSION_KEY", "").strip()
ORG_HINT = os.environ.get("CLAUDE_LAST_ACTIVE_ORG", "").strip()
MODEL_OVERRIDE = os.environ.get("PROBE_MODEL", "").strip()
DO_COMPLETION = os.environ.get("PROBE_COMPLETION", "1") == "1"


def mask(value):
    if value:
        print(f"::add-mask::{value}", flush=True)


def log(msg):
    print(msg, flush=True)


def headers(org=None, accept="application/json"):
    cookie = f"sessionKey={SESSION}"
    if org:
        cookie += f"; lastActiveOrg={org}"
    return {
        "Cookie": cookie,
        "Accept": accept,
        "Content-Type": "application/json",
        "User-Agent": UA,
        "Origin": "https://claude.ai",
        "Referer": "https://claude.ai/",
    }


def describe_error_body(raw, ctype):
    """エラー本文から個人情報を含まない部分だけ取り出す。"""
    if "json" in (ctype or ""):
        try:
            j = json.loads(raw)
            err = j.get("error") if isinstance(j, dict) else None
            if isinstance(err, dict):
                return f"error.type={err.get('type')} error.message={str(err.get('message'))[:200]}"
            if isinstance(j, dict):
                return f"json keys={sorted(j.keys())[:20]}"
        except Exception:
            pass
    text = raw[:4000].decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)[:4000]
    if "cf-" in text.lower() or "challenge" in text.lower() or "just a moment" in text.lower():
        return "HTML (Cloudflare のチャレンジ/ブロックページと思われる)"
    return f"non-JSON body ({len(raw)} bytes, starts with {text[:40]!r})"


def request(method, path, org=None, body=None, accept="application/json", timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=headers(org, accept))
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status, resp.headers, resp
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e


def show_headers(h):
    keys = ["content-type", "cf-mitigated", "server", "cf-ray"]
    parts = []
    for k in keys:
        v = h.get(k) if h else None
        if v:
            parts.append(f"{k}={'(present)' if k == 'cf-ray' else v}")
    return " ".join(parts)


def find_org_uuids(obj, out):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ("uuid", "organization_uuid") and isinstance(v, str) and len(v) == 36:
                out.append(v)
            else:
                find_org_uuids(v, out)
    elif isinstance(obj, list):
        for x in obj:
            find_org_uuids(x, out)


def collect_model_ids(obj, out):
    if isinstance(obj, dict):
        mid = obj.get("model") or obj.get("id")
        if isinstance(mid, str) and mid.startswith("claude"):
            out.append(mid)
        for v in obj.values():
            collect_model_ids(v, out)
    elif isinstance(obj, list):
        for x in obj:
            collect_model_ids(x, out)


def main():
    if not SESSION:
        log("❌ CLAUDE_SESSION_KEY が空です (Secret 未設定、またはフォーク/権限の問題)")
        return 1
    mask(SESSION)
    mask(ORG_HINT)
    log(f"session key length={len(SESSION)} prefix_ok={SESSION.startswith('sk-ant-')}")
    log(f"lastActiveOrg provided={bool(ORG_HINT)}")

    # 1. organizations
    log("\n== 1. GET /api/organizations ==")
    st, h, r = request("GET", "/organizations")
    raw = r.read()
    log(f"status={st} {show_headers(h)}")
    org = None
    if st == 200:
        try:
            j = json.loads(raw)
        except Exception:
            log("  JSON ではない応答: " + describe_error_body(raw, h.get("content-type")))
            return 2
        orgs = j if isinstance(j, list) else [j]
        log(f"  organizations count={len(orgs)}")
        uuids = []
        for o in orgs:
            if isinstance(o, dict) and isinstance(o.get("uuid"), str):
                uuids.append(o["uuid"])
                caps = o.get("capabilities")
                log(f"  org: keys={len(o)} capabilities={caps if isinstance(caps, list) else '?'}")
        for u in uuids:
            mask(u)
        if ORG_HINT and ORG_HINT in uuids:
            org = ORG_HINT
            log("  lastActiveOrg は一覧に含まれる → これを使用")
        elif uuids:
            org = uuids[0]
            log("  lastActiveOrg が一覧に無い/未設定 → 先頭の組織を使用")
    else:
        log("  " + describe_error_body(raw, h.get("content-type")))
        if st in (401, 403):
            log("  → セッション無効、または Cloudflare 等で拒否。ここで終了 (回避はしない)")
        return 2
    if not org:
        log("❌ 組織 UUID を特定できませんでした")
        return 2

    # 2. bootstrap
    log("\n== 2. GET /api/bootstrap/{org}/app_start ==")
    st, h, r = request("GET", f"/bootstrap/{org}/app_start?growthbook_format=sdk&include_system_prompts=false")
    raw = r.read()
    log(f"status={st} {show_headers(h)} bytes={len(raw)}")
    model_ids = []
    if st == 200:
        try:
            j = json.loads(raw)
            log(f"  top-level keys={sorted(j.keys()) if isinstance(j, dict) else type(j).__name__}")
            for key in ("model_selector_state", "model_selector_config"):
                if isinstance(j, dict) and key in j:
                    collect_model_ids(j[key], model_ids)
            seen = []
            for m in model_ids:
                if m not in seen:
                    seen.append(m)
            model_ids = seen
            log(f"  model ids (from model_selector_*)={model_ids[:20]}")
        except Exception as e:
            log(f"  parse error: {e}")
    else:
        log("  " + describe_error_body(raw, h.get("content-type")))

    if not DO_COMPLETION:
        log("\nPROBE_COMPLETION=0 のため送信テストは省略")
        return 0

    # 3. completion のバリエーション (テスト会話を作成し、最後に必ず削除する)
    model = MODEL_OVERRIDE or (model_ids[0] if model_ids else None)
    chat = str(uuid.uuid4())
    created = False
    results = {}
    try:
        # 3a. アプリと同じ body (新規会話)
        body = app_body("Reply with exactly: OK", chat, model, new=True, parent=None, thinking=None)
        res = run_completion("3a. app body / new chat", org, chat, body)
        results["3a"] = res
        created = res["status"] == 200
        if not created:
            body = app_body("Reply with exactly: OK", chat, model, new=True, parent=None, thinking=None, minimal=True)
            res = run_completion("3a'. minimal body / new chat", org, chat, body)
            results["3a'"] = res
            created = res["status"] == 200
        if created:
            first_assistant = res["assistant_uuid"]
            # 3b. 続き: parent_message_uuid = null
            body = app_body("Reply with exactly: TWO", chat, model, new=False, parent=None, thinking=None)
            results["3b"] = run_completion("3b. follow-up, parent=null", org, chat, body)
            # 3c. 続き: parent = 直前のアシスタントメッセージ UUID
            parent = results["3b"]["assistant_uuid"] or first_assistant
            body = app_body("Reply with exactly: THREE", chat, model, new=False, parent=parent, thinking=None)
            results["3c"] = run_completion(f"3c. follow-up, parent=assistant uuid (present={bool(parent)})", org, chat, body)
            # 3d. 拡張思考
            parent = results["3c"]["assistant_uuid"] or parent
            body = app_body("What is 17*23? Answer with just the number.", chat, model, new=False, parent=parent, thinking="extended")
            results["3d"] = run_completion("3d. thinking_mode=extended", org, chat, body)
            # 3g. effort の許容値確認 (不正値を送ると 400 で許容値が返る)
            for eff in os.environ.get("PROBE_EFFORTS", "__invalid__").split(","):
                eff = eff.strip()
                if not eff:
                    continue
                body = app_body("Reply with exactly: E", chat, model, new=False, parent=parent, thinking=None)
                body["effort"] = eff
                key = "3g:" + eff
                results[key] = run_completion("3g. effort=" + eff, org, chat, body)
                if results[key]["assistant_uuid"]:
                    parent = results[key]["assistant_uuid"]
            # 3e. 会話ツリーの確認 (メッセージ数・送信者の並び)
            log("\n== 3e. GET chat_conversations/{chat}?tree=True&rendering_mode=messages ==")
            st, h, r = request("GET", f"/organizations/{org}/chat_conversations/{chat}?tree=True&rendering_mode=messages&render_all_tools=true", org=org)
            raw = r.read()
            log(f"status={st}")
            if st == 200:
                try:
                    j = json.loads(raw)
                    msgs = j.get("chat_messages") or []
                    log(f"  keys={sorted(j.keys())}")
                    log(f"  chat_messages={len(msgs)} senders={[m.get('sender') for m in msgs]}")
                    log(f"  current_leaf present={bool(j.get('current_leaf_message_uuid'))}")
                    if msgs:
                        log(f"  message keys={sorted(msgs[0].keys())}")
                except Exception as e:
                    log(f"  parse error {e}")
            # 3f. タイトル生成
            log("\n== 3f. POST title ==")
            st, h, r = request("POST", f"/organizations/{org}/chat_conversations/{chat}/title", org=org,
                               body={"message_content": "Reply with exactly: OK", "recent_titles": []})
            raw = r.read()
            log(f"status={st}")
            if st == 200:
                try:
                    j = json.loads(raw)
                    log(f"  keys={sorted(j.keys())} title={str(j.get('title'))[:40]!r}")
                except Exception:
                    log("  non-JSON")
            else:
                log("  " + describe_error_body(raw, h.get("content-type")))
    finally:
        if created:
            log("\n== 4. DELETE test conversation ==")
            st, h, r = request("DELETE", f"/organizations/{org}/chat_conversations/{chat}", org=org)
            r.read()
            log(f"status={st}")
    log("\n== summary ==")
    for k, v in results.items():
        log(f"  {k}: status={v['status']} reply={v['text'][:30]!r} thinking_chars={v['thinking_chars']} "
            f"assistant_uuid={'yes' if v['assistant_uuid'] else 'no'} error={v['error']}")
    return 0 if created else 3


def app_body(prompt, chat, model, new, parent, thinking, minimal=False):
    """ClaudeAccountClient.swift と同じ形の body を作る。"""
    body = {
        "prompt": prompt,
        "timezone": "Asia/Tokyo",
        "attachments": [],
        "files": [],
        "rendering_mode": "messages",
        "input_mode": "text",
        "completion_request_id": str(uuid.uuid4()),
    }
    if model:
        body["model"] = model
    if new:
        body["create_conversation_params"] = {"uuid": chat, "name": "", **({"model": model} if model else {})}
    if parent:
        body["parent_message_uuid"] = parent
    if thinking:
        body["thinking_mode"] = thinking
    if not minimal:
        body.setdefault("parent_message_uuid", None)
        body.setdefault("create_conversation_params", None)
        body["tools"] = []
        body["effort"] = None
        body.setdefault("thinking_mode", None)
        body["turn_message_uuids"] = None
        body["tool_allowlist"] = []
        body["skip_completion_notification"] = False
    return body


def run_completion(label, org, chat, body):
    log(f"\n== {label} ==")
    log(f"  body keys={sorted(body.keys())}")
    st, h, r = request("POST", f"/organizations/{org}/chat_conversations/{chat}/completion", org=org,
                       body=body, accept="text/event-stream", timeout=120)
    log(f"  status={st} {show_headers(h)}")
    res = {"status": st, "text": "", "thinking_chars": 0, "assistant_uuid": None, "error": None}
    if st != 200:
        res["error"] = describe_error_body(r.read(), h.get("content-type"))
        log("  " + res["error"])
        return res
    events, buf, started = [], b"", time.time()
    block_types = []
    while True:
        chunk = r.read(1024)
        if not chunk:
            break
        buf += chunk
        while b"\n\n" in buf:
            block, buf = buf.split(b"\n\n", 1)
            ev, data = None, []
            for line in block.decode("utf-8", "replace").splitlines():
                if line.startswith("event:"):
                    ev = line[6:].strip()
                elif line.startswith("data:"):
                    data.append(line[5:].lstrip())
            payload = "\n".join(data)
            try:
                j = json.loads(payload) if payload else None
            except Exception:
                j = None
            etype = ev or (j.get("type") if isinstance(j, dict) else None) or "?"
            events.append(etype)
            if not isinstance(j, dict):
                continue
            if etype == "message_start":
                m = j.get("message") or {}
                if isinstance(m, dict):
                    log(f"  message_start.message keys={sorted(m.keys())}")
                    res["assistant_uuid"] = m.get("uuid") or m.get("id")
                    mask(res["assistant_uuid"])
            if etype == "content_block_start":
                cb = j.get("content_block") or {}
                block_types.append(cb.get("type") if isinstance(cb, dict) else "?")
            d = j.get("delta") if isinstance(j.get("delta"), dict) else {}
            if isinstance(d.get("text"), str):
                res["text"] += d["text"]
            if isinstance(d.get("thinking"), str):
                res["thinking_chars"] += len(d["thinking"])
            if etype == "error":
                err = j.get("error", {})
                res["error"] = f"SSE {err.get('type')}: {str(err.get('message'))[:200]}"
                log("  " + res["error"])
        if time.time() - started > 110:
            log("  (タイムアウトで打ち切り)")
            break
    compact = []
    for e in events:
        if compact and compact[-1][0] == e:
            compact[-1][1] += 1
        else:
            compact.append([e, 1])
    log("  events=" + " -> ".join(f"{e}x{n}" if n > 1 else e for e, n in compact))
    log(f"  content blocks={block_types} reply={res['text'][:80]!r} thinking_chars={res['thinking_chars']}")
    return res


if __name__ == "__main__":
    sys.exit(main())
