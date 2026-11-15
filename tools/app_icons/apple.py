"""iOS (single-size, dark/tinted appearances) and macOS appiconset generation."""

import json
from pathlib import Path

from PIL import Image

from .render import render

IOS_SET = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
MACOS_SET = Path("macos/Runner/Assets.xcassets/AppIcon.appiconset")

# (svg stem, file name, appearance value or None for the light/default entry)
IOS_ENTRIES = [
    ("ios-light", "Icon-App-1024x1024@1x.png", None),
    ("ios-dark", "Icon-App-1024x1024-dark.png", "dark"),
    ("ios-tinted", "Icon-App-1024x1024-tinted.png", "tinted"),
]
IOS_SIZE = 1024
# File names are the ones the existing macOS Contents.json already references.
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def _save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def _flatten_rgb(img: Image.Image) -> Image.Image:
    """Drop alpha by compositing over black (iOS requires an opaque marketing icon)."""
    bg = Image.new("RGBA", img.size, (0, 0, 0, 255))
    return Image.alpha_composite(bg, img).convert("RGB")


def _ios(src_dir: Path, repo_root: Path) -> list[Path]:
    out_dir = repo_root / IOS_SET
    keep = {name for _, name, _ in IOS_ENTRIES} | {"Contents.json"}
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.iterdir():
        if stale.name not in keep:
            stale.unlink()

    written, images = [], []
    for stem, name, appearance in IOS_ENTRIES:
        img = _flatten_rgb(render(src_dir / f"{stem}.svg", IOS_SIZE))
        _save_png(img, out_dir / name)
        written.append(out_dir / name)
        entry = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance:
            entry = {
                "appearances": [{"appearance": "luminosity", "value": appearance}],
                **entry,
            }
        images.append(entry)

    contents = out_dir / "Contents.json"
    contents.write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}},
                   indent=2, sort_keys=True) + "\n"
    )
    return written + [contents]


def _macos(src_dir: Path, repo_root: Path) -> list[Path]:
    out_dir = repo_root / MACOS_SET
    big = render(src_dir / "macos.svg", max(MACOS_SIZES))
    written = []
    for px in MACOS_SIZES:
        img = big if px == big.width else big.resize((px, px), Image.Resampling.LANCZOS)
        path = out_dir / f"app_icon_{px}.png"
        _save_png(img, path)
        written.append(path)
    return written


def generate(src_dir: Path, repo_root: Path) -> list[Path]:
    return _ios(src_dir, repo_root) + _macos(src_dir, repo_root)
