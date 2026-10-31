import importlib.util
import json
import os
import pathlib
import tempfile
import urllib.error
import urllib.parse
import urllib.request

spec = importlib.util.spec_from_file_location("hc_pair", pathlib.Path(__file__).with_name("hc-pair.py"))
hc_pair = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hc_pair)

KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJUc6vZbqkq8Yt1n3zL0pQ2wH5eR7uT9sXcA4dF6gBh hc-ios@iphone"


def test_valid_key():
    assert hc_pair.valid_key(KEY)
    assert hc_pair.valid_key(KEY.rsplit(" ", 1)[0])
    assert not hc_pair.valid_key(KEY + "\nssh-rsa AAAA evil")
    assert not hc_pair.valid_key('command="sh" ' + KEY)
    assert not hc_pair.valid_key("ssh-rsa AAAAB3NzaC1yc2E hc")


def test_pair_url():
    url = hc_pair.pair_url("mac.ts.net", "huy", "ssh-ed25519 AAAA+/=", "http://100.1.2.3:5000", "tok")
    parsed = urllib.parse.urlparse(url)
    query = dict(urllib.parse.parse_qsl(parsed.query))
    assert (parsed.scheme, parsed.netloc) == ("hcios", "pair")
    assert query["hostkey"] == "ssh-ed25519 AAAA+/=" and query["url"] == "http://100.1.2.3:5000"
    assert "+" not in parsed.query


def test_add_key():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, ".ssh", "authorized_keys")
        os.makedirs(os.path.dirname(path))
        with open(path, "w") as f:
            f.write("ssh-ed25519 OTHER")
        assert hc_pair.add_key(KEY, path)
        assert not hc_pair.add_key(KEY, path)
        assert open(path).read() == "ssh-ed25519 OTHER\n" + KEY + "\n"
        assert oct(os.stat(path).st_mode & 0o777) == "0o600"


def post(port, body):
    request = urllib.request.Request(f"http://127.0.0.1:{port}/pair", data=json.dumps(body).encode(), method="POST")
    try:
        return urllib.request.urlopen(request, timeout=5).status
    except urllib.error.HTTPError as error:
        return error.code


def test_serve():
    got = []
    server = hc_pair.serve("127.0.0.1", "secret", got.append)
    try:
        port = server.server_port
        assert post(port, {"token": "nope", "key": KEY}) == 403
        assert post(port, {"token": "secret", "key": "ssh-rsa AAAA"}) == 400
        assert got == []
        assert post(port, {"token": "secret", "key": KEY}) == 200
        assert got == [KEY]
    finally:
        server.shutdown()


if __name__ == "__main__":
    test_valid_key()
    test_pair_url()
    test_add_key()
    test_serve()
    print("ok")
