#!/usr/bin/env python3
"""Builds Petrichor release apps and publishes them to a GitHub release.

    python3 scripts/ci.py --version X.Y.Z --platform <p> [--publish]

  --platform  macos | linux-arm64 | linux-x64 | windows | all
  --publish   upload the built assets to GitHub release vX.Y.Z (Mac only)

Driven from the Mac: macOS builds natively, Linux in OrbStack docker
(image petrichor-linux-build:<arm64|x64>), Windows on the ssh box. Linux and
Windows build a `git archive HEAD` snapshot, so the tracked tree must be clean.
Assets land in build/ci-dist/. `--local --out DIR` is the host-local mode the
container and the Windows box run; it builds only the host's own platform.

--version must equal the pubspec.yaml version name. This script builds only:
the guard below refuses any test command (exit 3).

Exit codes: 0 ok, 1 command/output/publish failure, 2 usage or version gate,
3 test guard. stdlib only; Python >= 3.9.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
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
    """Checks every shell segment, so commands nested in ssh/docker strings count too."""
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


def run(argv: list[str], *, capture: bool = False, stdin: Path | None = None, check: bool = True):
    """The only process launcher. Rejects test commands, fails loudly on non-zero."""
    line = " ".join(argv)
    if is_test_command(line):
        print(f"test guard: refused `{line}` (CI script builds only, no tests)", file=sys.stderr)
        sys.exit(TEST_GUARD_EXIT)
    exe = shutil.which(argv[0])
    if exe is None:
        die(f"expected `{argv[0]}` on PATH, not found (needed for `{line}`)")
    print(f"+ {line}", flush=True)
    with open(stdin, "rb") if stdin else open(os.devnull, "rb") as fin:
        res = subprocess.run([exe, *argv[1:]], cwd=REPO_ROOT, stdin=fin, text=True,
                             capture_output=capture)
    if check and res.returncode != 0:
        detail = f"\n{res.stdout}{res.stderr}" if capture else ""
        die(f"`{line}` exited {res.returncode}, expected 0{detail}")
    return res


# ---- Everything below goes through run(). ----
REPO_ROOT = Path(__file__).resolve().parent.parent
DIST = REPO_ROOT / "build" / "ci-dist"
PLATFORMS = ("macos", "linux-arm64", "linux-x64", "windows")
SECRET_NAMES = {"token.txt", ".env"}
DOCKER_ARCH = {"linux-arm64": "arm64", "linux-x64": "amd64"}
LINUX_ARCH = {"aarch64": "arm64", "arm64": "arm64", "x86_64": "x64", "amd64": "x64"}
WIN_HOST = "User@<windows-host>"
WIN_KEY = str(Path.home() / ".ssh" / "id_ed25519")
WIN_DIR = r"C:\Users\User\petrichor-ci"
WIN_SCP_DIR = "C:/Users/User/petrichor-ci"


def die(msg: str, code: int = 1) -> NoReturn:
    print(f"ci.py: {msg}", file=sys.stderr)
    sys.exit(code)


def pubspec_version() -> str:
    path = REPO_ROOT / "pubspec.yaml"
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$", path.read_text(encoding="utf-8"), re.M)
    if not m:
        die(f"version gate: expected `version: X.Y.Z+N` in {path}, found none", 2)
    return m.group(1)


def host_platform() -> str:
    if sys.platform == "darwin":
        return "macos"
    if sys.platform == "win32":
        return "windows"
    if sys.platform.startswith("linux"):
        arch = LINUX_ARCH.get(platform.machine().lower())
        if arch is None:
            die(f"expected Linux machine in {sorted(LINUX_ARCH)}, got {platform.machine()}")
        return f"linux-{arch}"
    die(f"expected host darwin/win32/linux, got {sys.platform}")


def asset_name(version: str, plat: str) -> str:
    if plat == "macos":
        return f"petrichor-{version}-macos-{macos_arch()}.zip"
    if plat == "windows":
        return f"petrichor-{version}-windows-x64.zip"
    return f"petrichor-{version}-{plat}.tar.gz"


def macos_arch() -> str:
    binary = REPO_ROOT / "build/macos/Build/Products/Release/Petrichor.app/Contents/MacOS/Petrichor"
    archs = set(run(["lipo", "-archs", str(binary)], capture=True).stdout.split())
    labels = {"arm64": "arm64", "x86_64": "x64"}
    if archs == set(labels):
        return "universal"
    if len(archs) == 1 and archs <= set(labels):
        return labels[archs.pop()]
    die(f"expected {binary} archs within {sorted(labels)}, got {sorted(archs)}")


def check_secrets(asset: Path, names: list[str]) -> None:
    bad = [n for n in names if Path(n).name in SECRET_NAMES or n.endswith(".local")]
    if bad:
        asset.unlink()
        die(f"secret check: expected no {sorted(SECRET_NAMES)} or *.local in {asset}, got {bad}")


def build_local(version: str, plat: str, out: Path) -> Path:
    """Build and package the host's own platform into out/."""
    if plat != host_platform():
        die(f"--local: expected --platform {host_platform()} on this host, got {plat}", 2)
    os_name = plat.split("-")[0]
    run(["flutter", "build", os_name, "--release"])
    out.mkdir(parents=True, exist_ok=True)
    asset = out / asset_name(version, plat)
    if asset.exists():
        asset.unlink()
    if os_name == "macos":
        app = REPO_ROOT / "build/macos/Build/Products/Release/Petrichor.app"
        if not app.is_dir():
            die(f"expected {app} after flutter build, missing")
        # ditto keeps the framework symlinks that zipfile would flatten.
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(asset)])
        with zipfile.ZipFile(asset) as z:
            check_secrets(asset, z.namelist())
    elif os_name == "linux":
        bundle = REPO_ROOT / "build/linux" / plat.split("-")[1] / "release/bundle"
        if not bundle.is_dir():
            die(f"expected {bundle} after flutter build, missing")
        with tarfile.open(asset, "w:gz") as t:
            t.add(bundle, arcname=asset.name[: -len(".tar.gz")])
        with tarfile.open(asset) as t:
            check_secrets(asset, t.getnames())
    else:
        if platform.machine().upper() != "AMD64":
            die(f"expected Windows machine AMD64, got {platform.machine()}")
        release = REPO_ROOT / "build/windows/x64/runner/Release"
        if not release.is_dir():
            die(f"expected {release} after flutter build, missing")
        top = asset.name[: -len(".zip")]
        with zipfile.ZipFile(asset, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(release.rglob("*")):
                if f.is_file():
                    z.write(f, f"{top}/{f.relative_to(release).as_posix()}")
        with zipfile.ZipFile(asset) as z:
            check_secrets(asset, z.namelist())
    print(f"asset: {asset} ({asset.stat().st_size} bytes)")
    return asset


def snapshot(sha: str, plat: str) -> Path:
    """Per-platform tar of the pinned commit, so concurrent invocations do not collide."""
    tar = DIST / f"src-{plat}.tar"
    run(["git", "archive", "--format=tar", "-o", str(tar), sha])
    return tar


def build_linux(version: str, plat: str, sha: str) -> Path:
    tag = plat.split("-")[1]
    tar = snapshot(sha, plat)
    try:
        run(["docker", "run", "--rm", "-i", "--platform", f"linux/{DOCKER_ARCH[plat]}",
             "-v", f"{DIST}:/out", "-v", f"petrichor-pub-cache-{tag}:/root/.pub-cache",
             f"petrichor-linux-build:{tag}", "sh", "-ec",
             "mkdir /src; tar -x -C /src; cd /src; python3 scripts/ci.py "
             f"--version {version} --platform {plat} --local --out /out"],
            stdin=tar)
    finally:
        tar.unlink()
    return DIST / asset_name(version, plat)


def build_windows(version: str, sha: str) -> Path:
    ssh = ["ssh", "-i", WIN_KEY, "-o", "BatchMode=yes", WIN_HOST]
    scp = ["scp", "-i", WIN_KEY, "-o", "BatchMode=yes"]
    name = asset_name(version, "windows")

    def ps(script: str) -> None:
        # Remote shell is cmd.exe; powershell takes the ;-separated script.
        run([*ssh, f"powershell -Command \"{script}\""])

    ps(f"$ErrorActionPreference='Stop'; foreach ($d in '{WIN_DIR}\\src','{WIN_DIR}\\out') {{ if (Test-Path $d) "
       f"{{ Remove-Item -Recurse -Force $d }} }}; $null = New-Item -ItemType Directory -Force {WIN_DIR}\\src")
    tar = snapshot(sha, "windows")
    try:
        run([*scp, str(tar), f"{WIN_HOST}:{WIN_SCP_DIR}/src.tar"])
    finally:
        tar.unlink()
    # No 'Stop' here: PowerShell 5.1 can turn native stderr (flutter progress) into a
    # terminating error, so native failures propagate through $LASTEXITCODE instead.
    ps(f"tar -xf {WIN_DIR}\\src.tar -C {WIN_DIR}\\src; if ($LASTEXITCODE) {{ exit $LASTEXITCODE }}; "
       f"Set-Location -ErrorAction Stop {WIN_DIR}\\src; py -3 scripts\\ci.py --version {version} "
       f"--platform windows --local --out {WIN_DIR}\\out; exit $LASTEXITCODE")
    run([*scp, f"{WIN_HOST}:{WIN_SCP_DIR}/out/{name}", str(DIST / name)])
    return DIST / name


def git_out(*args: str) -> str:
    return run(["git", *args], capture=True).stdout.strip()


def require_clean_tree() -> None:
    # Untracked files count (the macOS build uses the working tree); gitignored ones do not.
    dirty = git_out("status", "--porcelain")
    if dirty:
        die(f"expected a clean tree (assets must match HEAD), got changes:\n{dirty}")


def remote_tag_sha(tag: str) -> str | None:
    lines = git_out("ls-remote", "--tags", "origin", f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}").splitlines()
    refs = {ref: sha for sha, ref in (line.split("\t") for line in lines)}
    return refs.get(f"refs/tags/{tag}^{{}}") or refs.get(f"refs/tags/{tag}")


def publish(version: str, assets: list[Path], sha: str) -> None:
    tag = f"v{version}"
    head = git_out("rev-parse", "HEAD")
    if head != sha:
        die(f"publish: expected HEAD at the built commit {sha}, got {head} (HEAD moved during the build)")
    require_clean_tree()
    run(["git", "fetch", "origin"])
    if run(["git", "merge-base", "--is-ancestor", sha, "origin/main"], check=False).returncode != 0:
        die(f"publish: expected {sha} on origin/main, it is not (push first)")
    tagged = remote_tag_sha(tag)
    if tagged and tagged != sha:
        die(f"publish: expected tag {tag} at {sha}, got {tagged} (bump pubspec version)")
    view = run(["gh", "release", "view", tag], capture=True, check=False)
    files = [str(a) for a in assets]
    if view.returncode == 0:
        if tagged is None:
            die(f"publish: release {tag} exists but tag {tag} is missing on origin, expected it at {sha} "
                "(likely a draft left by a failed create; delete it and rerun)")
        run(["gh", "release", "upload", tag, *files, "--clobber"])
    elif "release not found" in view.stderr:
        run(["gh", "release", "create", tag, *files, "--target", sha,
             "--title", f"Petrichor {version}", "--notes", f"Petrichor {version}"])
    else:
        die(f"publish: `gh release view {tag}` exited {view.returncode}, expected 0 or `release not found`:\n{view.stderr}")
    info = json.loads(run(["gh", "release", "view", tag, "--json", "isDraft,tagName,assets"], capture=True).stdout)
    missing = sorted({a.name for a in assets} - {a["name"] for a in info["assets"]})
    if info["isDraft"] or info["tagName"] != tag or missing:
        die(f"publish: expected release {tag} published (not draft) with all assets, got "
            f"isDraft={info['isDraft']} tagName={info['tagName']} missing={missing}")
    if remote_tag_sha(tag) != sha:
        die(f"publish: expected tag {tag} on origin at {sha}, got {remote_tag_sha(tag)}")
    print(f"published {tag} at {sha}: {sorted(a.name for a in assets)}")


def main() -> int:
    _self_scan()
    p = argparse.ArgumentParser(description="Build Petrichor release apps and publish them to GitHub.")
    p.add_argument("--version", required=True, help="X.Y.Z, must equal the pubspec.yaml version name")
    p.add_argument("--platform", required=True, choices=(*PLATFORMS, "all"))
    p.add_argument("--publish", action="store_true", help="upload assets to GitHub release vX.Y.Z (Mac only)")
    p.add_argument("--local", action="store_true", help="build this host's platform only (container / Windows box)")
    p.add_argument("--out", type=Path, default=DIST, help="asset directory for --local (default build/ci-dist)")
    args = p.parse_args()

    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        die(f"version gate: expected --version X.Y.Z, got {args.version!r}", 2)
    if args.version != pubspec_version():
        die(f"version gate: expected --version {pubspec_version()} (pubspec.yaml), got {args.version}", 2)

    if args.local:
        if args.publish or args.platform == "all":
            die("--local: expected one platform and no --publish", 2)
        build_local(args.version, args.platform, args.out.resolve())
        return 0

    if host_platform() != "macos":
        die(f"expected the dispatcher to run on macos, got {host_platform()} (use --local)", 2)
    require_clean_tree()
    sha = git_out("rev-parse", "HEAD")  # every platform and the release use this one commit
    DIST.mkdir(parents=True, exist_ok=True)
    assets = []
    for plat in PLATFORMS if args.platform == "all" else (args.platform,):
        # One run per platform at a time: the macOS tree, the Windows work dir and the
        # per-arch docker volume are single-owner. Left behind only if the process is killed.
        lock = DIST / f"{plat}.lock"
        try:
            lock.open("x").close()
        except FileExistsError:
            die(f"expected no other run building {plat}, found {lock} (delete it if no run is active)")
        try:
            if plat == "macos":
                assets.append(build_local(args.version, plat, DIST))
            elif plat == "windows":
                assets.append(build_windows(args.version, sha))
            else:
                assets.append(build_linux(args.version, plat, sha))
        finally:
            lock.unlink()
        if not assets[-1].is_file():
            die(f"expected asset {assets[-1]} after the {plat} build, missing")
    if args.publish:
        publish(args.version, assets, sha)
    print("ASSETS:")
    print("\n".join(str(a) for a in assets))
    return 0


if __name__ == "__main__":
    sys.exit(main())
