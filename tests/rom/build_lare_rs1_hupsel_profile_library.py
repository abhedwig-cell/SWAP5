#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import pathlib
from collections import defaultdict


def as_float(value: str) -> float | None:
    text = value.strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def load_candidates(path: pathlib.Path) -> list[dict[str, object]]:
    payload = json.loads(path.read_text())
    candidates = list(payload["candidates"]) + list(payload.get("noneligible_representation_controls", []))
    for candidate in candidates:
        boundaries = [float(v) for v in candidate["boundaries_cm"]]
        if boundaries[0] != 0.0 or boundaries[-1] != 200.0:
            raise SystemExit(f"{candidate['id']} does not cover 0-200 cm")
        if any(b <= a for a, b in zip(boundaries, boundaries[1:])):
            raise SystemExit(f"{candidate['id']} boundaries are not strictly increasing")
    return candidates


def parse_vap(path: pathlib.Path) -> dict[str, list[dict[str, float]]]:
    profiles: dict[str, list[dict[str, float]]] = defaultdict(list)
    with path.open(newline="", errors="replace") as handle:
        for raw in csv.reader(handle):
            if len(raw) < 16:
                continue
            timestamp = raw[0].strip()
            depth = as_float(raw[1])
            theta = as_float(raw[2])
            phead = as_float(raw[3])
            conductivity = as_float(raw[4])
            drainage = as_float(raw[5])
            rootext = as_float(raw[6])
            waterflux = as_float(raw[7])
            top = as_float(raw[12])
            bottom = as_float(raw[13])
            day = as_float(raw[14])
            dcum = as_float(raw[15])
            if not timestamp or depth is None or theta is None or top is None or bottom is None:
                continue
            if not math.isfinite(theta):
                raise SystemExit(f"non-finite theta in {timestamp}")
            a = min(abs(top), abs(bottom))
            b = max(abs(top), abs(bottom))
            if b <= a:
                raise SystemExit(f"invalid compartment bounds in {timestamp}: {top}, {bottom}")
            profiles[timestamp].append({
                "depth_cm": abs(depth),
                "top_cm": a,
                "bottom_cm": b,
                "theta": theta,
                "phead_cm": phead if phead is not None else math.nan,
                "conductivity_cm_per_day": conductivity if conductivity is not None else math.nan,
                "drainage_cm_per_day": drainage if drainage is not None else math.nan,
                "root_extraction_cm_per_day": rootext if rootext is not None else math.nan,
                "water_flux_cm_per_day": waterflux if waterflux is not None else math.nan,
                "day": int(day) if day is not None else -1,
                "dcum": int(dcum) if dcum is not None else -1,
            })
    if not profiles:
        raise SystemExit(f"no profile rows parsed from {path}")
    return profiles


def overlap(a0: float, a1: float, b0: float, b1: float) -> float:
    return max(0.0, min(a1, b1) - max(a0, b0))


def project(profile: list[dict[str, float]], boundaries: list[float]) -> tuple[list[float], float]:
    sorted_profile = sorted(profile, key=lambda row: row["top_cm"])
    full_storage = sum(
        row["theta"] * (row["bottom_cm"] - row["top_cm"])
        for row in sorted_profile
    )
    storages: list[float] = []
    for lo, hi in zip(boundaries, boundaries[1:]):
        storage = 0.0
        covered = 0.0
        for row in sorted_profile:
            width = overlap(lo, hi, row["top_cm"], row["bottom_cm"])
            if width > 0.0:
                storage += row["theta"] * width
                covered += width
        if abs(covered - (hi - lo)) > 1.0e-9:
            raise SystemExit(
                f"candidate layer {lo}-{hi} cm coverage is {covered} cm instead of {hi-lo} cm"
            )
        storages.append(storage)
    if abs(sum(storages) - full_storage) > 1.0e-10:
        raise SystemExit(
            f"projection is not storage conservative: candidate={sum(storages)} full={full_storage}"
        )
    return storages, full_storage


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vap", required=True, type=pathlib.Path)
    parser.add_argument("--candidates", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()

    candidates = load_candidates(args.candidates)
    profiles = parse_vap(args.vap)

    rows = []
    node_counts = set()
    max_storage_closure = 0.0
    for timestamp in sorted(profiles):
        profile = profiles[timestamp]
        node_counts.add(len(profile))
        candidate_rows = {}
        reference_storage = None
        for candidate in candidates:
            boundaries = [float(v) for v in candidate["boundaries_cm"]]
            storages, full_storage = project(profile, boundaries)
            if reference_storage is None:
                reference_storage = full_storage
            max_storage_closure = max(
                max_storage_closure, abs(sum(storages) - full_storage)
            )
            candidate_rows[str(candidate["id"])] = {
                "boundaries_cm": boundaries,
                "storage_cm": storages,
                "theta_mean": [
                    storage / (hi - lo)
                    for storage, lo, hi in zip(storages, boundaries, boundaries[1:])
                ],
            }

        first = profile[0]
        rows.append({
            "timestamp": timestamp,
            "day": first["day"],
            "dcum": first["dcum"],
            "full_profile_storage_cm": reference_storage,
            "full_profile_node_count": len(profile),
            "candidates": candidate_rows,
        })

    result = {
        "schema": "swap5.lare.rs1.hupsel-profile-library.v1",
        "source": {
            "vap_path": str(args.vap),
            "vap_sha256": hashlib.sha256(args.vap.read_bytes()).hexdigest(),
            "candidate_path": str(args.candidates),
            "candidate_sha256": hashlib.sha256(args.candidates.read_bytes()).hexdigest(),
        },
        "profile_count": len(rows),
        "node_counts": sorted(node_counts),
        "maximum_abs_projection_storage_closure_cm": max_storage_closure,
        "projection_mass_gate_cm": 1.0e-10,
        "profiles": rows,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "profile_count": result["profile_count"],
        "node_counts": result["node_counts"],
        "maximum_abs_projection_storage_closure_cm": max_storage_closure,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
