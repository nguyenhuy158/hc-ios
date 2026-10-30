"""Add or remove the E2E simulator key in ~/.ssh/authorized_keys (lines tagged hc-ios-e2e)."""
import os
import sys

TAG = "hc-ios-e2e"
path = os.path.expanduser("~/.ssh/authorized_keys")
lines = open(path).read().splitlines(True) if os.path.exists(path) else []
lines = [line for line in lines if not line.rstrip().endswith(TAG)]

if sys.argv[1] == "add":
    kind, blob = sys.argv[2].split()[:2]
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines.append(f"restrict {kind} {blob} {TAG}\n")

with open(path, "w") as f:
    f.writelines(lines)
os.chmod(path, 0o600)
