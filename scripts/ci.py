#!/usr/bin/env python3
"""Builds Petrichor release apps and publishes them to a GitHub release.

    python3 scripts/ci.py                                      # local pre-check: macos + android on this Mac
    python3 scripts/ci.py --platform <target> [--tag vX.Y.Z]   # build one target on its own host
    python3 scripts/ci.py --publish --tag vX.Y.Z               # publish every target's asset

  --platform  macos | linux-x64 | linux-arm64 | windows-x64 | windows-arm64 | android
  --tag       release tag; must equal v<pubspec.yaml version name> (default: pubspec version)
  --dist      asset directory (default build/ci-dist)

Release assets come only from .github/workflows/release.yml: pushing tag vX.Y.Z
runs `--platform` on one GitHub-hosted runner per target, then `--publish` on
the downloaded assets. Run locally, this script only pre-checks that flow.
Each target builds on its own host OS (android on macOS or Linux); the target's
Flutter output is deleted before the build, so a wrong-arch build fails loudly.

This script builds only: the guard below refuses any test command (exit 3).

Exit codes: 0 ok, 1 command/output/publish failure, 2 usage or version gate,
3 test guard. stdlib only; Python >= 3.9.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path
from typing import NoReturn

if sys.version_info < (3, 9):
    sys.exit(f"ci.py: expected Python >= 3.9, got {sys.version_info[0]}.{sys.version_info[1]}")

# ---- Test guard: CI builds only, no test may run from this script. ----
TEST_GUARD_EXIT = 3
TEST_PATHS = re.compile(r"run_tests\.py|pytest|unittest|integration_test|_test\.dart|(^|[\s/\\])test[/\\]")
TEST_RUNNERS = {"flutter", "dart", "xcodebuild"}  # refused when `test`/`drive` follows, flags or not
TEST_VERBS = {"test", "drive"}


def is_test_command(line: str) -> bool:
    """Checks every shell segment, so commands nested in shell strings count too."""
    if TEST_PATHS.search(line):
        return True
    for segment in re.split(r"[;&|\n]", line):
        words = [re.sub(r"\.(bat|exe)$", "", re.split(r"[/\\]", w)[-1].lower())
                 for w in re.findall(r"[^\s'\"]+", segment)]
        for i, word in enumerate(words):
            if word == "ctest" or (word in TEST_RUNNERS and TEST_VERBS & set(words[i + 1:])):
                return True
    return False


def _self_scan() -> None:
    """The process call in run() must stay the only process entry: the module
    name may appear only in its import and that call (no alias, no second call)."""
    src = Path(__file__).read_text(encoding="utf-8")
    calls = src.count("sub" + "process") - 1
    banned = [t for t in ("os." + "system", "os." + "popen",
                          "os." + "exec", "os." + "spawn", "posix" + "_spawn", "pty" + ".")
              if t in src]
    if calls != 1 or banned:
        print(f"test guard: expected exactly 1 process call site and no other process API, "
              f"got {calls} call sites and {banned} in {__file__}", file=sys.stderr)
        sys.exit(TEST_GUARD_EXIT)
    if "FLUTTER_TEST" in os.environ:
        print("test guard: expected FLUTTER_TEST unset, got it set", file=sys.stderr)
        sys.exit(TEST_GUARD_EXIT)


def run(argv: list[str], *, capture: bool = False, check: bool = True,
        env: dict[str, str] | None = None):
    """The only process launcher. Rejects test commands, fails loudly on non-zero."""
    line = " ".join(argv)
    if is_test_command(line):
        print(f"test guard: refused `{line}` (CI script builds only, no tests)", file=sys.stderr)
        sys.exit(TEST_GUARD_EXIT)
    exe = shutil.which(argv[0])
    if exe is None:
        die(f"expected `{argv[0]}` on PATH, not found (needed for `{line}`)")
    print(f"+ {line}", flush=True)
    with open(os.devnull, "rb") as fin:
        res = subprocess.run([exe, *argv[1:]], cwd=REPO_ROOT, stdin=fin, text=True,
                             capture_output=capture,
                             env=None if env is None else {**os.environ, **env})
    if check and res.returncode != 0:
        detail = f"\n{res.stdout}{res.stderr}" if capture else ""
        die(f"`{line}` exited {res.returncode}, expected 0{detail}")
    return res


# ---- Everything below goes through run(). ----
REPO_ROOT = Path(__file__).resolve().parent.parent
DIST = REPO_ROOT / "build" / "ci-dist"
SECRET_NAMES = {"token.txt", ".env"}
# target -> (host sys.platform values, flutter build subcommand, Flutter output, asset suffix)
TARGETS = {
    "macos": (("darwin",), "macos", "build/macos/Build/Products/Release/Petrichor.app", "macos-universal.zip"),
    "linux-x64": (("linux",), "linux", "build/linux/x64/release/bundle", "linux-x64.tar.gz"),
    "linux-arm64": (("linux",), "linux", "build/linux/arm64/release/bundle", "linux-arm64.tar.gz"),
    "windows-x64": (("win32",), "windows", "build/windows/x64/runner/Release", "windows-x64.zip"),
    "windows-arm64": (("win32",), "windows", "build/windows/arm64/runner/Release", "windows-arm64.zip"),
    "android": (("darwin", "linux"), "apk", "build/app/outputs/flutter-apk/app-release.apk", "android.apk"),
}
# Flutter forwards FLUTTER_XCODE_* env vars to xcodebuild as build settings: ad-hoc sign, no team/keychain.
AD_HOC_SIGNING_ENV = {
    "FLUTTER_XCODE_CODE_SIGN_IDENTITY": "-",
    "FLUTTER_XCODE_CODE_SIGN_STYLE": "Manual",
    "FLUTTER_XCODE_DEVELOPMENT_TEAM": "",
}
PRECHECK_TARGETS = ("macos", "android")


def die(msg: str, code: int = 1) -> NoReturn:
    print(f"ci.py: {msg}", file=sys.stderr)
    sys.exit(code)


def pubspec_version() -> str:
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$",
                  (REPO_ROOT / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    if not m:
        die("version gate: expected `version: X.Y.Z+N` in pubspec.yaml, found none", 2)
    return m.group(1)


def asset_name(version: str, target: str) -> str:
    return f"petrichor-{version}-{TARGETS[target][3]}"


def check_secrets(asset: Path, names: list[str]) -> None:
    bad = [n for n in names if Path(n).name in SECRET_NAMES or n.endswith(".local")]
    if bad:
        asset.unlink()
        die(f"secret check: expected no {sorted(SECRET_NAMES)} or *.local in {asset.name}, got {bad}")


def check_universal(app: Path) -> None:
    binary = app / "Contents/MacOS/Petrichor"
    archs = set(run(["lipo", "-archs", str(binary)], capture=True).stdout.split())
    if archs != {"arm64", "x86_64"}:
        die(f"expected a universal macOS binary (arm64 + x86_64), got {sorted(archs)}")


def build(version: str, target: str, dist: Path) -> Path:
    """Build one target on its own host and package it into dist/."""
    hosts, subcommand, output, _ = TARGETS[target]
    if sys.platform not in hosts:
        die(f"--platform {target}: expected host {'/'.join(hosts)}, got {sys.platform}", 2)
    product = REPO_ROOT / output
    if product.is_dir():
        shutil.rmtree(product)
    elif product.exists():
        product.unlink()
    run(["flutter", "build", subcommand, "--release"],
        env=AD_HOC_SIGNING_ENV if target == "macos" else None)
    if not product.exists():
        die(f"expected {output} after `flutter build {subcommand}`, missing (wrong host arch?)")
    dist.mkdir(parents=True, exist_ok=True)
    asset = dist / asset_name(version, target)
    if asset.exists():
        asset.unlink()
    top = asset.name.removesuffix(".zip").removesuffix(".tar.gz")
    if target == "macos":
        check_universal(product)
        # ditto keeps the framework symlinks that zipfile would flatten.
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(product), str(asset)])
    elif target == "android":
        shutil.copyfile(product, asset)
    elif subcommand == "linux":
        with tarfile.open(asset, "w:gz") as t:
            t.add(product, arcname=top)
    else:
        with zipfile.ZipFile(asset, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(product.rglob("*")):
                if f.is_file():
                    z.write(f, f"{top}/{f.relative_to(product).as_posix()}")
    if asset.name.endswith(".tar.gz"):
        with tarfile.open(asset) as t:
            check_secrets(asset, t.getnames())
    else:
        with zipfile.ZipFile(asset) as z:
            check_secrets(asset, z.namelist())
    print(f"asset: {asset.name} ({asset.stat().st_size} bytes)")
    return asset


def publish(tag: str, version: str, dist: Path) -> None:
    """Create or update release <tag> (not draft) with one asset per target."""
    assets = [dist / asset_name(version, t) for t in TARGETS]
    missing = [a.name for a in assets if not a.is_file()]
    if missing:
        die(f"publish: expected all {len(assets)} assets in {dist.name}/, missing {missing}")
    files = [str(a) for a in assets]
    view = run(["gh", "release", "view", tag], capture=True, check=False)
    if view.returncode == 0:
        run(["gh", "release", "upload", tag, *files, "--clobber"])
    elif "release not found" in view.stderr:
        run(["gh", "release", "create", tag, *files, "--verify-tag",
             "--title", f"Petrichor {version}", "--notes", f"Petrichor {version}"])
    else:
        die(f"publish: `gh release view {tag}` exited {view.returncode}, expected 0 or `release not found`:\n{view.stderr}")
    info = json.loads(run(["gh", "release", "view", tag, "--json", "isDraft,tagName,assets"], capture=True).stdout)
    missing = sorted({a.name for a in assets} - {a["name"] for a in info["assets"]})
    if info["isDraft"] or info["tagName"] != tag or missing:
        die(f"publish: expected release {tag} published (not draft) with all assets, got "
            f"isDraft={info['isDraft']} tagName={info['tagName']} missing={missing}")
    print(f"published {tag}: {sorted(a.name for a in assets)}")


def main() -> int:
    _self_scan()
    p = argparse.ArgumentParser(description="Build Petrichor release apps and publish them to GitHub.")
    p.add_argument("--platform", choices=TARGETS, help="build this one target on its own host")
    p.add_argument("--publish", action="store_true", help="publish every target's asset from --dist to release --tag")
    p.add_argument("--tag", help="vX.Y.Z, must equal v<pubspec.yaml version name>")
    p.add_argument("--dist", type=Path, default=DIST, help="asset directory (default build/ci-dist)")
    args = p.parse_args()

    version = pubspec_version()
    if args.tag is not None and args.tag != f"v{version}":
        die(f"version gate: expected --tag v{version} (pubspec.yaml), got {args.tag!r}", 2)
    dist = args.dist.resolve()

    if args.publish:
        if args.tag is None or args.platform is not None:
            die(f"--publish: expected --tag and no --platform, got tag={args.tag} platform={args.platform}", 2)
        publish(args.tag, version, dist)
        return 0
    targets = (args.platform,) if args.platform else PRECHECK_TARGETS
    assets = [build(version, t, dist) for t in targets]
    print("ASSETS:")
    print("\n".join(a.name for a in assets))
    return 0


if __name__ == "__main__":
    sys.exit(main())
