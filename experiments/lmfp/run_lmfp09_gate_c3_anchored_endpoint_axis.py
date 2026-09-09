from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c_corrected_interface as gatec
import run_lmfp09_homogeneous_face_matrix as core

BASE_N = 33
DECADE_HEAD_KNOTS = (
    -1.0e6, -1.0e5, -1.0e4, -1.0e3, -1.0e2, -1.0e1, -1.0,
    -1.0e-1, -1.0e-2, -1.0e-3,
    0.0,
    1.0e-3, 1.0e-2, 1.0e-1, 1.0, 1.0e1, 1.0e2,
)
ACTIVE_MATERIALS = ("reference_sand", "very_fast")


def tolerant_bracket(axis, x):
    lo = axis[0]
    hi = axis[-1]
    lo_tol = 8.0 * math.ulp(max(1.0, abs(lo)))
    hi_tol = 8.0 * math.ulp(max(1.0, abs(hi)))
    if x < lo:
        if lo - x <= lo_tol:
            x = lo
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    if x > hi:
        if x - hi <= hi_tol:
            x = hi
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    if x >= hi:
        return len(axis) - 2, len(axis) - 1
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


class AnchoredEndpointPairRatioView(ep.EndpointPairRatioView):
    def __init__(self, fixture, length):
        self.fixture = fixture
        self.mat = fixture.material
        self.length = float(length)
        mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
        self.mfp = ep.HermiteMFPTable(self.mat, mfp_coord, core.MFP_N)
        self.coordinate = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
        base = [
            self.coordinate.xmin
            + (self.coordinate.xmax - self.coordinate.xmin) * i / (BASE_N - 1)
            for i in range(BASE_N)
        ]
        anchors = [
            self.coordinate.x(h)
            for h in DECADE_HEAD_KNOTS
            if core.R_HMIN <= h <= core.R_HMAX
        ]
        self.x_axis = sorted(set(base + anchors))
        self.h_axis = [0.0 if x == 0.0 else self.coordinate.h(x) for x in self.x_axis]
        self.nx = len(self.x_axis)
        self.values = []
        self.oracle_solves = 0
        for h_u in self.h_axis:
            row = []
            for h_l in self.h_axis:
                g = (h_l - h_u) / self.length
                kd, calls = core.oracle_kdar(self.mat, h_u, g, self.length)
                self.oracle_solves += calls
                kb = self.mfp.secant_k(h_u, h_l)
                if not (math.isfinite(kd) and kd > 0.0 and math.isfinite(kb) and kb > 0.0):
                    raise RuntimeError(("nonpositive_endpoint_pair_conductivity", h_u, h_l, kd, kb))
                ratio = kd / kb
                if not (math.isfinite(ratio) and ratio > 0.0):
                    raise RuntimeError(("nonpositive_endpoint_pair_ratio", h_u, h_l, ratio))
                row.append(math.log(ratio))
            self.values.append(row)


def build_provider(fixture, length):
    view = AnchoredEndpointPairRatioView(fixture, length)
    return view, view.oracle_solves, 0


def compact(row):
    face = row["face_matrix"]
    return {
        "material": row["material"],
        "length_cm": row["length_cm"],
        "pass": row["pass"],
        "axis_nodes": row["memory"]["values"] ** 0.5,
        "bytes_before_metadata": row["memory"]["bytes_before_metadata"],
        "identity_pass": row["identity"]["pass"],
        "continuity_pass": row["continuity"]["pass"],
        "fail_closed_pass": row["fail_closed"]["pass"],
        "face_matrix_pass": face["pass"],
        "face_matrix": {k: v for k, v in face.items() if k != "rows"},
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_gate_c3_anchored_endpoint_axis.py EVIDENCE_JSON")
    out = Path(sys.argv[1])
    ep.bracket = tolerant_bracket
    fixtures_all, _ = gatec.material_group("synthetic")
    fixtures = {name: fixtures_all[name] for name in ACTIVE_MATERIALS}
    providers = {}
    preparation = []
    total_bytes = 0
    total_oracle = 0

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C3_ANCHORED_ENDPOINT_AXIS_CHARACTERIZATION",
        "candidate": "BASE33_PLUS_SIGNED_PRESSURE_HEAD_DECADES",
        "base_coordinate": "asinh(h/0.01cm)",
        "base_nodes": BASE_N,
        "extra_head_knots_cm": list(DECADE_HEAD_KNOTS),
        "material_specific_knots": False,
        "pair_specific_knots": False,
        "thresholds_changed_from_C2": False,
        "extreme_tail_probes_retained": True,
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    for name, fixture in fixtures.items():
        for length in gatec.HALF_LENGTHS:
            view, calls, _ = build_provider(fixture, length)
            providers[(name, length)] = view
            memory = view.memory()["bytes_before_metadata"]
            total_bytes += memory
            total_oracle += calls
            preparation.append({
                "material": name,
                "half_face_length_cm": length,
                "axis_nodes": view.nx,
                "table_values": view.memory()["values"],
                "bytes_before_metadata": memory,
                "offline_oracle_solves": calls,
            })
            evidence["preparation"] = preparation
            evidence["total_shared_bytes_for_characterized_classes"] = total_bytes
            evidence["total_offline_oracle_solves"] = total_oracle
            out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    evidence["stage"] = "PROVIDER_SELF_CHECK"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    check = ep.provider_self_check(fixtures, providers)
    evidence["provider_self_check"] = check
    evidence["summary"] = [compact(row) for row in check["rows"]]
    evidence["status"] = "COMPLETED"
    evidence["stage"] = "COMPLETE"
    evidence["decision"] = (
        "C3_ANCHORED_PROVIDER_CHARACTERIZATION_PASSED_PROCEED_FULL_SYNTHETIC_MATRIX"
        if check["pass"]
        else "C3_ANCHORED_PROVIDER_CHARACTERIZATION_FAILED_DO_NOT_PROCEED_FULL_MATRIX"
    )
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": evidence["decision"],
        "total_shared_bytes_for_characterized_classes": total_bytes,
        "total_offline_oracle_solves": total_oracle,
        "summary": evidence["summary"],
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if check["pass"] else 1)


if __name__ == "__main__":
    main()
