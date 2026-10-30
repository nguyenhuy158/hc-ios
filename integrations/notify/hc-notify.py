#!/usr/bin/env python3
"""Watch hc and push an ntfy notification when a terminal becomes blocked or done."""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

HC = os.environ.get("HC_BIN", os.path.expanduser("~/.local/bin/herdr-core"))
SERVER = os.environ.get("NTFY_SERVER", "https://ntfy.sh").rstrip("/")
TOPIC_FILE = os.path.expanduser(os.environ.get("HC_NOTIFY_TOPIC_FILE", "~/.config/hc-notify/topic"))
COOLDOWN = int(os.environ.get("HC_NOTIFY_COOLDOWN", "30"))

MESSAGES = {
    "blocked": ("needs you", "warning", "high"),
    "error": ("hit an error", "x", "high"),
    "done": ("is done", "white_check_mark", "default"),
}


def log(text):
    print(time.strftime("%H:%M:%S"), text, flush=True)


def topic():
    with open(TOPIC_FILE) as f:
        return f.read().strip()


def terminals():
    requests = "".join(
        json.dumps({"jsonrpc": "2.0", "id": i, "method": m, "params": {}}) + "\n"
        for i, m in ((1, "hello"), (2, "terminal.list"))
    )
    proc = subprocess.Popen([HC, "connect"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    proc.stdin.write(requests)
    proc.stdin.flush()
    try:
        for line in proc.stdout:
            message = json.loads(line)
            if message.get("id") == 2:
                return message.get("result", {}).get("terminals", [])
    finally:
        proc.kill()
        proc.wait()
    return []


def label(t):
    for value in (t.get("name"), t.get("title"), (t.get("labels") or {}).get("where")):
        if value:
            return value
    return t["address"]


def push(t, state):
    what, tag, priority = MESSAGES[state]
    app = (t.get("status") or {}).get("app") or "agent"
    request = urllib.request.Request(
        f"{SERVER}/{topic()}",
        data=f"{label(t)} {what}".encode(),
        headers={
            "Title": f"{app} - {t['address']}",
            "Tags": tag,
            "Priority": priority,
            "Click": "hcios://terminal/" + urllib.parse.quote(t["address"], safe=""),
        },
        method="POST",
    )
    urllib.request.urlopen(request, timeout=10).read()
    log(f"sent {t['address']} {state}")


def changes(previous, current, last_sent, now):
    for t in current:
        state = (t.get("status") or {}).get("state")
        address = t["address"]
        if state in MESSAGES and previous.get(address) != state and now - last_sent.get(address, 0) >= COOLDOWN:
            yield t, state


def snapshot(items):
    return {t["address"]: (t.get("status") or {}).get("state") for t in items}


def watch():
    proc = subprocess.Popen([HC, "connect"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    for i, method in enumerate(("hello", "events.subscribe"), start=1):
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": i, "method": method, "params": {}}) + "\n")
        proc.stdin.flush()
    previous = snapshot(terminals())
    last_sent = {}
    log(f"watching {len(previous)} terminals")
    for line in proc.stdout:
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if "id" in message:
            continue
        current = terminals()
        now = time.time()
        for t, state in changes(previous, current, last_sent, now):
            try:
                push(t, state)
                last_sent[t["address"]] = now
            except OSError as error:
                log(f"ntfy failed: {error}")
        previous = snapshot(current)
    proc.wait()


def main():
    if "--test" in sys.argv:
        push({"address": "t0", "name": "hc-notify test", "status": {"app": "hc-notify"}}, "done")
        return
    while True:
        try:
            watch()
        except Exception as error:
            log(f"watch ended: {error}")
        time.sleep(5)


if __name__ == "__main__":
    main()
