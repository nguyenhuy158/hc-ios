#!/usr/bin/env python3
"""Install the hc status hook into Claude Code (~/.claude) next to existing hooks."""
import json
import os
import shutil
import sys

HOOKS = [
    ("SessionStart", None, "idle"),
    ("UserPromptSubmit", None, "working"),
    ("PreToolUse", "*", "working"),
    ("PostToolUse", "*", "working"),
    ("PermissionRequest", "*", "blocked"),
    ("Stop", None, "done"),
]

home = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
settings_path = os.path.join(home, "settings.json")
hook_path = os.path.join(home, "hooks", "hc-status.sh")
uninstall = "--uninstall" in sys.argv

settings = json.load(open(settings_path)) if os.path.exists(settings_path) else {}
backup = settings_path + ".bak-hc-status"
if os.path.exists(settings_path) and not os.path.exists(backup):
    shutil.copy(settings_path, backup)
hooks = settings.setdefault("hooks", {})

for event in sorted({event for event, _, _ in HOOKS}):
    entries = [e for e in hooks.get(event, []) if not any("hc-status.sh" in h.get("command", "") for h in e.get("hooks", []))]
    if not uninstall:
        for hook_event, matcher, state in HOOKS:
            if hook_event != event:
                continue
            entry = {"hooks": [{"type": "command", "command": f"$HOME/.claude/hooks/hc-status.sh {state}", "timeout": 3}]}
            if matcher:
                entry["matcher"] = matcher
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
