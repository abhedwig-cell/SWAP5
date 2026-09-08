from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp03_column import TrialResult, advance_trial
from run_lmfp04_ab import (
    DZ, SAND, CLAY, TABLES, case_definition, parse_reference, compare,
)
from run_lmfp06_lookup_surrogate import DarcianLookup, HEAD_AXIS


HEAD_WET = max(HEAD_AXIS)
HEAD_DRY = min(HEAD_AXIS)


def material_for(code: int):
    return SAND if code == 1 else CLAY


def lookup_key(code_u: int, code_l: int, dz_u: float, dz_l: float):
    # For homogeneous material only the total internodal distance affects the
    # local steady Darcy BVP. For heterogeneous material the two half lengths
    # are part of the immutable face class because the interface position matters.
    if code_u == code_l:
        return (code_u, code_l, 0.5 * (dz_u + dz_l), 0.0)
    return (code_u, code_l, 0.5 * dz_u, 0.5 * dz_l)


def build_lookup_pool():
    keys = set()
    for case_id in range(1, 7):
        _, codes, _, _, _, _ = case_definition(case_id)
        for i in range(3):
            keys.add(lookup_key(codes[i], codes[i + 1], DZ[i], DZ[i + 1]))

    pool = {}
    for key in sorted(keys):
        cu, cl, a, b = key
        if cu == cl:
            # DarcianLookup wants two positive segments. Splitting a homogeneous
            # face in half leaves the exact steady BVP unchanged.
            total = a
            pool[key] = DarcianLookup(cu, cl, 0.5 * total, 0.5 * total)
        else:
            pool[key] = DarcianLookup(cu, cl, a, b)
    return pool


def lookup_face_flux(pool, code_u, code_l, h_u, h_l, dz_u, dz_l):
    if not (HEAD_DRY <= h_u <= HEAD_WET and HEAD_DRY <= h_l <= HEAD_WET):
        raise ValueError(f"lookup_out_of_envelope:{h_u}:{h_l}")

    len_u = 0.5 * dz_u
    len_l = 0.5 * dz_l
    total = len_u + len_l

    # Preserve exact homogeneous identities instead of allowing table
    # interpolation noise to break q=K(h) or hydrostatic q=0.
    if code_u == code_l:
        scale = max(1.0, abs(h_u), abs(h_l), total)
        if abs(h_u - h_l) <= 1.0e-12 * scale:
            return material_for(code_u).conductivity(0.5 * (h_u + h_l)), "exact_equal_head"
        if abs((h_l - h_u) - total) <= 1.0e-12 * scale:
            return 0.0, "exact_hydrostatic"

    key = lookup_key(code_u, code_l, dz_u, dz_l)
    return pool[key].flux(h_u, h_l), "lookup"


def advance_trial_lookup(base_storage, codes, thickness, step_duration, top_flux, pool,
                         source=None, sink=None):
    """Functional transient trial with Darcian lookup faces.

    This mirrors F-LMFP03 advance_trial except for the internal face provider.
    It retains the same committed-state ownership, free-drainage bottom,
    telescoping water balance, admissibility calculation and reject-without-
    mutation semantics. No production source is used or changed.
    """
    n = len(base_storage)
    mats = [material_for(c) for c in codes]
    source = [0.0] * n if source is None else list(source)
    sink = [0.0] * n if sink is None else list(sink)

    if not (len(codes) == len(thickness) == len(source) == len(sink) == n):
        raise ValueError("column shape mismatch")
    if step_duration <= 0.0:
        raise ValueError("step_duration must be positive")

    heads = []
    for i in range(n):
        theta = base_storage[i] / thickness[i]
        if theta < mats[i].theta_r - 1.0e-10 or theta > mats[i].theta_s + 1.0e-10:
            return TrialResult(False, list(base_storage), [], [], [], 0.0, 0.0, 0,
                               "base_state_out_of_bounds"), {"lookup_faces": 0, "exact_faces": 0}
        theta_eval = min(mats[i].theta_s, max(mats[i].theta_r + 1.0e-12, theta))
        heads.append(mats[i].head_from_theta(theta_eval))

    face = [0.0] * (n + 1)
    face[0] = top_flux
    lookup_faces = 0
    exact_faces = 0
    try:
        for i in range(n - 1):
            q, route = lookup_face_flux(pool, codes[i], codes[i + 1], heads[i], heads[i + 1],
                                        thickness[i], thickness[i + 1])
            face[i + 1] = q
            if route == "lookup":
                lookup_faces += 1
            else:
                exact_faces += 1
    except ValueError as exc:
        return TrialResult(False, list(base_storage), heads, face, [], 0.0, 0.0, 0,
                           str(exc)), {"lookup_faces": lookup_faces, "exact_faces": exact_faces}

    # Same unit-gradient free drainage as the F-LMFP03 candidate.
    face[-1] = mats[-1].conductivity(heads[-1])
    rate = [face[i] - face[i + 1] + source[i] - sink[i] for i in range(n)]
    candidate = [base_storage[i] + step_duration * rate[i] for i in range(n)]

    expected_change = step_duration * (face[0] - face[-1] + sum(source) - sum(sink))
    actual_change = sum(candidate) - sum(base_storage)
    mass_residual = actual_change - expected_change

    admissible = math.inf
    violated = []
    for i in range(n):
        lower = (mats[i].theta_r + 1.0e-10) * thickness[i]
        upper = (mats[i].theta_s - 1.0e-10) * thickness[i]
        if rate[i] > 0.0:
            admissible = min(admissible, max(0.0, (upper - base_storage[i]) / rate[i]))
        elif rate[i] < 0.0:
            admissible = min(admissible, max(0.0, (base_storage[i] - lower) / (-rate[i])))
        if candidate[i] < lower - 1.0e-12 or candidate[i] > upper + 1.0e-12:
            violated.append(i)

    advised = 0.95 * admissible if math.isfinite(admissible) else None
    diagnostics = {"lookup_faces": lookup_faces, "exact_faces": exact_faces}
    if violated:
        return TrialResult(False, list(base_storage), heads, face, rate, mass_residual, advised, 0,
                           "storage_bounds:" + str(violated)), diagnostics

    return TrialResult(True, candidate, heads, face, rate, mass_residual, advised, 0,
                       "accepted"), diagnostics


def run_path(case_id: int, refinement: int, path: str, pool):
    name, codes, heads0, duration, base_dt, top_down = case_definition(case_id)
    mats = [material_for(c) for c in codes]
    tabs = [TABLES[c] for c in codes]
    storage = [m.theta(h) * dz for m, h, dz in zip(mats, heads0, DZ)]
    initial_storage = sum(storage)
    dt = base_dt / refinement
    nsteps = round(duration / dt)

    max_mass = 0.0
    max_face_iterations = 0
    retries = 0
    lookup_faces = 0
    exact_faces = 0
    final_trial = None

    for _ in range(nsteps):
        if path == "mfp":
            trial = advance_trial(storage, mats, tabs, DZ, dt, top_down)
            diag = {"lookup_faces": 0, "exact_faces": 0}
        elif path == "darcian_lookup":
            trial, diag = advance_trial_lookup(storage, codes, DZ, dt, top_down, pool)
        else:
            raise ValueError(path)

        if not trial.accepted:
            retries += 1
            return {
                "accepted": False,
                "name": name,
                "path": path,
                "reason": trial.reason,
                "advised_step_duration": trial.advised_step_duration,
                "retries": retries,
                "dt": dt,
                "nsteps": nsteps,
                "mass_max": max_mass,
                "lookup_faces": lookup_faces,
                "exact_faces": exact_faces,
            }
        storage = trial.candidate_storage
        final_trial = trial
        max_mass = max(max_mass, abs(trial.mass_residual))
        max_face_iterations = max(max_face_iterations, trial.max_face_iterations)
        lookup_faces += diag["lookup_faces"]
        exact_faces += diag["exact_faces"]

    theta = [w / dz for w, dz in zip(storage, DZ)]
    h = [m.head_from_theta(t) for m, t in zip(mats, theta)]
    return {
        "accepted": True,
        "name": name,
        "path": path,
        "dt": dt,
        "nsteps": nsteps,
        "top_down": top_down,
        "bottom_down": final_trial.face_flux[-1] if final_trial else mats[-1].conductivity(heads0[-1]),
        "initial_storage": initial_storage,
        "final_storage": sum(storage),
        "mass_max": max_mass,
        "max_face_iterations": max_face_iterations,
        "retries": retries,
        "lookup_faces": lookup_faces,
        "exact_faces": exact_faces,
        "theta": theta,
        "h": h,
    }


def improvement(old: float, new: float):
    if old == 0.0:
        return 0.0 if new == 0.0 else -math.inf
    return (old - new) / old


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp07_transient_ab.py REFERENCE_OUTPUT EVIDENCE_JSON")

    reference_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    ref = parse_reference(reference_path)
    pool = build_lookup_pool()

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP07",
        "lookup": {
            "source": "F-LMFP06 independent steady-Darcy oracle",
            "legacy_swkmean7_reproduced": False,
            "head_envelope_cm": [HEAD_DRY, HEAD_WET],
            "head_axis_points": len(HEAD_AXIS),
            "unique_face_classes": len(pool),
            "values_per_face_class": len(HEAD_AXIS) ** 2,
            "shared_immutable_parameter_data": True,
        },
        "cases": {},
        "tests": {},
    }

    structural_ok = True
    improvements = []
    for case_id in range(1, 7):
        name = case_definition(case_id)[0]
        case_ev = {"refinements": {}}
        for refinement in (1, 2):
            key = (case_id, refinement)
            if key not in ref or "summary" not in ref[key] or len(ref[key].get("nodes", {})) != 4:
                raise SystemExit(f"missing FullRichards output for {key}")

            mfp = run_path(case_id, refinement, "mfp", pool)
            dar = run_path(case_id, refinement, "darcian_lookup", pool)
            if not mfp["accepted"] or not dar["accepted"]:
                structural_ok = False
                case_ev["refinements"][str(refinement)] = {
                    "fullrichards": ref[key], "mfp": mfp, "darcian_lookup": dar,
                }
                continue

            mfp_metrics = compare(ref[key], mfp, case_id)
            dar_metrics = compare(ref[key], dar, case_id)
            delta = {
                metric: improvement(mfp_metrics[metric], dar_metrics[metric])
                for metric in (
                    "theta_max_abs", "theta_rmse", "head_max_abs_cm", "head_rmse_cm",
                    "pf_max_abs", "storage_abs_cm", "bottom_flux_abs_cm_d"
                )
            }
            improvements.append((name, refinement, delta))
            case_ev["refinements"][str(refinement)] = {
                "fullrichards": ref[key],
                "mfp": mfp,
                "darcian_lookup": dar,
                "mfp_vs_fullrichards": mfp_metrics,
                "darcian_vs_fullrichards": dar_metrics,
                "fractional_error_reduction_positive_is_better": delta,
            }

            if ref[key].get("mass_max", math.inf) > 2.0e-8:
                structural_ok = False
            if mfp["mass_max"] > 2.0e-10 or dar["mass_max"] > 2.0e-10:
                structural_ok = False
        evidence["cases"][name] = case_ev

    all_accepted = all(
        evidence["cases"][case_definition(c)[0]]["refinements"][str(r)].get(path, {}).get("accepted", False)
        for c in range(1, 7) for r in (1, 2) for path in ("mfp", "darcian_lookup")
    )
    mfp_mass = max(
        evidence["cases"][case_definition(c)[0]]["refinements"][str(r)].get("mfp", {}).get("mass_max", math.inf)
        for c in range(1, 7) for r in (1, 2)
    )
    dar_mass = max(
        evidence["cases"][case_definition(c)[0]]["refinements"][str(r)].get("darcian_lookup", {}).get("mass_max", math.inf)
        for c in range(1, 7) for r in (1, 2)
    )
    full_mass = max(ref[(c, r)].get("mass_max", math.inf) for c in range(1, 7) for r in (1, 2))

    steady = evidence["cases"]["steady_sand"]["refinements"]["2"]
    steady_d = steady["darcian_vs_fullrichards"]
    steady_ok = steady_d["theta_max_abs"] < 1.0e-9 and steady_d["bottom_flux_rel"] < 2.0e-8

    evidence["tests"]["all_candidate_steps_accepted"] = {"pass": all_accepted}
    evidence["tests"]["mass_closure"] = {
        "pass": full_mass <= 2.0e-8 and mfp_mass <= 2.0e-10 and dar_mass <= 2.0e-10,
        "fullrichards_max": full_mass,
        "mfp_max": mfp_mass,
        "darcian_lookup_max": dar_mass,
    }
    evidence["tests"]["steady_uniform_cross_model_identity"] = {
        "pass": steady_ok,
        "theta_max_abs": steady_d["theta_max_abs"],
        "bottom_flux_rel": steady_d["bottom_flux_rel"],
    }
    evidence["tests"]["lookup_envelope_respected"] = {
        "pass": all_accepted,
        "qualified_envelope_cm": [HEAD_DRY, HEAD_WET],
        "rule": "out-of-envelope heads reject the trial; no silent extrapolation",
    }

    dynamic = [
        (name, r, d) for name, r, d in improvements if name != "steady_sand"
    ]
    evidence["observed_error_reduction"] = {
        "dynamic_case_refinement_pairs": len(dynamic),
        "theta_rmse_improved_count": sum(d["theta_rmse"] > 0.0 for _, _, d in dynamic),
        "head_rmse_improved_count": sum(d["head_rmse_cm"] > 0.0 for _, _, d in dynamic),
        "storage_error_improved_count": sum(d["storage_abs_cm"] > 0.0 for _, _, d in dynamic),
        "bottom_flux_error_improved_count": sum(d["bottom_flux_abs_cm_d"] > 0.0 for _, _, d in dynamic),
        "pairs": [
            {"case": name, "refinement": r, **d} for name, r, d in dynamic
        ],
    }

    evidence["interpretation"] = {
        "physical_similarity_thresholds": "No new transient similarity threshold is used as a structural pass criterion in this exploratory workunit. Error reductions are reported descriptively and will determine whether a separate qualification envelope can be justified.",
        "flux_sign": "downward-positive in reduced-order evidence; FullRichards reference output already sign-converted by the F-LMFP04 driver",
        "scope": "hydraulic-only explicit top flux, free drainage bottom, no crop, drainage process, ponding, groundwater or MODFLOW",
        "production_change": False,
    }

    structural_ok = structural_ok and all_accepted and evidence["tests"]["mass_closure"]["pass"] and steady_ok
    evidence["structural_pass"] = structural_ok
    output_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if structural_ok else 1)


if __name__ == "__main__":
    main()
