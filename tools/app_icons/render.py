"""The only SVG renderer: headless Chrome at RENDER_PX once per SVG, Pillow LANCZOS down."""
import atexit
import os
import shutil
import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path

from PIL import Image

RENDER_PX = 1024
CHROME_TIMEOUT_S = 60
CHROME_MAC_APP = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_NAMES = ("google-chrome", "chromium")

_scratch = Path(tempfile.mkdtemp(prefix="app_icons_"))
atexit.register(shutil.rmtree, _scratch, ignore_errors=True)


def _find_chrome() -> str:
    tried = []
    env = os.environ.get("CHROME")
    if env:
        tried.append(f"$CHROME={env}")
        if Path(env).is_file():
            return env
    for name in CHROME_NAMES:
        tried.append(f"which {name}")
        found = shutil.which(name)
        if found:
            return found
    tried.append(CHROME_MAC_APP)
    if Path(CHROME_MAC_APP).is_file():
        return CHROME_MAC_APP
    raise RuntimeError(f"Chrome not found; tried: {tried}")


@lru_cache(maxsize=None)
def _render_large(svg: Path) -> Image.Image:
    html = _scratch / f"{svg.parent.name}_{svg.stem}.html"
    png = html.with_suffix(".png")
    html.write_text(
        '<html><body style="margin:0;background:transparent">'
        f'<img src="{svg.resolve().as_uri()}" width="{RENDER_PX}" height="{RENDER_PX}" '
        'style="display:block"></body></html>'
    )
    cmd = [
        _find_chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--default-background-color=00000000", f"--window-size={RENDER_PX},{RENDER_PX}",
        f"--screenshot={png}", "--user-data-dir=" + str(_scratch / "profile"),
        html.as_uri(),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=CHROME_TIMEOUT_S)
    if res.returncode != 0 or not png.is_file():
        raise RuntimeError(
            f"Chrome failed rendering {svg}: rc={res.returncode} stderr={res.stderr[-500:]}"
        )
    img = Image.open(png).convert("RGBA")
    if img.size != (RENDER_PX, RENDER_PX):
        raise RuntimeError(f"Chrome output for {svg}: expected {RENDER_PX}x{RENDER_PX}, got {img.size}")
    return img


def render(svg: Path, px: int) -> Image.Image:
    big = _render_large(Path(svg))
    return big if px == RENDER_PX else big.resize((px, px), Image.Resampling.LANCZOS)
