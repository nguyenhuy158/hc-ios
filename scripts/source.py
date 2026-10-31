#!/usr/bin/env python3
"""Write the SideStore/AltStore source JSON that points at the latest hc IPA."""
import json
import os
import sys
from datetime import datetime, timezone

REPO = "https://github.com/nguyenhuy158/hc-ios"
RELEASE = f"{REPO}/releases/download/latest"


def source(version, build, size, date):
    """Return the source document for one hc build."""
    return {
        "name": "hc",
        "identifier": "dev.nguyenhuy158.hcios.source",
        "sourceURL": f"{RELEASE}/source.json",
        "website": REPO,
        "apps": [{
            "name": "hc",
            "bundleIdentifier": "dev.nguyenhuy158.hcios",
            "developerName": "nguyenhuy158",
            "subtitle": "Watch and answer your hc terminals",
            "localizedDescription": "iOS client for herdr-core (hc) over SSH: see which agents are working, blocked or done, read their screens and answer prompts.",
            "iconURL": "https://raw.githubusercontent.com/nguyenhuy158/hc-ios/main/docs/icon/b1.png",
            "tintColor": "#5B8DEF",
            "versions": [{
                "version": version,
                "buildVersion": str(build),
                "date": date,
                "size": size,
                "downloadURL": f"{RELEASE}/HcIOS.ipa",
                "minOSVersion": "17.0",
            }],
            "appPermissions": {"entitlements": [], "privacy": {"NSFaceIDUsageDescription": "Unlock hc to see your terminals."}},
        }],
        "news": [],
    }


def main():
    ipa, out, version, build = sys.argv[1:5]
    date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(out, "w") as f:
        json.dump(source(version, build, os.path.getsize(ipa), date), f, indent=2)


if __name__ == "__main__":
    main()
