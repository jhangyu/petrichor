#!/usr/bin/env python3
"""Rebuilds the macOS release app.

    python3 tools/build_macos_release.py [--clean]

  --clean  run `flutter clean` and `flutter pub get` first (full rebuild)

Runs from the repo root wherever it is called from. Prints the absolute path
of the built .app as the last stdout line. Exits nonzero with a message on any
failure. stdlib only.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/macos/Build/Products/Release/Petrichor.app"


def run(flutter: str, *args: str) -> None:
    cmd = [flutter, *args]
    rc = subprocess.run(cmd, cwd=ROOT).returncode
    if rc != 0:
        raise RuntimeError(f"`{' '.join(cmd)}` exited {rc}, expected 0")


def main() -> int:
    parser = argparse.ArgumentParser(description="Rebuild the macOS release app.")
    parser.add_argument("--clean", action="store_true", help="flutter clean + pub get first")
    args = parser.parse_args()
    if sys.platform != "darwin":
        print(f"build_macos_release.py: needs macOS, running on {sys.platform}", file=sys.stderr)
        return 1
    flutter = shutil.which("flutter")
    if flutter is None:
        print("build_macos_release.py: `flutter` not found on PATH", file=sys.stderr)
        return 1
    try:
        if args.clean:
            run(flutter, "clean")
            run(flutter, "pub", "get")
        run(flutter, "build", "macos", "--release")
    except RuntimeError as e:
        print(f"build_macos_release.py: {e}", file=sys.stderr)
        return 1
    if not APP.is_dir():
        print(f"build_macos_release.py: build succeeded but {APP} is missing", file=sys.stderr)
        return 1
    print(APP)
    return 0


if __name__ == "__main__":
    sys.exit(main())
