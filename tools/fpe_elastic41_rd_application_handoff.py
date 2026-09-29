#!/usr/bin/env python3
"""F-PE-ELASTIC41: request-gated offline RD-point application handoff."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import fpe_elastic36_rd_point_profile_interchange as elastic36

SCHEMA = "swap5.elastic41.application-handoff.v1"

class Elastic41Error(RuntimeError):
    pass

def parse_bool(text: str) -> bool:
    if text == "true":
        return True
    if text == "false":
        return False
    raise Elastic41Error("generated-prior-requested must be exactly true or false")

def _cleanup(*paths: Path) -> None:
    for path in paths:
        try:
            if path.exists():
                path.unlink()
        except OSError:
            pass

def prepare_handoff(
    generated_prior_requested: bool,
    gpkg: Path,
    x_rd_m: float,
    y_rd_m: float,
    row_output: Path,
    provenance_output: Path,
):
    _cleanup(row_output, provenance_output)

    if not generated_prior_requested:
        return {
            "status": "INACTIVE",
            "generated_prior_requested": False,
            "row_file": None,
            "provenance_file": None,
        }

    if not math.isfinite(float(x_rd_m)) or not math.isfinite(float(y_rd_m)):
        raise Elastic41Error("RD coordinates must be finite")

    try:
        provenance36, interchange = elastic36.compose(gpkg, float(x_rd_m), float(y_rd_m))
    except Exception as exc:
        raise Elastic41Error(str(exc)) from exc

    manifest = {
        **provenance36,
        "schema": SCHEMA,
        "generated_prior_requested": True,
        "row_file": str(row_output),
    }

    row_output.parent.mkdir(parents=True, exist_ok=True)
    provenance_output.parent.mkdir(parents=True, exist_ok=True)

    tmp_row = row_output.with_name(row_output.name + ".tmp")
    tmp_prov = provenance_output.with_name(provenance_output.name + ".tmp")
    _cleanup(tmp_row, tmp_prov)
    try:
        tmp_row.write_text(interchange, encoding="utf-8")
        tmp_prov.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        tmp_row.replace(row_output)
        tmp_prov.replace(provenance_output)
    except Exception:
        _cleanup(tmp_row, tmp_prov, row_output, provenance_output)
        raise

    return {
        "status": "OK",
        "generated_prior_requested": True,
        "row_file": str(row_output),
        "provenance_file": str(provenance_output),
        "selection": manifest,
    }

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--generated-prior-requested", required=True)
    ap.add_argument("--gpkg", required=True)
    ap.add_argument("--x", required=True, type=float)
    ap.add_argument("--y", required=True, type=float)
    ap.add_argument("--row-output", required=True)
    ap.add_argument("--provenance-output", required=True)
    args = ap.parse_args()

    row_output = Path(args.row_output)
    provenance_output = Path(args.provenance_output)

    try:
        requested = parse_bool(args.generated_prior_requested)
        result = prepare_handoff(
            requested,
            Path(args.gpkg),
            args.x,
            args.y,
            row_output,
            provenance_output,
        )
    except Elastic41Error as exc:
        _cleanup(row_output, provenance_output)
        raise SystemExit(f"F_PE_ELASTIC41_FAIL {exc}") from exc

    print("F_PE_ELASTIC41_HANDOFF=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
    print("F_PE_ELASTIC41=PASS")

if __name__ == "__main__":
    main()
