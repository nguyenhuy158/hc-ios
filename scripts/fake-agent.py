"""Fake coding agent for E2E: reports a status with OSC 7501 and echoes every byte it receives."""
import os
import sys
import termios
import tty


def write(text):
    sys.stdout.write(text)
    sys.stdout.flush()


def status(state, kind=""):
    extra = f":kind={kind}" if kind else ""
    write(f"\033]7501;state={state}:app=fake-agent{extra}\033\\")


state = sys.argv[1] if len(sys.argv) > 1 else "working"
fd = sys.stdin.fileno()
saved = termios.tcgetattr(fd)
tty.setraw(fd)
try:
    if state == "blocked":
        status("blocked", "permission")
        write("Bash command\r\n\r\n  echo e2e\r\n\r\nDo you want to proceed?\r\n> 1. Yes\r\n  2. No\r\n")
    else:
        status(state)
        write(f"fake agent ({state})\r\n")
    while True:
        data = os.read(fd, 1024)
        if not data:
            break
        write(f"got: {data.decode(errors='replace')!r}\r\n")
        if data == b"\x03":
            write("interrupted\r\n")
        status("done")
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, saved)
