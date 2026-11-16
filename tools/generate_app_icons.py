#!/usr/bin/env python3
"""Regenerate every platform's app icon from the "Echo Rain" source SVGs."""
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent
SRC_DIR = REPO_ROOT / "docs/design/icon/v2/v2-icon-5-opus"

sys.path.insert(0, str(TOOLS_DIR))

from app_icons import android, apple, desktop_web  # noqa: E402  (needs sys.path above; a missing module must fail loudly)


def main() -> None:
    if not SRC_DIR.is_dir():
        raise SystemExit(f"icon source dir missing: {SRC_DIR}")
    for module in (android, apple, desktop_web):
        for path in module.generate(SRC_DIR, REPO_ROOT):
            print(path.relative_to(REPO_ROOT))


if __name__ == "__main__":
    main()
