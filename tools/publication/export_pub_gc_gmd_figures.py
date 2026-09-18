#!/usr/bin/env python3
"""Export governed PUB-GC SVG figures to GMD-ready vector PDFs.

The repository SVGs remain the scientific source. This script performs only
presentation conversion and validates size, page geometry, font embedding and
renderability. It also creates a flat submission ZIP and a machine-readable
manifest.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

# Make Cairo PDF metadata reproducible across runs before the backend is used.
os.environ.setdefault("SOURCE_DATE_EPOCH", "0")

import cairosvg
from PIL import Image, ImageChops
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "docs/publication/PUB_GC_GMD_FIGURE_EXPORT_PLAN.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def svg_geometry(path: Path) -> tuple[float, float]:
    root = ET.parse(path).getroot()
    viewbox = root.attrib.get("viewBox")
    if viewbox:
        vals = [float(x) for x in re.split(r"[ ,]+", viewbox.strip())]
        if len(vals) == 4 and vals[2] > 0 and vals[3] > 0:
            return vals[2], vals[3]
    def val(name: str) -> float:
        raw = root.attrib[name]
        m = re.match(r"([0-9.]+)", raw)
        if not m:
            raise ValueError(f"cannot parse SVG {name}: {raw}")
        return float(m.group(1))
    return val("width"), val("height")


def font_embedding(pdf: Path) -> list[dict[str, str]]:
    p = subprocess.run(
        ["pdffonts", str(pdf)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    rows: list[dict[str, str]] = []
    lines = p.stdout.splitlines()
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("name"):
            continue
        # pdffonts prints a column separator containing dashes and spaces.
        if stripped.replace("-", "").replace(" ", "") == "":
            continue
        parts = line.split()
        # pdffonts allows a multi-token font type such as "CID TrueType".
        # The final columns are stable: encoding, emb, sub, uni, object ID.
        if len(parts) < 8:
            continue
        rows.append(
            {
                "name": parts[0],
                "type": " ".join(parts[1:-6]),
                "encoding": parts[-6],
                "embedded": parts[-5],
                "subset": parts[-4],
                "unicode": parts[-3],
            }
        )
    return rows


def render_check(pdf: Path, work: Path) -> dict[str, object]:
    prefix = work / pdf.stem
    subprocess.run(
        ["pdftoppm", "-png", "-singlefile", "-r", "150", str(pdf), str(prefix)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    png = Path(str(prefix) + ".png")
    img = Image.open(png).convert("RGB")
    bg = Image.new("RGB", img.size, "white")
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()
    if bbox is None:
        raise RuntimeError(f"blank render: {pdf.name}")
    left, top, right, bottom = bbox
    w, h = img.size
    if left <= 0 or top <= 0 or right >= w or bottom >= h:
        raise RuntimeError(f"render touches page edge (possible clipping): {pdf.name} bbox={bbox} size={img.size}")
    return {
        "raster_width_px": w,
        "raster_height_px": h,
        "nonwhite_bbox_px": [left, top, right, bottom],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="build/gmd-figures")
    ap.add_argument("--zip", dest="zip_path", default="build/pub-gc-gmd-figure-package.zip")
    args = ap.parse_args()

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    out = ROOT / args.out_dir
    zip_path = ROOT / args.zip_path
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    zip_path.parent.mkdir(parents=True, exist_ok=True)

    limit = int(plan["upload_rule"]["max_pdf_figure_mb"] * 1024 * 1024)
    records = []

    with tempfile.TemporaryDirectory(prefix="pub-gc-pdf-render-") as td:
        work = Path(td)
        for item in plan["figures"]:
            src = ROOT / item["source"]
            dst = out / item["target"]
            if not src.is_file():
                raise FileNotFoundError(src)

            cairosvg.svg2pdf(url=str(src), write_to=str(dst))
            size = dst.stat().st_size
            if size <= 0 or size > limit:
                raise RuntimeError(f"{dst.name}: size {size} exceeds PDF limit {limit}")

            reader = PdfReader(str(dst))
            if len(reader.pages) != 1:
                raise RuntimeError(f"{dst.name}: expected one page, got {len(reader.pages)}")
            page = reader.pages[0]
            pw = float(page.mediabox.width)
            ph = float(page.mediabox.height)

            sw, sh = svg_geometry(src)
            source_ratio = sw / sh
            pdf_ratio = pw / ph
            rel_ratio_error = abs(pdf_ratio - source_ratio) / source_ratio
            if rel_ratio_error > 0.002:
                raise RuntimeError(
                    f"{dst.name}: aspect-ratio drift source={source_ratio} pdf={pdf_ratio}"
                )

            fonts = font_embedding(dst)
            nonembedded = [x for x in fonts if x["embedded"].lower() != "yes"]
            if nonembedded:
                raise RuntimeError(f"{dst.name}: non-embedded fonts: {nonembedded}")

            render = render_check(dst, work)
            records.append(
                {
                    "figure": item["id"],
                    "source": item["source"],
                    "source_sha256": sha256(src),
                    "target": item["target"],
                    "pdf_sha256": sha256(dst),
                    "pdf_size_bytes": size,
                    "pdf_page_count": 1,
                    "pdf_media_box_points": [pw, ph],
                    "source_aspect_ratio": source_ratio,
                    "pdf_aspect_ratio": pdf_ratio,
                    "relative_aspect_ratio_error": rel_ratio_error,
                    "fonts": fonts,
                    **render,
                }
            )

    manifest = {
        "schema": "pub-gc-gmd-figure-export-result-v1",
        "source_plan": str(PLAN.relative_to(ROOT)),
        "exporter": "CairoSVG",
        "checks": {
            "all_figures_present": len(records) == 7,
            "one_page_each": True,
            "max_pdf_bytes": limit,
            "all_within_pdf_size_limit": all(x["pdf_size_bytes"] <= limit for x in records),
            "aspect_ratio_preserved": True,
            "all_detected_fonts_embedded": True,
            "render_nonblank_and_not_edge_clipped": True,
        },
        "figures": records,
    }
    manifest_path = out / "figure-export-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    # Build the flat submission ZIP with fixed entry metadata so its bytes are
    # reproducible as well. ZIP timestamps cannot predate 1980.
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file_path, arcname in [
            *[(out / item["target"], item["target"]) for item in plan["figures"]],
            (manifest_path, manifest_path.name),
        ]:
            info = zipfile.ZipInfo(arcname, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, file_path.read_bytes())

    print("PUB_GC_GMD_FIGURE_EXPORT=PASS")
    print(f"PUB_GC_GMD_FIGURE_COUNT={len(records)}")
    print(f"PUB_GC_GMD_FIGURE_ZIP={zip_path.relative_to(ROOT)}")
    print(f"PUB_GC_GMD_FIGURE_ZIP_SHA256={sha256(zip_path)}")
    for x in records:
        print(
            f"{x['figure']} {x['target']} size={x['pdf_size_bytes']} "
            f"sha256={x['pdf_sha256']} fonts={len(x['fonts'])}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
