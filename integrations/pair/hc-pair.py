#!/usr/bin/env python3
"""Show a QR code that pairs the hc iPhone app with this Mac over Tailscale."""
import getpass
import hmac
import json
import os
import re
import secrets
import shutil
import socketserver
import subprocess
import sys
import threading
import urllib.parse

AUTHORIZED = os.path.expanduser("~/.ssh/authorized_keys")
HOST_KEY = "/etc/ssh/ssh_host_ed25519_key.pub"
HC = os.environ.get("HC_PATH", "~/.local/bin/herdr-core")
TIMEOUT = 300
KEY_RE = re.compile(r"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5[A-Za-z0-9+/]{43,48}={0,2}( [A-Za-z0-9@._-]{1,64})?")


def tailscale_self():
    """Return this machine's Tailscale DNS name and IPv4 address."""
    out = subprocess.run(["tailscale", "status", "--self", "--json"], capture_output=True, text=True, check=True).stdout
    me = json.loads(out)["Self"]
    return me["DNSName"].rstrip("."), next(ip for ip in me["TailscaleIPs"] if "." in ip)


def host_key(path=HOST_KEY):
    """Return the Mac's ed25519 host key as 'type base64'."""
    with open(path) as f:
        return " ".join(f.read().split()[:2])


def pair_url(host, user, hostkey, endpoint, token):
    """Build the hcios://pair link that goes into the QR code."""
    query = {"host": host, "port": "22", "user": user, "hc": HC, "hostkey": hostkey, "url": endpoint, "token": token}
    return "hcios://pair?" + urllib.parse.urlencode(query, quote_via=urllib.parse.quote)


def valid_key(line):
    """Return True when line is a single ed25519 public key line."""
    return bool(KEY_RE.fullmatch(line))


def add_key(line, path=AUTHORIZED):
    """Append the key to authorized_keys unless it is already there."""
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    existing = open(path).read() if os.path.exists(path) else ""
    if line in existing.splitlines():
        return False
    with open(path, "a") as f:
        if existing and not existing.endswith("\n"):
            f.write("\n")
        f.write(line + "\n")
    os.chmod(path, 0o600)
    return True


def answer(line, token, on_key):
    """Check one pairing request line and return the reply object."""
    try:
        body = json.loads(line)
    except ValueError:
        body = None
    if not isinstance(body, dict) or not hmac.compare_digest(str(body.get("token", "")), token):
        return {"ok": False, "message": "bad token"}
    key = str(body.get("key", "")).strip()
    if not valid_key(key):
        return {"ok": False, "message": "bad key"}
    on_key(key)
    return {"ok": True, "message": "paired"}


def serve(bind, token, on_key):
    """Start the one-shot pairing TCP server (one JSON line in, one out) and return it."""
    class Handler(socketserver.StreamRequestHandler):
        timeout = 10

        def handle(self):
            try:
                line = self.rfile.readline(4096)
            except OSError:
                return
            self.wfile.write((json.dumps(answer(line, token, on_key)) + "\n").encode())

    server = socketserver.ThreadingTCPServer((bind, 0), Handler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    _, ip = tailscale_self()
    token = secrets.token_urlsafe(24)
    done = threading.Event()
    paired = []

    def on_key(key):
        paired.append(key)
        add_key(key)
        done.set()

    server = serve(ip, token, on_key)
    url = pair_url(ip, getpass.getuser(), host_key(), f"tcp://{ip}:{server.server_address[1]}", token)
    if shutil.which("qrencode"):
        subprocess.run(["qrencode", "-t", "ansiutf8", url], check=True)
    else:
        print("Install qrencode (brew install qrencode) to show a QR code. Link:\n" + url)
    print(f"Scan with the iPhone Camera and open in hc. Waiting up to {TIMEOUT // 60} minutes…")
    ok = done.wait(TIMEOUT)
    server.shutdown()
    if not ok:
        sys.exit("Timed out. Run hc-pair again.")
    print("Paired:", paired[0].split()[-1])


if __name__ == "__main__":
    main()
