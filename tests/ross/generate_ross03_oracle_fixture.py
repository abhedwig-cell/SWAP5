from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np


def load_research_modules(research_root: Path):
    exp = research_root / "experiments" / "ross"
    sys.path.insert(0, str(exp))
    import run_ross01_gate_d_conservative_physical_unsaturated_column as gate_d
    import run_ross01_gate_f_timestep_convergence as gate_f
    import run_ross01_gate_j1a_real_table_face_derivative as j1a
    import ross01_d3r_fsi31_duration_adapter as d3r
    return gate_d, gate_f, j1a, d3r


def run_window(gate_f, theta0, table, ext, duration: float, steps: int = 8):
    theta = tuple(float(v) for v in theta0)
    dt = duration / steps
    max_mass = 0.0
    for _ in range(steps):
        result = gate_f.candidate_step(theta, table, ext, dt)
        if not result["domain_ok"] or not result["envelope_ok"] or result["nonfinite_count"]:
            raise RuntimeError(("research candidate invalid", duration, result))
        max_mass = max(max_mass, float(result["abs_global_mass_residual_cm"]))
        theta = tuple(float(v) for v in result["theta"])
    return theta, tuple(float(v) for v in gate_f.heads_from_theta(theta)), max_mass


def write_vector(f, values):
    f.write(" ".join(f"{float(v):.17e}" for v in values) + "\n")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--research-root", type=Path, required=True)
    p.add_argument("--material", required=True)
    p.add_argument("--table-out", type=Path, required=True)
    p.add_argument("--fixture-out", type=Path, required=True)
    p.add_argument("--metadata-out", type=Path, required=True)
    a = p.parse_args()

    gate_d, gate_f, j1a, d3r = load_research_modules(a.research_root)
    catalog = json.loads(
        (a.research_root / "integration" / "f-ross" / "F-ROSS01_GATE_C1_MATERIAL_CATALOG.json").read_text()
    )
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if a.material not in d3r.MATERIAL_IDS or a.material not in by_name:
        raise SystemExit(f"material outside frozen D3R set: {a.material}")
    row = by_name[a.material]

    j1a.c1r.base.c1.configure_core(row)
    table, preprocessing_seconds, failures = j1a.c1r.base.generate_table(j1a.N)
    if failures:
        raise RuntimeError(("research table generation failures", failures[:8]))
    if table.shape != (241, 241) or table.dtype != np.float32:
        raise RuntimeError(("unexpected research table representation", table.shape, table.dtype))

    heads0 = tuple(float(v) for v in gate_d.build_profile(16, -180.0, -650.0))
    theta0 = tuple(float(gate_d.theta_from_head(h)) for h in heads0)
    ext = gate_f.fixed_external(heads0, "zero")
    q_top = float(ext["q_top"])
    q_bottom_up = -float(ext["q_bottom"])
    span = float(row["theta_s"] - row["theta_r"])

    cases = []
    max_component_mass = 0.0
    for attempt in range(d3r.CANONICAL_MAX_RETRIES + 1):
        duration = float(d3r.DURATION_LADDER_DAY[attempt])
        coarse_theta, coarse_heads, mass_full = run_window(gate_f, theta0, table, ext, duration)
        half_theta, _, mass_half1 = run_window(gate_f, theta0, table, ext, 0.5 * duration)
        refined_theta, refined_heads, mass_half2 = run_window(
            gate_f, half_theta, table, ext, 0.5 * duration
        )
        raw = max(abs(a0 - b0) for a0, b0 in zip(refined_theta, coarse_theta)) / span
        bound = max(raw, 1.0e-10)
        indicator = bound / 1.0e-5
        if not math.isfinite(indicator) or indicator < 0.0:
            raise RuntimeError(("invalid research indicator", attempt, indicator))
        max_component_mass = max(max_component_mass, mass_full, mass_half1, mass_half2)
        cases.append(
            {
                "attempt": attempt,
                "duration": duration,
                "q_top": q_top,
                "q_bottom_up": q_bottom_up,
                "initial_heads": heads0,
                "initial_theta": theta0,
                "coarse_heads": coarse_heads,
                "coarse_theta": coarse_theta,
                "refined_heads": refined_heads,
                "refined_theta": refined_theta,
                "raw_estimator": raw,
                "indicator": indicator,
            }
        )

    # Write the float32 table in Fortran column-major traversal. Nine decimal
    # significant digits are sufficient for lossless float32 round-tripping.
    np.savetxt(a.table_out, table.flatten(order="F"), fmt="%.9e")
    with a.fixture_out.open("w", encoding="utf-8") as f:
        f.write(f"{len(cases)}\n")
        for case in cases:
            f.write(
                f"{case['attempt']} {case['duration']:.17e} {case['q_top']:.17e} "
                f"{case['q_bottom_up']:.17e} {case['raw_estimator']:.17e} "
                f"{case['indicator']:.17e}\n"
            )
            write_vector(f, case["initial_heads"])
            write_vector(f, case["initial_theta"])
            write_vector(f, case["coarse_heads"])
            write_vector(f, case["coarse_theta"])
            write_vector(f, case["refined_heads"])
            write_vector(f, case["refined_theta"])

    metadata = {
        "schema_version": 1,
        "work_unit": "F-ROSS03",
        "kind": "PINNED_F_ROSS01_RESEARCH_ORACLE_FIXTURE",
        "material": a.material,
        "research_head": "04807fdcf45453a59b7f6c99fe97f1286c172833",
        "table_shape": list(table.shape),
        "table_dtype": str(table.dtype),
        "table_raw_c_order_sha256": hashlib.sha256(table.tobytes(order="C")).hexdigest(),
        "table_fixture_sha256": hashlib.sha256(a.table_out.read_bytes()).hexdigest(),
        "fixture_sha256": hashlib.sha256(a.fixture_out.read_bytes()).hexdigest(),
        "case_count": len(cases),
        "attempt_indices": [c["attempt"] for c in cases],
        "max_component_mass_residual_cm": max_component_mass,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "oracle_semantics": "Gate F candidate_step plus D3G02R refined-two-half certificate",
    }
    a.metadata_out.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    print(json.dumps(metadata, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
