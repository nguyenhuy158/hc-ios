import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location("hc_notify", pathlib.Path(__file__).with_name("hc-notify.py"))
hc_notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hc_notify)


def t(address, state, **extra):
    return {"address": address, "status": {"state": state} if state else None, **extra}


def test_changes():
    previous = {"t1": "working", "t2": "blocked", "t3": None}
    current = [t("t1", "blocked"), t("t2", "blocked"), t("t3", "done"), t("t4", "working"), t("t5", "error")]
    got = [(x["address"], s) for x, s in hc_notify.changes(previous, current, {}, 100.0)]
    assert got == [("t1", "blocked"), ("t3", "done"), ("t5", "error")], got

    cooled = [(x["address"], s) for x, s in hc_notify.changes(previous, current, {"t1": 90.0}, 100.0)]
    assert ("t1", "blocked") not in cooled


def test_label():
    assert hc_notify.label({"address": "t1", "name": "api"}) == "api"
    assert hc_notify.label({"address": "t1", "name": None, "title": "", "labels": {"where": "root / 1"}}) == "root / 1"
    assert hc_notify.label({"address": "vps/t1"}) == "vps/t1"


if __name__ == "__main__":
    test_changes()
    test_label()
    print("ok")
