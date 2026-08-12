#!/usr/bin/env python3
"""Resolve Xcode build-setting placeholders for the swiftc bundle build."""

import json
import plistlib
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
SPEC_PATH = PROJECT_DIR / "project.yml"


def main() -> None:
    requested_version = sys.argv[1] if len(sys.argv) > 1 else ""
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else PROJECT_DIR / "build" / "GeneratedPlists"
    output_dir.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["xcodegen", "dump", "--type", "json", "--spec", str(SPEC_PATH)],
        check=True,
        capture_output=True,
        text=True,
    )
    spec = json.loads(result.stdout)
    global_settings = spec.get("settings", {}).get("base", {})
    version = requested_version or str(global_settings.get("MARKETING_VERSION", "1.0.0"))
    build_number = str(global_settings.get("CURRENT_PROJECT_VERSION", "1"))

    for target_name, target in spec["targets"].items():
        info = target.get("info")
        if not info:
            continue

        settings = target.get("settings", {}).get("base", {})
        product_name = str(settings.get("PRODUCT_NAME", target_name))
        bundle_identifier = str(settings.get("PRODUCT_BUNDLE_IDENTIFIER", ""))
        plist_path = PROJECT_DIR / info["path"]

        with plist_path.open("rb") as file:
            plist = plistlib.load(file)

        plist["CFBundleExecutable"] = product_name
        plist["CFBundleIdentifier"] = bundle_identifier
        plist["CFBundleName"] = product_name
        plist["CFBundleShortVersionString"] = version
        plist["CFBundleVersion"] = build_number
        plist["CFBundleDevelopmentRegion"] = "en"

        output_path = output_dir / f"{target_name}.Info.plist"
        with output_path.open("wb") as file:
            plistlib.dump(plist, file, sort_keys=False)

        print(f"Prepared {output_path.relative_to(PROJECT_DIR)}")


if __name__ == "__main__":
    main()
