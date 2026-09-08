from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp02_testbench import B110Material
from run_lmfp03_column import ExtendedMFPTable, advance_trial

DZ = [10.0, 10.0, 20.0, 20.0]


def material(code: int) -> B110Material:
    vals = [0.0] * 24
    if code == 1:
        tr, ts, ks, alpha, lamb, nn = 0.045, 0.430, 20.0, 0.040, 0.50, 1.80
    elif code == 2:
        tr, ts, ks, alpha, lamb, nn = 0.080, 0.500, 0.20, 0.010, 0.50, 1.30
    else:
        raise ValueError(code)
    mm = 1.0 - 1.0 / nn
    vals[0] = tr
    vals[1] = ts
    vals[2] = ks
    vals[3] = alpha
    vals[4] = lamb
    vals[5] = nn
    vals[6] = mm
    vals[7] = alpha
    vals[8] = 0.0
    vals[9] = ks
    vals[10] = 0.999
    vals[11] = 0.99 * ks
    vals[21] = -1.0e6
    vals[22] = 1.0e-12
    return B110Material.from_input(vals)


SAND = material(1)
CLAY = material(2)
TABLES = {
    1: ExtendedMFPTable(SAND, n=1025, pf_max=8.0, pf_min=-4.0),
    2: ExtendedMFPTable(CLAY, n=1025, pf_max=8.0, pf_min=-4.0),
}


def case_definition(case_id: int):
    if case_id == 1:
        return "steady_sand", [1, 1, 1, 1], [-100.0] * 4, 0.20, 0.02, SAND.conductivity(-100.0)
    if case_id == 2:
        return "redistribution_sand", [1, 1, 1, 1], [-200.0, -120.0, -60.0, -30.0], 0.20, 0.005, 0.0
    if case_id == 3:
        return "infiltration_sand", [1, 1, 1, 1], [-200.0] * 4, 0.20, 0.005, 0.10
    if case_id == 4:
        return "infiltration_clay", [2, 2, 2, 2], [-200.0] * 4, 0.50, 0.01, 0.01
    if case_id == 5:
        return "sand_over_clay", [1, 1, 2, 2], [-150.0, -100.0, -70.0, -50.0], 0.20, 0.005, 0.0
    if case_id == 6:
        return "clay_over_sand", [2, 2, 1, 1], [-150.0, -100.0, -70.0, -50.0], 0.20, 0.005, 0.0
    raise ValueError(case_id)


def parse_reference(path: Path):
    data = {}
    for raw in path.read_text().splitlines():
        parts = raw.split()
        if not parts:
            continue
        if parts[0] == "SUMMARY":
            cid, ref = int(parts[1]), int(parts[2])
            data.setdefault((cid, ref), {})["summary"] = {
                "name": parts[3],
                "dt": float(parts[4]),
                "nsteps": int(parts[5]),
                "top_down": float(parts[6]),
                "bottom_down": float(parts[7]),
                "initial_storage": float(parts[8]),
                "final_storage": float(parts[9]),
                "nonlinear_iterations_total": int(parts[10]),
                "nonlinear_iterations_max": int(parts[11]),
            }
        elif parts[0] == "MASS":
            cid, ref = int(parts[1]), int(parts[2])
            data.setdefault((cid, ref), {})["mass_max"] = float(parts[3])
        elif parts[0] == "NODE":
            cid, ref, node = int(parts[1]), int(parts[2]), int(parts[3])
            d = data.setdefault((cid, ref), {})
            d.setdefault("nodes", {})[node] = {"h": float(parts[4]), "theta": float(parts[5])}
    return data


def run_candidate(case_id: int, refinement: int):
    name, codes, heads0, duration, base_dt, top_down = case_definition(case_id)
    mats = [SAND if c == 1 else CLAY for c in codes]
    tabs = [TABLES[c] for c in codes]
    storage = [m.theta(h) * dz for m, h, dz in zip(mats, heads0, DZ)]
    initial_storage = sum(storage)
    dt = base_dt / refinement
    nsteps = round(duration / dt)
    max_mass = 0.0
    max_face_iterations = 0
    retries = 0
    final_trial = None
    for _ in range(nsteps):
        trial = advance_trial(storage, mats, tabs, DZ, dt, top_down)
        if not trial.accepted:
            retries += 1
            return {
                "accepted": False,
                "reason": trial.reason,
                "advised_step_duration": trial.advised_step_duration,
                "retries": retries,
                "dt": dt,
                "nsteps": nsteps,
            }
        storage = trial.candidate_storage
        final_trial = trial
        max_mass = max(max_mass, abs(trial.mass_residual))
        max_face_iterations = max(max_face_iterations, trial.max_face_iterations)
    theta = [w / dz for w, dz in zip(storage, DZ)]
    h = [m.head_from_theta(t) for m, t in zip(mats, theta)]
    return {
        "accepted": True,
        "name": name,
        "dt": dt,
        "nsteps": nsteps,
        "top_down": top_down,
        "bottom_down": final_trial.face_flux[-1] if final_trial else mats[-1].conductivity(heads0[-1]),
        "initial_storage": initial_storage,
        "final_storage": sum(storage),
        "mass_max": max_mass,
        "max_face_iterations": max_face_iterations,
        "retries": retries,
        "theta": theta,
        "h": h,
    }


def rms(values):
    return math.sqrt(sum(v * v for v in values) / len(values))


def compare(ref, cand, case_id):
    rtheta = [ref["nodes"][i]["theta"] for i in range(1, 5)]
    rh = [ref["nodes"][i]["h"] for i in range(1, 5)]
    dtheta = [a - b for a, b in zip(cand["theta"], rtheta)]
    dh = [a - b for a, b in zip(cand["h"], rh)]
    pf_delta = []
    for a, b in zip(cand["h"], rh):
        if a < 0.0 and b < 0.0:
            pf_delta.append(math.log10(-a) - math.log10(-b))
        else:
            pf_delta.append(float("nan"))
    denom = max(abs(ref["summary"]["bottom_down"]), 1.0e-12)

    _, codes, heads0, _, _, _ = case_definition(case_id)
    mats = [SAND if c == 1 else CLAY for c in codes]
    theta0 = [m.theta(h) for m, h in zip(mats, heads0)]
    sign_matches = 0
    sign_compared = 0
    for t0, tr, tc in zip(theta0, rtheta, cand["theta"]):
        ar = tr - t0
        ac = tc - t0
        if max(abs(ar), abs(ac)) > 1.0e-9:
            sign_compared += 1
            if ar == 0.0 or ac == 0.0 or ar * ac > 0.0:
                sign_matches += 1

    return {
        "theta_max_abs": max(abs(x) for x in dtheta),
        "theta_rmse": rms(dtheta),
        "head_max_abs_cm": max(abs(x) for x in dh),
        "head_rmse_cm": rms(dh),
        "pf_max_abs": max(abs(x) for x in pf_delta if math.isfinite(x)),
        "storage_abs_cm": abs(cand["final_storage"] - ref["summary"]["final_storage"]),
        "bottom_flux_abs_cm_d": abs(cand["bottom_down"] - ref["summary"]["bottom_down"]),
        "bottom_flux_rel": abs(cand["bottom_down"] - ref["summary"]["bottom_down"]) / denom,
        "direction_matches": sign_matches,
        "direction_compared": sign_compared,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp04_ab.py REFERENCE_OUTPUT EVIDENCE_JSON")
    ref = parse_reference(Path(sys.argv[1]))
    evidence = {"schema_version": 1, "cases": {}, "tests": {}}
    structural_ok = True
    for case_id in range(1, 7):
        name = case_definition(case_id)[0]
        case_ev = {"refinements": {}}
        for refinement in (1, 2):
            key = (case_id, refinement)
            if key not in ref or "summary" not in ref[key] or len(ref[key].get("nodes", {})) != 4:
                raise SystemExit(f"missing FullRichards output for {key}")
            cand = run_candidate(case_id, refinement)
            if not cand["accepted"]:
                structural_ok = False
                case_ev["refinements"][str(refinement)] = {"candidate": cand}
                continue
            metrics = compare(ref[key], cand, case_id)
            case_ev["refinements"][str(refinement)] = {
                "fullrichards": ref[key],
                "layeredmfp": cand,
                "cross_model": metrics,
            }
            if ref[key].get("mass_max", math.inf) > 2.0e-8:
                structural_ok = False
            if cand["mass_max"] > 2.0e-10:
                structural_ok = False
        evidence["cases"][name] = case_ev

    steady = evidence["cases"]["steady_sand"]["refinements"]["2"]["cross_model"]
    steady_ok = steady["theta_max_abs"] < 1.0e-9 and steady["bottom_flux_rel"] < 2.0e-8
    structural_ok = structural_ok and steady_ok
    evidence["tests"]["fullrichards_mass_closure"] = {
        "pass": all(ref[(c, r)].get("mass_max", math.inf) <= 2.0e-8 for c in range(1, 7) for r in (1, 2)),
        "threshold": 2.0e-8,
    }
    evidence["tests"]["layeredmfp_mass_closure"] = {
        "pass": all(evidence["cases"][case_definition(c)[0]]["refinements"][str(r)].get("layeredmfp", {}).get("mass_max", math.inf) <= 2.0e-10
                    for c in range(1, 7) for r in (1, 2)),
        "threshold": 2.0e-10,
    }
    evidence["tests"]["steady_uniform_cross_model_identity"] = {
        "pass": steady_ok,
        "theta_max_abs": steady["theta_max_abs"],
        "bottom_flux_rel": steady["bottom_flux_rel"],
    }
    evidence["tests"]["all_candidate_steps_accepted"] = {
        "pass": all(evidence["cases"][case_definition(c)[0]]["refinements"][str(r)].get("layeredmfp", {}).get("accepted", False)
                    for c in range(1, 7) for r in (1, 2))
    }
    evidence["structural_pass"] = structural_ok
    evidence["interpretation"] = {
        "physical_similarity_thresholds": "not predeclared; dynamic cross-model errors are evidence for defining the next qualification envelope, not silently converted into admission criteria",
        "flux_sign": "evidence stores downward-positive flux; SWAP5 FullRichards output is sign-converted from its upward-positive q convention",
        "scope": "hydraulic-only, explicit top flux, free drainage bottom, no crop/drainage/ponding/groundwater"
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if structural_ok else 1)


if __name__ == "__main__":
    main()
