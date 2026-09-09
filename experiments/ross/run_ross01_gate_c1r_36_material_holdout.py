from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from scipy.stats import qmc

import run_ross01_gate_c1r_characterization_v4 as v4

N = 241
LENGTH_CM = 10.0
H_MIN = -10000.0
H_MAX = -1.0
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")


def seed_for(prefix: str, name: str) -> int:
    return int(hashlib.sha256((prefix + name).encode()).hexdigest()[:8], 16)


def state_seed(name: str) -> int:
    return seed_for("F-ROSS01-C1R-HOLDOUT-S:", name)


def coordinate_seed(name: str) -> int:
    return seed_for("F-ROSS01-C1R-HOLDOUT-U:", name)


def state_pair_from_heads(h_above: float, h_below: float):
    return float(v4.base.c1.core.s_of_h(h_above)), float(v4.base.c1.core.s_of_h(h_below))


def build_holdout_probes(name: str):
    s_min = v4.base.c1.core.S_MIN
    s_max = v4.base.c1.core.S_MAX
    probes = []

    ordinary_s = qmc.Sobol(d=2, scramble=True, seed=state_seed(name)).random_base2(m=9)
    for a, b in ordinary_s:
        sa = s_min + (s_max - s_min) * float(a)
        sb = s_min + (s_max - s_min) * float(b)
        probes.append((float(sa), float(sb), "holdout_state_space"))

    ordinary_u = qmc.Sobol(d=2, scramble=True, seed=coordinate_seed(name)).random_base2(m=9)
    for a, b in ordinary_u:
        ua = 4.0 * float(a)
        ub = 4.0 * float(b)
        ha = -(10.0 ** ua)
        hb = -(10.0 ** ub)
        probes.append((*state_pair_from_heads(ha, hb), "holdout_coordinate_space"))

    for u in np.linspace(0.0, 4.0, 96):
        h = -(10.0 ** float(u))
        probes.append((*state_pair_from_heads(h, h), "equal_head"))

    for h_above in -np.geomspace(11.0, 10000.0, 96):
        h_below = float(h_above) + LENGTH_CM
        probes.append((*state_pair_from_heads(float(h_above), h_below), "hydrostatic"))

    for h_above in -np.geomspace(21.0, 10000.0, 64):
        for epsilon in (-0.25, 0.25):
            h_below = float(h_above) + LENGTH_CM + epsilon
            probes.append((*state_pair_from_heads(float(h_above), h_below), "near_hydrostatic"))

    fractions = (0.005, 0.02, 0.1, 0.5, 0.9, 0.98, 0.995)
    for a in fractions:
        for b in fractions:
            sa = s_min + (s_max - s_min) * a
            sb = s_min + (s_max - s_min) * b
            probes.append((float(sa), float(sb), "wet_dry_cross"))

    for ha, hb in (
        (H_MIN, H_MIN),
        (H_MAX, H_MAX),
        (H_MIN, H_MAX),
        (H_MAX, H_MIN),
        (H_MIN, H_MIN + LENGTH_CM),
        (H_MAX - LENGTH_CM, H_MAX),
        (-100.0, -90.0),
        (-100.0, -91.0),
    ):
        probes.append((*state_pair_from_heads(ha, hb), "edge"))

    if len(probes) != 1401:
        raise RuntimeError(f"frozen holdout probe count mismatch: {len(probes)}")
    return probes


v4.base.build_probes = build_holdout_probes
v4.base.seed_for_material = state_seed


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c1r_36_material_holdout.py OUTPUT_DIR MATERIAL1,MATERIAL2,...")
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    requested = [x.strip() for x in sys.argv[2].split(",") if x.strip()]

    catalog = json.loads(CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    unknown = [name for name in requested if name not in by_name]
    if unknown:
        raise SystemExit(f"unknown materials: {unknown}")

    results = []
    for index, name in enumerate(requested, 1):
        result = v4.base.run_material(by_name[name], N)
        result["holdout_state_seed"] = state_seed(name)
        result["holdout_coordinate_seed"] = coordinate_seed(name)
        result["holdout_probe_set"] = "FRESH_C1R_36_MATERIAL_HOLDOUT"
        results.append(result)
        (out_dir / f"F-ROSS01_C1R_HOLDOUT_{name}.json").write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n"
        )
        print(json.dumps({
            "progress": f"{index}/{len(requested)}",
            "material": name,
            "pass": result["pass"],
            "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
            "max_hybrid_metric": result.get("max_hybrid_metric"),
            "failed_metrics": result.get("failed_metrics", []),
        }), flush=True)

    failed = [r for r in results if not r["pass"]]
    summary = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C1R_FRESH_36_MATERIAL_HOLDOUT",
        "candidate": {
            "N": N,
            "storage": "float32_log_mobility",
            "state_to_coordinate": "qualified_direct_S_to_u",
            "shared_table_plus_metadata_bytes": 4 * N * N + 32,
        },
        "materials": requested,
        "material_count": len(results),
        "pass_count": len(results) - len(failed),
        "fail_count": len(failed),
        "failed_materials": [r["material"] for r in failed],
        "pass": len(failed) == 0,
        "decision": "C1R_HOLDOUT_GROUP_PASS" if not failed else "C1R_HOLDOUT_GROUP_FAIL",
        "no_retuning_after_holdout_access": True,
    }
    (out_dir / "F-ROSS01_C1R_HOLDOUT_GROUP_RESULT.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n"
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    raise SystemExit(0 if summary["pass"] else 1)


if __name__ == "__main__":
    main()
