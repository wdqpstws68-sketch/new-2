#!/usr/bin/env python3
"""Update Info.plist with AdMob recommended SKAdNetwork IDs.

Reference: https://developers.google.com/admob/ios/quick-start (2025-2026 list)
Run any time AdMob publishes new IDs.
"""
import plistlib
from pathlib import Path

PLIST_PATH = Path(__file__).resolve().parents[1] / "PixelColoringGame" / "Info.plist"

# Canonical AdMob + mediation partners SKAdNetwork IDs (mid-2026 list).
# Source: Google AdMob iOS quick-start docs and partner network mediation pages.
SKADNETWORK_IDS = [
    "cstr6suwn9.skadnetwork",  # Google
    "4fzdc2evr5.skadnetwork",
    "2fnua5tdw4.skadnetwork",
    "ydx93a7ass.skadnetwork",
    "5a6flpkh64.skadnetwork",
    "p78axxw29g.skadnetwork",
    "v72qych5uu.skadnetwork",
    "ludvb6z3bs.skadnetwork",
    "cp8zw746q7.skadnetwork",
    "3sh42y64q3.skadnetwork",
    "c6k4g5qg8m.skadnetwork",
    "s39g8k73mm.skadnetwork",
    "3qy4746246.skadnetwork",
    "f38h382jlk.skadnetwork",
    "hs6bdukanm.skadnetwork",
    "mlmmfzh3r3.skadnetwork",
    "v4nxqhlyqp.skadnetwork",
    "wzmmz9fp6w.skadnetwork",
    "yclnxrl5pm.skadnetwork",
    "t38b2kh725.skadnetwork",
    "7ug5zh24hu.skadnetwork",
    "gta9lk7p23.skadnetwork",
    "vutu7akeur.skadnetwork",
    "y5ghdn5j9k.skadnetwork",
    "v9wttpbfk9.skadnetwork",
    "n38lu8286q.skadnetwork",
    "47vhws6wlr.skadnetwork",
    "kbd757ywx3.skadnetwork",
    "9t245vhmpl.skadnetwork",
    "a2p9lx4jpn.skadnetwork",
    "22mmun2rn5.skadnetwork",
    "4468km3ulz.skadnetwork",
    "2u9pt9hc89.skadnetwork",
    "8s468mfl3y.skadnetwork",
    "klf5c3l5u5.skadnetwork",
    "ppxm28t8ap.skadnetwork",
    "ecpz2srf59.skadnetwork",
    "uw77j35x4d.skadnetwork",
    "pwa73g5rt2.skadnetwork",
    "mtkv5xtk9e.skadnetwork",
    "578prtvx9j.skadnetwork",
    "4dzt52r2t5.skadnetwork",
    "e5fvkxwrpn.skadnetwork",
    "8c4e2ghe7u.skadnetwork",
    "zq492l623r.skadnetwork",
    "3rd42ekr43.skadnetwork",
    "3qcr597p9d.skadnetwork",
]


def main() -> None:
    with PLIST_PATH.open("rb") as f:
        data = plistlib.load(f)

    sk_items = [{"SKAdNetworkIdentifier": id_} for id_ in SKADNETWORK_IDS]
    data["SKAdNetworkItems"] = sk_items

    with PLIST_PATH.open("wb") as f:
        plistlib.dump(data, f)

    print(f"Updated {PLIST_PATH} with {len(SKADNETWORK_IDS)} SKAdNetwork IDs.")


if __name__ == "__main__":
    main()
