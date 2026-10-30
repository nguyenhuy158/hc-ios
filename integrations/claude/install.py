#!/usr/bin/env python3
"""Install the hc status hook into Claude Code (~/.claude) next to existing hooks."""
import json
import os
import shutil
import sys

STATES = {
    "UserPromptSubmit": "working",
    "PreToolUse": "working",
    "PermissionRequest": "blocked",
    "Stop": "done",
    "SessionStart": "idle",
}

home = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
settings_path = os.path.join(home, "settings.json")
hook_path = os.path.join(home, "hooks", "hc-status.sh")
uninstall = "--uninstall" in sys.argv

settings = json.load(open(settings_path)) if os.path.exists(settings_path) else {}
backup = settings_path + ".bak-hc-status"
if os.path.exists(settings_path) and not os.path.exists(backup):
    shutil.copy(settings_path, backup)
hooks = settings.setdefault("hooks", {})

for event, state in STATES.items():
    command = f"$HOME/.claude/hooks/hc-status.sh {state}"
    entries = [e for e in hooks.get(event, []) if not any(h.get("command") == command for h in e.get("hooks", []))]
    if not uninstall:
        entry = {"hooks": [{"type": "command", "command": command, "timeout": 3}]}
        if event in ("PreToolUse", "PermissionRequest"):
            entry["matcher"] = "*"
        entries.append(entry)
    if entries:
        hooks[event] = entries
    else:
        hooks.pop(event, None)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

if uninstall:
    if os.path.exists(hook_path):
        os.remove(hook_path)
    print("hc status hook removed")
else:
    os.makedirs(os.path.dirname(hook_path), exist_ok=True)
    shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "hc-status.sh"), hook_path)
    os.chmod(hook_path, 0o755)
    print(f"hc status hook installed; backup at {backup}")
