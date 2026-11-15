"""Android adaptive icon: 3 PNG layers + legacy ic_launcher.png per density, plus the adaptive XML."""
from pathlib import Path

from PIL import Image

from .render import render

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
CANVAS_DP = 108
LEGACY_DP = 48
VISIBLE_DP = 72  # the part of the 108 dp canvas that the launcher mask shows
LAYERS = ("background", "foreground", "monochrome")

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""


def _save(img: Image.Image, path: Path, written: list[Path]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=False)
    written.append(path)


def generate(src_dir: Path, repo_root: Path) -> list[Path]:
    res = repo_root / "android/app/src/main/res"
    written: list[Path] = []
    for density, scale in DENSITIES.items():
        canvas_px = int(CANVAS_DP * scale)
        out = res / f"mipmap-{density}"
        layers = {n: render(src_dir / f"{n}.svg", canvas_px) for n in LAYERS}
        for name, img in layers.items():
            _save(img, out / f"ic_launcher_{name}.png", written)

        full = Image.alpha_composite(layers["background"], layers["foreground"])
        margin = round(canvas_px * (CANVAS_DP - VISIBLE_DP) / 2 / CANVAS_DP)
        visible = full.crop((margin, margin, canvas_px - margin, canvas_px - margin))
        legacy_px = int(LEGACY_DP * scale)
        legacy = visible.resize((legacy_px, legacy_px), Image.Resampling.LANCZOS)
        _save(legacy, out / "ic_launcher.png", written)

    xml = res / "mipmap-anydpi-v26/ic_launcher.xml"
    xml.parent.mkdir(parents=True, exist_ok=True)
    xml.write_text(ADAPTIVE_XML)
    written.append(xml)
    return written
