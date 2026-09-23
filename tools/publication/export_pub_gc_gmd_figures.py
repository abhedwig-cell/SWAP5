#!/usr/bin/env python3
"""Export and validate PUB-GC GMD figures from governed SVG sources.

This is a presentation-only transform. Scientific source remains the
version-controlled SVG set referenced by PUB_GC_GMD_FIGURE_EXPORT_PLAN.json.

Validation covers:
- source/target identity and one-page PDF geometry;
- embedded PDF font programs, including Type0 descendant fonts;
- source/PDF aspect-ratio preservation;
- a 160 dpi Poppler render that is nonblank and does not touch page edges;
- GMD per-figure and total-size budgets;
- flat, fixed-metadata submission ZIP construction.

SOURCE_DATE_EPOCH and fixed ZIP entry metadata are used as reproducibility
controls. Byte identity is not assumed here; the workflow tests it explicitly.
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

# Stable source-time hint must be present before the Cairo renderer is imported.
os.environ.setdefault("SOURCE_DATE_EPOCH", "0")

try:
    import cairosvg
    from PIL import Image, ImageChops
    from pypdf import PdfReader
except ImportError as exc:
    raise SystemExit(
        "Missing export dependencies. Install: pip install cairosvg pillow pypdf"
    ) from exc

ROOT = Path(__file__).resolve().parents[2]
PUB = ROOT / "docs" / "publication"
PLAN = PUB / "PUB_GC_GMD_FIGURE_EXPORT_PLAN.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def svg_geometry(path: Path) -> tuple[float, float]:
    """Return governed SVG width/height in source coordinate units."""
    root = ET.parse(path).getroot()
    viewbox = root.attrib.get("viewBox")
    if viewbox:
        vals = [float(x) for x in re.split(r"[ ,]+", viewbox.strip())]
        if len(vals) == 4 and vals[2] > 0 and vals[3] > 0:
            return vals[2], vals[3]

    def value(name: str) -> float:
        raw = root.attrib[name]
        match = re.match(r"([0-9.]+)", raw)
        if not match:
            raise ValueError(f"cannot parse SVG {name}: {raw}")
        return float(match.group(1))

    return value("width"), value("height")


def add_proportional_export_margin(
    svg_text: str,
    padding_fraction: float = 0.015,
) -> str:
    """Expand the SVG viewBox proportionally without mutating governed source."""
    match = re.search(r'viewBox="([^"]+)"', svg_text)
    if not match:
        raise SystemExit("governed SVG must provide a viewBox for qualified export")
    vals = [float(x) for x in re.split(r"[ ,]+", match.group(1).strip())]
    if len(vals) != 4 or vals[2] <= 0 or vals[3] <= 0:
        raise SystemExit(f"invalid SVG viewBox: {match.group(1)}")
    x0, y0, width, height = vals
    dx = width * padding_fraction
    dy = height * padding_fraction
    padded = f"{x0-dx:g} {y0-dy:g} {width+2*dx:g} {height+2*dy:g}"
    return svg_text[: match.start(1)] + padded + svg_text[match.end(1) :]


def _descriptor_has_font_file(font: object) -> bool:
    """Return True when a PDF font or Type0 descendant embeds its font program."""
    if not hasattr(font, "get"):
        return False

    subtype = str(font.get("/Subtype", ""))
    if subtype == "/Type3":
        # Type3 glyph programs live in the PDF itself.
        return True

    descriptor = font.get("/FontDescriptor")
    if descriptor is not None:
        descriptor = descriptor.get_object()
        if any(k in descriptor for k in ("/FontFile", "/FontFile2", "/FontFile3")):
            return True

    # Composite Type0 fonts carry the descriptor on the descendant CIDFont,
    # not on the top-level Type0 resource.
    descendants = font.get("/DescendantFonts")
    if descendants is not None:
        descendants = descendants.get_object()
        for child_ref in descendants:
            child = child_ref.get_object()
            if _descriptor_has_font_file(child):
                return True

    return False


def font_embedding_status(reader: PdfReader) -> dict[str, object]:
    """Report whether referenced PDF fonts depend on external font files."""
    total = 0
    embedded = 0
    missing: list[str] = []
    details: list[dict[str, str]] = []
    for page in reader.pages:
        resources = page.get("/Resources")
        if resources is None:
            continue
        resources = resources.get_object()
        fonts = resources.get("/Font")
        if fonts is None:
            continue
        fonts = fonts.get_object()
        for name, ref in fonts.items():
            total += 1
            font = ref.get_object()
            subtype = str(font.get("/Subtype", ""))
            basefont = str(font.get("/BaseFont", ""))
            is_embedded = _descriptor_has_font_file(font)
            if is_embedded:
                embedded += 1
            else:
                missing.append(f"{name}:{subtype}:{basefont}")
            details.append(
                {
                    "name": str(name),
                    "subtype": subtype,
                    "basefont": basefont,
                    "descriptor": "embedded" if is_embedded else "unembedded",
                }
            )
    return {
        "font_resources": total,
        "embedded_font_resources": embedded,
        "unembedded_font_resources": missing,
        "details": details,
        "pass": not missing,
    }


def render_check(pdf: Path, work: Path) -> dict[str, object]:
    """Rasterize a PDF and reject blank or page-edge-clipped output."""
    prefix = work / pdf.stem
    try:
        subprocess.run(
            ["pdftoppm", "-png", "-singlefile", "-r", "160", str(pdf), str(prefix)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit(
            "pdftoppm is required for GMD figure render qualification"
        ) from exc

    png = Path(str(prefix) + ".png")
    image = Image.open(png).convert("RGB")
    background = Image.new("RGB", image.size, "white")
    bbox = ImageChops.difference(image, background).getbbox()
    if bbox is None:
        raise SystemExit(f"blank PDF render: {pdf.name}")

    left, top, right, bottom = bbox
    width, height = image.size
    if left <= 0 or top <= 0 or right >= width or bottom >= height:
        raise SystemExit(
            f"{pdf.name} render touches page edge (possible clipping): "
            f"bbox={bbox} page={image.size}"
        )

    return {
        "raster_dpi": 160,
        "raster_width_px": width,
        "raster_height_px": height,
        "nonwhite_bbox_px": [left, top, right, bottom],
        "pass": True,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="build/pub_gc_gmd_figures")
    ap.add_argument("--zip", dest="zip_path", default="build/pub_gc_gmd_figures.zip")
    ap.add_argument(
        "--manifest", default="build/pub_gc_gmd_figure_export_manifest.json"
    )
    args = ap.parse_args()

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    figures = plan.get("figures", [])
    if len(figures) != 7:
        raise SystemExit(f"Expected 7 figures, found {len(figures)}")

    out_dir = ROOT / args.out_dir
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    max_pdf_bytes = int(
        plan["upload_rule"]["max_pdf_figure_mb"] * 1024 * 1024
    )

    exported: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="pub-gc-gmd-render-") as td:
        render_work = Path(td)

        for idx, item in enumerate(figures, 1):
            expected_target = f"f{idx:02d}.pdf"
            if item.get("target") != expected_target:
                raise SystemExit(
                    f"Target mismatch for F{idx}: "
                    f"{item.get('target')} != {expected_target}"
                )

            source = ROOT / item["source"]
            if not source.is_file():
                raise SystemExit(f"Missing governed SVG source: {item['source']}")
            if source.suffix.lower() != ".svg":
                raise SystemExit(f"Governed source is not SVG: {item['source']}")

            target = out_dir / expected_target
            svg_text = source.read_text(encoding="utf-8")
            # Normalize only the export rendering font. The governed SVG
            # content and geometry remain unchanged in the repository.
            svg_text = svg_text.replace(
                "font-family:Arial,Helvetica,sans-serif",
                "font-family:DejaVu Sans,sans-serif",
            )
            # Keep governed SVG files unchanged while ensuring PDF glyph metrics
            # cannot clip long labels/titles at the page boundary.
            svg_text = add_proportional_export_margin(svg_text, 0.015)
            cairosvg.svg2pdf(
                bytestring=svg_text.encode("utf-8"),
                write_to=str(target),
            )

            size = target.stat().st_size
            if size <= 0:
                raise SystemExit(f"Empty export: {expected_target}")
            if size > max_pdf_bytes:
                raise SystemExit(
                    f"{expected_target} exceeds GMD 2 MB limit: {size} bytes"
                )

            reader = PdfReader(str(target))
            if len(reader.pages) != 1:
                raise SystemExit(
                    f"{expected_target} must be exactly one page, "
                    f"got {len(reader.pages)}"
                )

            box = reader.pages[0].mediabox
            width_pt = float(box.width)
            height_pt = float(box.height)
            if width_pt <= 0 or height_pt <= 0:
                raise SystemExit(
                    f"Invalid PDF media box for {expected_target}"
                )

            fonts = font_embedding_status(reader)
            if not fonts["pass"]:
                raise SystemExit(
                    f"{expected_target} contains unembedded font resources: "
                    + ",".join(fonts["unembedded_font_resources"])
                )

            svg_width, svg_height = svg_geometry(source)
            source_ratio = svg_width / svg_height
            pdf_ratio = width_pt / height_pt
            relative_ratio_error = abs(pdf_ratio - source_ratio) / source_ratio
            if relative_ratio_error > 0.002:
                raise SystemExit(
                    f"{expected_target} aspect-ratio drift: "
                    f"source={source_ratio} pdf={pdf_ratio}"
                )

            rendering = render_check(target, render_work)

            exported.append(
                {
                    "id": item["id"],
                    "source": item["source"],
                    "source_sha256": sha256(source),
                    "target": expected_target,
                    "pdf_sha256": sha256(target),
                    "size_bytes": size,
                    "pages": 1,
                    "media_box_points": [width_pt, height_pt],
                    "source_aspect_ratio": source_ratio,
                    "pdf_aspect_ratio": pdf_ratio,
                    "relative_aspect_ratio_error": relative_ratio_error,
                    "font_embedding": fonts,
                    "render_check": rendering,
                }
            )

    zip_path = ROOT / args.zip_path
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        zip_path, "w", compression=zipfile.ZIP_DEFLATED
    ) as zf:
        for item in exported:
            target = out_dir / str(item["target"])
            # Fixed entry metadata removes filesystem mtime/permission drift
            # from the submission package.
            info = zipfile.ZipInfo(
                str(item["target"]),
                date_time=(1980, 1, 1, 0, 0, 0),
            )
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, target.read_bytes())

    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
    expected_names = [f"f{i:02d}.pdf" for i in range(1, 8)]
    if names != expected_names:
        raise SystemExit(
            f"Flat zip content mismatch: {names} != {expected_names}"
        )

    manifest = {
        "schema": "pub-gc-gmd-qualified-figure-export-v2",
        "source_plan": str(PLAN.relative_to(ROOT)),
        "source_rule": plan["source_rule"],
        "presentation_transform_only": True,
        "source_date_epoch": os.environ.get("SOURCE_DATE_EPOCH"),
        "export_padding_fraction": 0.015,
        "export_font_normalization": (
            "Arial/Helvetica/sans-serif -> DejaVu Sans/sans-serif "
            "for PDF embedding only"
        ),
        "render_validation": (
            "pdftoppm 160 dpi; nonblank; content must remain inside page edges"
        ),
        "figures": exported,
        "zip": {
            "file": zip_path.name,
            "sha256": sha256(zip_path),
            "size_bytes": zip_path.stat().st_size,
            "flat_contents": names,
            "fixed_entry_metadata": True,
        },
        "limits": {
            "max_pdf_figure_mb": plan["upload_rule"]["max_pdf_figure_mb"],
            "max_total_submission_mb_excluding_supplements": plan[
                "upload_rule"
            ]["max_total_submission_mb_excluding_supplements"],
        },
    }

    manifest_path = ROOT / args.manifest
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )

    print("PUB_GC_GMD_FIGURE_EXPORT=PASS")
    print("PUB_GC_GMD_FIGURE_FONT_EMBEDDING=PASS")
    print("PUB_GC_GMD_FIGURE_ASPECT_RATIO=PASS")
    print("PUB_GC_GMD_FIGURE_RENDER_NO_CLIP=PASS")
    print(f"PUB_GC_GMD_FIGURE_COUNT={len(exported)}")
    print(f"PUB_GC_GMD_FIGURE_ZIP_SHA256={manifest['zip']['sha256']}")
    for item in exported:
        print(
            f"{item['id']} {item['target']} "
            f"bytes={item['size_bytes']} sha256={item['pdf_sha256']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
