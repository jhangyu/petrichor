#!/usr/bin/env python3
"""Builds libwebp 1.6.0 plus the radar shim into ONE shared library.

    python3 tools/build_libwebp.py --os <os> --arch <arch> --out-dir <dir>
        [--cache-dir <dir>] [--cc <compiler>] [--vcvars <script>]
        [--ios-sdk iphoneos|iphonesimulator] [--min-os-version <n>]
        [--android-ndk <ndk root>]

  --os    macos | ios | android | windows | linux
  --arch  arm64 | x64 | arm | ia32 | riscv64   (Dart `Architecture` names;
          android arm64-v8a = arm64, armeabi-v7a = arm, x86_64 = x64)

Prints the absolute path of the built library as the last stdout line.
Exits nonzero with a message on any failure. stdlib only; Python >= 3.12.

How it compiles: the needed libwebp .c files (src/dec, src/enc, src/dsp,
src/utils, sharpyuv) and native/radar_webp/radar_webp.c are compiled directly
with ONE C compiler and linked into one shared library. No CMake: every host
that can build the app already has the C compiler Flutter itself uses (Xcode
clang, NDK clang, MSVC cl.exe, the Linux CMake C++ compiler's C sibling), and
hook/build.dart passes that compiler in, so the same path runs everywhere.
Two flag dialects exist only because MSVC's cl.exe does not take GCC flags.

Compiler resolution (no guessing): --cc if given; else macOS/iOS use
`xcrun --sdk <sdk> -f clang`; else Android uses --android-ndk's clang; any
other case is an error.

Exported symbols: everything is compiled hidden (-fvisibility=hidden and
WEBP_EXTERN=extern), so only the four RADAR_WEBP_EXPORT functions are public.

ponytail: SSE4.1/AVX2 libwebp kernels are only built where the compiler enables
them by default (MSVC x64 does; clang/gcc x86_64 get SSE2 only). Add per-file
-msse4.1/-mavx2 if x86 encode/decode speed ever matters.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

LIBWEBP_VERSION = "1.6.0"
LIBWEBP_URL = (
    "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/"
    f"libwebp-{LIBWEBP_VERSION}.tar.gz"
)
LIBWEBP_SHA256 = "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564"
LIBWEBP_SOURCE_DIRS = ("src/dec", "src/enc", "src/dsp", "src/utils", "sharpyuv")
DOWNLOAD_TIMEOUT_SECONDS = 120
LIBRARY_BASENAME = "radar_webp"

REPO_ROOT = Path(__file__).resolve().parent.parent
SHIM_DIR = REPO_ROOT / "native" / "radar_webp"

OS_CHOICES = ("macos", "ios", "android", "windows", "linux")
ARCH_CHOICES = ("arm64", "x64", "arm", "ia32", "riscv64")
IOS_SDK_CHOICES = ("iphoneos", "iphonesimulator")

APPLE_ARCH = {"arm64": "arm64", "x64": "x86_64"}
ANDROID_TRIPLE = {
    "arm64": "aarch64-linux-android",
    "arm": "armv7a-linux-androideabi",
    "x64": "x86_64-linux-android",
    "ia32": "i686-linux-android",
    "riscv64": "riscv64-linux-android",
}
HOST_ARCH = {
    "arm64": "arm64", "aarch64": "arm64", "x86_64": "x64", "amd64": "x64",
    "riscv64": "riscv64",
}
NDK_HOST_TAG = {"Darwin": "darwin-x86_64", "Linux": "linux-x86_64",
                "Windows": "windows-x86_64"}


class BuildError(Exception):
    pass


def run(argv: list[str], env: dict[str, str] | None = None) -> str:
    result = subprocess.run(argv, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        raise BuildError(
            f"command failed (exit {result.returncode}, expected 0): {' '.join(argv)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_tarball(cache_dir: Path) -> Path:
    """Returns a verified tarball path. A cached file with the wrong hash is an
    error, not a silent re-download: something wrote a bad file there."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    tarball = cache_dir / f"libwebp-{LIBWEBP_VERSION}.tar.gz"
    if not tarball.exists():
        partial = tarball.with_suffix(".partial")
        with urllib.request.urlopen(LIBWEBP_URL, timeout=DOWNLOAD_TIMEOUT_SECONDS) as r, \
                partial.open("wb") as f:
            shutil.copyfileobj(r, f)
        partial.replace(tarball)
    actual = sha256_of(tarball)
    if actual != LIBWEBP_SHA256:
        raise BuildError(
            f"SHA-256 mismatch for {tarball}: expected {LIBWEBP_SHA256}, actual {actual}. "
            "Delete the file to re-download it."
        )
    return tarball


def extract(tarball: Path, cache_dir: Path) -> Path:
    source = cache_dir / f"libwebp-{LIBWEBP_VERSION}"
    marker = cache_dir / f"libwebp-{LIBWEBP_VERSION}.extracted"
    if marker.exists() and marker.read_text() == LIBWEBP_SHA256:
        return source
    if source.exists():
        shutil.rmtree(source)
    with tarfile.open(tarball) as tar:
        tar.extractall(cache_dir, filter="data")
    if not (source / "src" / "webp" / "encode.h").is_file():
        raise BuildError(f"expected {source}/src/webp/encode.h after extracting {tarball}")
    marker.write_text(LIBWEBP_SHA256)
    return source


def apple_sdk(args) -> str:
    return "macosx" if args.os == "macos" else args.ios_sdk


def resolve_compiler(args) -> str:
    if args.cc:
        return args.cc
    if args.os in ("macos", "ios"):
        return run(["xcrun", "--sdk", apple_sdk(args), "-f", "clang"]).strip()
    if args.os == "android":
        if not args.android_ndk:
            raise BuildError("android needs --cc or --android-ndk (got neither)")
        tag = NDK_HOST_TAG[platform.system()]
        exe = ".exe" if platform.system() == "Windows" else ""
        cc = Path(args.android_ndk) / "toolchains" / "llvm" / "prebuilt" / tag / "bin" / f"clang{exe}"
        if not cc.is_file():
            raise BuildError(f"expected NDK clang at {cc}, not found")
        return str(cc)
    raise BuildError(f"--os {args.os} needs --cc (the C compiler Flutter uses for this target)")


def gnu_target_flags(args) -> list[str]:
    if args.os in ("macos", "ios"):
        arch = APPLE_ARCH.get(args.arch)
        if arch is None:
            raise BuildError(f"--os {args.os} supports arch arm64/x64, got {args.arch}")
        sysroot = run(["xcrun", "--sdk", apple_sdk(args), "--show-sdk-path"]).strip()
        if args.os == "macos":
            triple = f"{arch}-apple-macos{args.min_os_version}"
        else:
            suffix = "-simulator" if args.ios_sdk == "iphonesimulator" else ""
            triple = f"{arch}-apple-ios{args.min_os_version}{suffix}"
        return ["-target", triple, "-isysroot", sysroot]
    if args.os == "android":
        return [f"--target={ANDROID_TRIPLE[args.arch]}{args.min_os_version}"]
    # linux: the app's Linux build is native-only, so the compiler's default
    # target is the target.
    host = HOST_ARCH.get(platform.machine().lower())
    if host != args.arch:
        raise BuildError(f"linux builds are native only: host arch {host}, requested {args.arch}")
    return []


def library_name(target_os: str) -> str:
    if target_os in ("macos", "ios"):
        return f"lib{LIBRARY_BASENAME}.dylib"
    if target_os == "windows":
        return f"{LIBRARY_BASENAME}.dll"
    return f"lib{LIBRARY_BASENAME}.so"


def source_files(libwebp: Path) -> list[Path]:
    files = [f for d in LIBWEBP_SOURCE_DIRS for f in sorted((libwebp / d).glob("*.c"))]
    return files + [SHIM_DIR / "radar_webp.c"]


def object_name(src: Path) -> str:
    return f"{src.parent.name}_{src.stem}"


def vcvars_env(script: str) -> dict[str, str]:
    """Environment after running the Visual Studio developer prompt script."""
    out = run(["cmd", "/d", "/c", f'call "{script}" >nul && set'])
    env = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    if "INCLUDE" not in env:
        raise BuildError(f"expected INCLUDE in the environment after {script}, not set")
    return env


def compile_all(jobs: list[list[str]], env) -> None:
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 1) as pool:
        for future in [pool.submit(run, job, env) for job in jobs]:
            future.result()


def build(args) -> Path:
    if args.os == "ios" and args.ios_sdk is None:
        raise BuildError("--os ios needs --ios-sdk iphoneos|iphonesimulator")
    if args.os in ("macos", "ios", "android") and args.min_os_version is None:
        raise BuildError(f"--os {args.os} needs --min-os-version")
    out_dir = Path(args.out_dir).resolve()
    cache_dir = Path(args.cache_dir).resolve() if args.cache_dir else out_dir / "cache"
    libwebp = extract(fetch_tarball(cache_dir), cache_dir)
    obj_dir = out_dir / "obj"
    obj_dir.mkdir(parents=True, exist_ok=True)
    library = out_dir / library_name(args.os)
    sources = source_files(libwebp)
    cc = resolve_compiler(args)
    defines = ["NDEBUG", "WEBP_EXTERN=extern"]
    includes = [libwebp, libwebp / "src", SHIM_DIR]

    if args.os == "windows":
        if not args.vcvars:
            raise BuildError("--os windows needs --vcvars (Visual Studio vcvars script)")
        env = vcvars_env(args.vcvars)
        base = ["/nologo", "/O2", "/c"] + [f"/D{d}" for d in defines] + [f"/I{i}" for i in includes]
        objs = [obj_dir / f"{object_name(s)}.obj" for s in sources]
        compile_all([[cc, *base, str(s), f"/Fo{o}"] for s, o in zip(sources, objs)], env)
        run([cc, "/nologo", "/LD", *map(str, objs), f"/Fe{library}",
             "/link", f"/IMPLIB:{obj_dir / (LIBRARY_BASENAME + '.lib')}"], env)
        return library

    target = gnu_target_flags(args)
    base = [*target, "-O2", "-fPIC", "-fvisibility=hidden", "-c"]
    base += [f"-D{d}" for d in defines] + [f"-I{i}" for i in includes]
    objs = [obj_dir / f"{object_name(s)}.o" for s in sources]
    compile_all([[cc, *base, str(s), "-o", str(o)] for s, o in zip(sources, objs)], None)
    link = [cc, *target, "-shared", *map(str, objs), "-o", str(library)]
    if args.os in ("macos", "ios"):
        link += ["-install_name", f"@rpath/{library.name}", "-headerpad_max_install_names"]
    else:
        link += ["-lm", "-Wl,--no-undefined"]
    run(link)
    return library


def main() -> int:
    parser = argparse.ArgumentParser(description="Build libwebp + radar shim as one shared library.")
    parser.add_argument("--os", required=True, choices=OS_CHOICES)
    parser.add_argument("--arch", required=True, choices=ARCH_CHOICES)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--cache-dir")
    parser.add_argument("--cc")
    parser.add_argument("--vcvars")
    parser.add_argument("--ios-sdk", choices=IOS_SDK_CHOICES)
    parser.add_argument("--min-os-version")
    parser.add_argument("--android-ndk")
    args = parser.parse_args()
    try:
        library = build(args)
    except (BuildError, OSError, tarfile.TarError) as e:
        print(f"build_libwebp.py: {e}", file=sys.stderr)
        return 1
    if not library.is_file():
        print(f"build_libwebp.py: expected {library} after linking, not found", file=sys.stderr)
        return 1
    print(library)
    return 0


if __name__ == "__main__":
    sys.exit(main())
