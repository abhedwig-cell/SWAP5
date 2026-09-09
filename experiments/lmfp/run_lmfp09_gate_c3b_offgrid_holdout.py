from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES

DRY_HEADS = (
    -750000.0, -316227.7660168379, -177827.94100389228,
    -56234.13251903491, -31622.776601683792, -17782.794100389227,
    -5623.413251903491, -3162.2776601683795, -1778.2794100389228,
    -562.341325190349,
)
WET_HEADS = (
    -316.22776601683796, -31.622776601683793, -3.1622776601683795,
    -0.31622776601683794, -0.03162277660168379, -0.0031622776601683794,
    0.0031622776601683794, 0.03162277660168379, 0.31622776601683794,
    3.1622776601683795, 31.622776601683793,
)
RANDOM_SEED = 531093003
RANDOM_CASES = 200


def is_anchor(h):
    return any(abs(h - a) <= 1.0e-13 * max(1.0, abs(a)) for a in c3.DECADE_HEAD_KNOTS)


def row(mat, h_u, h_l, length, kind):
    if is_anchor(h_u) or is_anchor(h_l):
        raise AssertionError(("holdout_endpoint_is_anchor", h_u, h_l))
    g = (h_l - h_u) / length
    q_ref = core.direct_flux(mat, h_u, h_l, length)
    return {
        "h_u": h_u,
        "h_l": h_l,
        "g": g,
        "q_ref": q_ref,
        "active_floor": 1.0e-8 * max(mat.conductivity(0.0), 1.0),
        "strong_gradient": abs(g) >= 5.0,
        "near_saturation": max(abs(h_u), abs(h_l)) <= 10.0,
        "holdout_kind": kind,
    }


def holdout_rows(mat, length):
    rows = [row(mat, hu, hl, length, "fixed_middecade") for hu in DRY_HEADS for hl in WET_HEADS]
    rng = random.Random(RANDOM_SEED)
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
    accepted = 0
    attempts = 0
    while accepted < RANDOM_CASES:
        attempts += 1
        if attempts > 200000:
            raise RuntimeError(("holdout_sampling_exhausted", accepted, attempts))
        hu = coord.h(rng.uniform(coord.xmin, coord.xmax))
        hl = coord.h(rng.uniform(coord.xmin, coord.xmax))
        # Freeze a genuinely off-grid dry-to-wet stress family.  These bounds are
        # algorithmic regime definitions, not material-specific tuning.
        if not (hu <= -100.0 and hl >= -10.0):
            continue
        if is_anchor(hu) or is_anchor(hl):
            continue
        rows.append(row(mat, hu, hl, length, "random_asinh_dry_to_wet"))
        accepted += 1
    return rows, attempts


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: run_lmfp09_gate_c3b_offgrid_holdout.py EVIDENCE_JSON MATERIAL HALF_FACE_LENGTH_CM")
    out = Path(sys.argv[1])
    material_name = sys.argv[2]
    length = float(sys.argv[3])
    fixtures = {f.name: f for f in FIXTURES}
    if material_name not in ("reference_sand", "very_fast"):
        raise SystemExit(("unsupported_precommitted_material", material_name))
    if length not in (5.0, 10.0):
        raise SystemExit(("unsupported_precommitted_length", length))
    fixture = fixtures[material_name]

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C3B_OFFGRID_ENDPOINT_PAIR_HOLDOUT",
        "candidate": "BASE33_PLUS_SIGNED_PRESSURE_HEAD_DECADES",
        "material": material_name,
        "half_face_length_cm": length,
        "thresholds_changed_from_C2": False,
        "candidate_changed_after_C3": False,
        "holdout_endpoints_exclude_exact_anchors": True,
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    # Freeze the exact C3 provider implementation.  Only the probe set changes.
    ep.bracket = c3.tolerant_bracket
    view, oracle_solves, _ = c3.build_provider(fixture, length)
    evidence["provider"] = {
        "axis_nodes": view.nx,
        "table_values": view.memory()["values"],
        "bytes_before_metadata": view.memory()["bytes_before_metadata"],
        "offline_oracle_solves": oracle_solves,
    }
    evidence["stage"] = "HOLDOUT_REFERENCE_GENERATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    probes, attempts = holdout_rows(fixture.material, length)
    evidence["holdout"] = {
        "fixed_cases": len(DRY_HEADS) * len(WET_HEADS),
        "random_cases": RANDOM_CASES,
        "total_cases": len(probes),
        "random_seed": RANDOM_SEED,
        "random_sampling_attempts": attempts,
    }
    evidence["stage"] = "HOLDOUT_EVALUATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    metrics = core.metrics_for_view(view, probes)
    identity = ep.provider_identity(view)
    continuity = ep.provider_continuity(view)
    fail_closed = ep.provider_fail_closed(view)
    structural_pass = metrics["pass"] and identity["pass"] and continuity["pass"] and fail_closed["pass"]

    worst = None
    for r in metrics["rows"]:
        if r.get("failed"):
            score = math.inf
        else:
            score = r.get("corrected_error", -1.0)
        if worst is None or score > worst[0]:
            worst = (score, r)

    evidence.update({
        "metrics": {k: v for k, v in metrics.items() if k != "rows"},
        "identity": identity,
        "continuity": continuity,
        "fail_closed": fail_closed,
        "worst_holdout_row": worst[1] if worst else None,
        "structural_pass": structural_pass,
        "status": "COMPLETED",
        "stage": "COMPLETE",
        "decision": (
            "C3B_OFFGRID_CLASS_PASSED"
            if structural_pass
            else "C3B_OFFGRID_CLASS_FAILED_DO_NOT_PROCEED_TO_CATALOG"
        ),
    })
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material_name,
        "half_face_length_cm": length,
        "provider": evidence["provider"],
        "holdout": evidence["holdout"],
        "metrics": evidence["metrics"],
        "worst_holdout_row": evidence["worst_holdout_row"],
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if structural_pass else 1)


if __name__ == "__main__":
    main()
