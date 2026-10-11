#!/usr/bin/env python3
"""F-PE-ELASTIC33: materialize ELASTIC24 JSON as canonical ELASTIC22 row interchange."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

INPUT_SCHEMA = "swap5.elastic24.bro-profile.v1"
OUTPUT_MAGIC = "SWAP5_ELASTIC33_BRO_ROWS_V1"
SOURCE_ARTIFACT_SHA256 = "f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"
TOL_M = 1.0e-10

TOP_LEVEL_KEYS = {
    "schema",
    "source_artifact_sha256",
    "normalsoilprofile_id",
    "soilunit",
    "horizon_count",
    "horizons",
}
HORIZON_KEYS = {
    "layernumber",
    "top_depth_m",
    "bottom_depth_m",
    "staringseriesblock",
    "dry_density_g_cm3",
    "organic_matter_pct",
    "peat_type",
}
COLUMNS = (
    "normalsoilprofile_id",
    "layer_number",
    "top_depth_m",
    "bottom_depth_m",
    "staringseriesblock",
    "rho_dry_g_cm3",
    "organic_matter_available",
    "organic_matter_pct",
    "peat_type_present",
)


class Elastic33Error(RuntimeError):
    pass


def _exact_int(value: Any, name: str) -> int:
    if isinstance(value, bool):
        raise Elastic33Error(f"{name} must be integer")
    if not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise Elastic33Error(f"{name} must be integer")
    ivalue = int(value)
    if ivalue != value:
        raise Elastic33Error(f"{name} must be exact integer")
    return ivalue


def _finite_float(value: Any, name: str) -> float:
    if isinstance(value, bool):
        raise Elastic33Error(f"{name} must be finite numeric")
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise Elastic33Error(f"{name} must be finite numeric") from exc
    if not math.isfinite(result):
        raise Elastic33Error(f"{name} must be finite numeric")
    return result


def _f64(value: float) -> str:
    return format(float(value), ".17g")


def load_profile(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise Elastic33Error(f"missing input JSON: {path}")
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise Elastic33Error("invalid input JSON") from exc
    if not isinstance(raw, dict):
        raise Elastic33Error("top-level JSON must be an object")
    return raw


def materialize_interchange(profile: dict[str, Any]) -> str:
    if set(profile) != TOP_LEVEL_KEYS:
        raise Elastic33Error("top-level schema keys differ from ELASTIC24 v1")
    if profile["schema"] != INPUT_SCHEMA:
        raise Elastic33Error("unsupported profile schema")
    if profile["source_artifact_sha256"] != SOURCE_ARTIFACT_SHA256:
        raise Elastic33Error("unexpected source artifact hash")

    profile_id = _exact_int(profile["normalsoilprofile_id"], "normalsoilprofile_id")
    if profile_id <= 0:
        raise Elastic33Error("normalsoilprofile_id must be positive")
    soilunit = profile["soilunit"]
    if soilunit is not None and not isinstance(soilunit, str):
        raise Elastic33Error("soilunit must be string or null")

    horizons = profile["horizons"]
    if not isinstance(horizons, list) or not horizons:
        raise Elastic33Error("horizons must be non-empty array")
    horizon_count = _exact_int(profile["horizon_count"], "horizon_count")
    if horizon_count != len(horizons):
        raise Elastic33Error("horizon_count mismatch")

    output_rows: list[str] = []
    previous_bottom: float | None = None

    for index, horizon in enumerate(horizons, start=1):
        if not isinstance(horizon, dict) or set(horizon) != HORIZON_KEYS:
            raise Elastic33Error(f"layer {index} schema keys differ from ELASTIC24 v1")

        layer = _exact_int(horizon["layernumber"], f"layer {index} layernumber")
        if layer != index:
            raise Elastic33Error(f"layer sequence invalid at {index}")

        top = _finite_float(horizon["top_depth_m"], f"layer {index} top_depth_m")
        bottom = _finite_float(horizon["bottom_depth_m"], f"layer {index} bottom_depth_m")
        if top < 0.0 or bottom <= top:
            raise Elastic33Error(f"layer {index} invalid geometry")
        if index == 1:
            if abs(top) > TOL_M:
                raise Elastic33Error("first horizon does not begin at soil surface")
        elif previous_bottom is None or abs(top - previous_bottom) > TOL_M:
            raise Elastic33Error(f"gap/overlap before layer {index}")
        previous_bottom = bottom

        block = _exact_int(horizon["staringseriesblock"], f"layer {index} staringseriesblock")
        density = _finite_float(horizon["dry_density_g_cm3"], f"layer {index} dry_density_g_cm3")
        if density <= 0.0:
            raise Elastic33Error(f"layer {index} dry density must be positive")

        organic = horizon["organic_matter_pct"]
        if organic is None:
            organic_available = 0
            organic_value = 0.0
        else:
            organic_available = 1
            organic_value = _finite_float(organic, f"layer {index} organic_matter_pct")
            if organic_value < 0.0 or organic_value > 100.0:
                raise Elastic33Error(f"layer {index} organic matter outside [0,100]")

        peat = horizon["peat_type"]
        if peat is not None and not isinstance(peat, str):
            raise Elastic33Error(f"layer {index} peat_type must be string or null")
        peat_present = 0 if peat is None else 1

        output_rows.append("|".join((
            str(profile_id),
            str(layer),
            _f64(top),
            _f64(bottom),
            str(block),
            _f64(density),
            str(organic_available),
            _f64(organic_value),
            str(peat_present),
        )))

    header = [
        OUTPUT_MAGIC,
        f"source_artifact_sha256={SOURCE_ARTIFACT_SHA256}",
        f"normalsoilprofile_id={profile_id}",
        f"row_count={len(output_rows)}",
        "columns=" + "|".join(COLUMNS),
    ]
    return "\n".join(header + output_rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    try:
        text = materialize_interchange(load_profile(Path(args.input)))
    except Elastic33Error as exc:
        raise SystemExit(f"F_PE_ELASTIC33_FAIL {exc}") from exc

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")
    print("F_PE_ELASTIC33=PASS")


if __name__ == "__main__":
    main()
