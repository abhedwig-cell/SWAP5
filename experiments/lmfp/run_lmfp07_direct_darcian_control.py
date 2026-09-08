from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp04_ab import DZ, case_definition
from run_lmfp07_transient_abc import integrate_candidate


def metrics(candidate, direct):
    return {
        "theta_max_abs": max(abs(a-b) for a,b in zip(candidate["theta"], direct["theta"])),
        "head_max_abs_cm": max(abs(a-b) for a,b in zip(candidate["h"], direct["h"])),
        "storage_abs_cm": abs(candidate["final_storage"]-direct["final_storage"]),
        "bottom_flux_abs_cm_d": abs(candidate["bottom_down"]-direct["bottom_down"]),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp07_direct_darcian_control.py ABC_EVIDENCE OUTPUT_JSON")
    base = json.loads(Path(sys.argv[1]).read_text())
    out = {
        "schema_version": 1,
        "work_unit": "F-LMFP07",
        "control": "DIRECT_STEADY_DARCIAN_FACE_CLOSURE_INSIDE_TRANSIENT_EXPLICIT_COLUMN",
        "interpretation": "This isolates face-closure interpolation/model error. It is not a replacement for transient FullRichards as scientific reference.",
        "cases": {},
    }
    lookup_better = 0
    mfp_better = 0
    ties = 0
    all_accepted = True
    max_mass = 0.0

    for cid in range(1, 7):
        name, codes, heads0, duration, base_dt, top = case_definition(cid)
        refinement = 2
        dt = base_dt/refinement
        direct = integrate_candidate(codes, heads0, DZ, duration, dt, top, "oracle")
        all_accepted = all_accepted and direct["accepted"]
        if direct["accepted"]:
            max_mass = max(max_mass, direct["mass_max"])
        stored = base["cases"][name]["refinements"][str(refinement)]
        mfp = stored["mfp"]
        lookup = stored["darcian_lookup"]
        m = metrics(mfp, direct) if direct["accepted"] and mfp["accepted"] else None
        d = metrics(lookup, direct) if direct["accepted"] and lookup["accepted"] else None
        if m and d:
            if d["theta_max_abs"] < m["theta_max_abs"]:
                lookup_better += 1
            elif m["theta_max_abs"] < d["theta_max_abs"]:
                mfp_better += 1
            else:
                ties += 1
        out["cases"][name] = {
            "direct_darcian": direct,
            "mfp_vs_direct_darcian": m,
            "lookup16_vs_direct_darcian": d,
            "fullrichards_vs_direct_darcian": {
                "theta_max_abs": max(abs(stored["fullrichards"]["nodes"][str(i+1)]["theta"]-direct["theta"][i])
                                     if isinstance(next(iter(stored["fullrichards"]["nodes"].keys())), str)
                                     else abs(stored["fullrichards"]["nodes"][i+1]["theta"]-direct["theta"][i])
                                     for i in range(len(codes)))
            } if direct["accepted"] else None,
        }

    out["summary"] = {
        "all_direct_darcian_steps_accepted": all_accepted,
        "max_direct_darcian_mass_residual": max_mass,
        "lookup16_theta_closer_than_mfp_count": lookup_better,
        "mfp_theta_closer_than_lookup16_count": mfp_better,
        "ties": ties,
        "compared": lookup_better+mfp_better+ties,
    }
    out["structural_pass"] = all_accepted and max_mass < 2.0e-10
    Path(sys.argv[2]).write_text(json.dumps(out, indent=2, sort_keys=True)+"\n")
    print(json.dumps(out, indent=2, sort_keys=True))
    raise SystemExit(0 if out["structural_pass"] else 1)


if __name__ == "__main__":
    main()
