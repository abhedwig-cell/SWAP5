#!/usr/bin/env python3
"""Export and validate PUB-GC GMD figures from governed SVG sources.

This is a presentation-only transform. Scientific source remains the
version-controlled SVG set referenced by PUB_GC_GMD_FIGURE_EXPORT_PLAN.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

try:
    import cairosvg
    from pypdf import PdfReader
except ImportError as exc:
    raise SystemExit(
        "Missing export dependencies. Install: pip install cairosvg pypdf"
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


def font_embedding_status(reader: PdfReader) -> dict[str, object]:
    """Report whether any referenced PDF fonts depend on unembedded files."""
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
            descriptor = font.get("/FontDescriptor")
            subtype = str(font.get("/Subtype", ""))
            basefont = str(font.get("/BaseFont", ""))
            if descriptor is None:
                details.append({"name": str(name), "subtype": subtype, "basefont": basefont, "descriptor": "none"})
                if subtype == "/Type3":
                    embedded += 1
                else:
                    missing.append(f"{name}:{subtype}:{basefont}")
                continue
            descriptor = descriptor.get_object()
            if any(k in descriptor for k in ("/FontFile", "/FontFile2", "/FontFile3")):
                embedded += 1
                details.append({"name": str(name), "subtype": subtype, "basefont": basefont, "descriptor": "embedded"})
            else:
                details.append({"name": str(name), "subtype": subtype, "basefont": basefont, "descriptor": "unembedded"})
                missing.append(f"{name}:{subtype}:{basefont}")
    return {
        "font_resources": total,
        "embedded_font_resources": embedded,
        "unembedded_font_resources": missing,
        "details": details,
        "pass": not missing,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="build/pub_gc_gmd_figures")
    ap.add_argument("--zip", dest="zip_path", default="build/pub_gc_gmd_figures.zip")
    ap.add_argument("--manifest", default="build/pub_gc_gmd_figure_export_manifest.json")
    args = ap.parse_args()

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    figures = plan.get("figures", [])
    if len(figures) != 7:
        raise SystemExit(f"Expected 7 figures, found {len(figures)}")

    out_dir = ROOT / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    max_pdf_bytes = int(plan["upload_rule"]["max_pdf_figure_mb"] * 1024 * 1024)

    exported = []
    for idx, item in enumerate(figures, 1):
        expected_target = f"f{idx:02d}.pdf"
        if item.get("target") != expected_target:
            raise SystemExit(
                f"Target mismatch for F{idx}: {item.get('target')} != {expected_target}"
            )

        source = ROOT / item["source"]
        if not source.is_file():
            raise SystemExit(f"Missing governed SVG source: {item['source']}")
        if source.suffix.lower() != ".svg":
            raise SystemExit(f"Governed source is not SVG: {item['source']}")

        target = out_dir / expected_target
        svg_text = source.read_text(encoding="utf-8")
        # GMD production PDF must not depend on non-embedded base/fallback fonts.
        # Normalize only the export rendering font; governed SVG content/geometry
        # remains unchanged in the repository.
        svg_text = svg_text.replace(
            "font-family:Arial,Helvetica,sans-serif",
            "font-family:DejaVu Sans,sans-serif",
        )
        cairosvg.svg2pdf(bytestring=svg_text.encode("utf-8"), write_to=str(target))

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
                f"{expected_target} must be exactly one page, got {len(reader.pages)}"
            )

        box = reader.pages[0].mediabox
        width_pt = float(box.width)
        height_pt = float(box.height)
        if width_pt <= 0 or height_pt <= 0:
            raise SystemExit(f"Invalid PDF media box for {expected_target}")

        fonts = font_embedding_status(reader)
        if not fonts["pass"]:
            raise SystemExit(
                f"{expected_target} contains unembedded font resources: "
                + ",".join(fonts["unembedded_font_resources"])
            )

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
                "font_embedding": fonts,
            }
        )

    zip_path = ROOT / args.zip_path
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for item in exported:
            target = out_dir / item["target"]
            zf.write(target, arcname=item["target"])

    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
    expected_names = [f"f{i:02d}.pdf" for i in range(1, 8)]
    if names != expected_names:
        raise SystemExit(f"Flat zip content mismatch: {names} != {expected_names}")

    manifest = {
        "schema": "pub-gc-gmd-qualified-figure-export-v1",
        "source_plan": str(PLAN.relative_to(ROOT)),
        "source_rule": plan["source_rule"],
        "presentation_transform_only": True,
        "export_font_normalization": "Arial/Helvetica/sans-serif -> DejaVu Sans/sans-serif for PDF embedding only",
        "figures": exported,
        "zip": {
            "file": zip_path.name,
            "sha256": sha256(zip_path),
            "size_bytes": zip_path.stat().st_size,
            "flat_contents": names,
        },
        "limits": {
            "max_pdf_figure_mb": plan["upload_rule"]["max_pdf_figure_mb"],
            "max_total_submission_mb_excluding_supplements": plan["upload_rule"][
                "max_total_submission_mb_excluding_supplements"
            ],
        },
    }

    manifest_path = ROOT / args.manifest
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print("PUB_GC_GMD_FIGURE_EXPORT=PASS")
    print("PUB_GC_GMD_FIGURE_FONT_EMBEDDING=PASS")
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
