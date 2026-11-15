"""Windows ico, Linux window icon, and Web icons from the Echo Rain SVGs."""
from pathlib import Path

from PIL import Image

from .render import render

ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)
LINUX_ICON_PX = 256
FAVICON_PX = 32
WEB_ICON_SIZES = (192, 512)

WINDOWS_ICO = "windows/runner/resources/app_icon.ico"
LINUX_ICON = "linux/runner/resources/app_icon.png"
FAVICON = "web/favicon.png"
WEB_ICONS_DIR = "web/icons"


def _save_png(img: Image.Image, path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=False)
    return path


def generate(src_dir: Path, repo_root: Path) -> list[Path]:
    macos = render(src_dir / "macos.svg", 1024)
    ios_light = src_dir / "ios-light.svg"
    written = []

    ico_path = repo_root / WINDOWS_ICO
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    largest = max(ICO_SIZES)
    macos.resize((largest, largest), Image.Resampling.LANCZOS).save(
        ico_path, format="ICO", sizes=[(s, s) for s in ICO_SIZES]
    )
    written.append(ico_path)

    written.append(_save_png(render(src_dir / "macos.svg", LINUX_ICON_PX), repo_root / LINUX_ICON))
    written.append(_save_png(render(src_dir / "macos.svg", FAVICON_PX), repo_root / FAVICON))

    for px in WEB_ICON_SIZES:
        icons = repo_root / WEB_ICONS_DIR
        written.append(_save_png(render(ios_light, px), icons / f"Icon-{px}.png"))
        maskable = Image.alpha_composite(
            render(src_dir / "background.svg", px), render(src_dir / "foreground.svg", px)
        )
        written.append(_save_png(maskable, icons / f"Icon-maskable-{px}.png"))
    return written
