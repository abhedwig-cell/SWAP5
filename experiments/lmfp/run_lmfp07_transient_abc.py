from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp03_column import homogeneous_face_flux, heterogeneous_face_flux
from run_lmfp04_ab import DZ, SAND, CLAY, TABLES, case_definition, parse_reference
from run_lmfp06_darcian_reference import MATERIALS, solve_steady_flux
from run_lmfp06_lookup_surrogate import DarcianLookup, HEAD_AXIS

MATERIAL_BY_CODE = {1: SAND, 2: CLAY}


def rms(values):
    return math.sqrt(sum(v*v for v in values) / len(values))


def relerr(a, b, floor=1.0e-12):
    return abs(a-b) / max(abs(b), floor)


class LookupCache:
    def __init__(self):
        self.tables = {}
        self.build_count = 0
        self.transient_calls = 0
        self.coverage_misses = 0
        self.min_head = min(HEAD_AXIS)
        self.max_head = max(HEAD_AXIS)

    def table(self, code_u, code_l, len_u, len_l):
        key = (int(code_u), int(code_l), round(float(len_u), 12), round(float(len_l), 12))
        if key not in self.tables:
            self.tables[key] = DarcianLookup(code_u, code_l, len_u, len_l)
            self.build_count += 1
        return self.tables[key]

    def flux(self, code_u, code_l, h_u, h_l, len_u, len_l):
        self.transient_calls += 1
        if not (self.min_head <= h_u <= self.max_head and self.min_head <= h_l <= self.max_head):
            self.coverage_misses += 1
            raise RuntimeError(f"lookup_head_out_of_range:{h_u}:{h_l}")
        return self.table(code_u, code_l, len_u, len_l).flux(h_u, h_l)

    def diagnostics(self):
        return {
            "table_builds": self.build_count,
            "table_values_total": self.build_count * len(HEAD_AXIS) ** 2,
            "bytes_double_values_before_metadata": self.build_count * len(HEAD_AXIS) ** 2 * 8,
            "transient_face_lookups": self.transient_calls,
            "coverage_misses": self.coverage_misses,
            "head_envelope_cm": [self.min_head, self.max_head],
        }


def candidate_trial(base_storage, codes, thickness, step_duration, top_flux, closure,
                    lookup_cache=None, bottom_free_drainage=True):
    n = len(base_storage)
    mats = [MATERIAL_BY_CODE[c] for c in codes]
    heads = []
    for w, m, dz in zip(base_storage, mats, thickness):
        theta = w/dz
        if theta < m.theta_r - 1.0e-10 or theta > m.theta_s + 1.0e-10:
            return {"accepted":False,"reason":"base_state_out_of_bounds","state":list(base_storage)}
        theta_eval = min(m.theta_s, max(m.theta_r + 1.0e-12, theta))
        heads.append(m.head_from_theta(theta_eval))

    face = [0.0]*(n+1)
    face[0] = top_flux
    max_face_iterations = 0
    oracle_calls = 0
    for i in range(n-1):
        lu = 0.5*thickness[i]
        ll = 0.5*thickness[i+1]
        if closure == "mfp":
            if codes[i] == codes[i+1]:
                face[i+1] = homogeneous_face_flux(TABLES[codes[i]], heads[i], heads[i+1], lu+ll)
            else:
                q, _, it, _ = heterogeneous_face_flux(TABLES[codes[i]], TABLES[codes[i+1]],
                                                       heads[i], heads[i+1], lu, ll)
                face[i+1] = q
                max_face_iterations = max(max_face_iterations, it)
        elif closure == "lookup":
            if lookup_cache is None:
                raise ValueError("lookup closure requires cache")
            try:
                face[i+1] = lookup_cache.flux(codes[i], codes[i+1], heads[i], heads[i+1], lu, ll)
            except RuntimeError as exc:
                return {"accepted":False,"reason":str(exc),"state":list(base_storage),"heads":heads}
        elif closure == "oracle":
            q, _, _, _, _ = solve_steady_flux(MATERIALS[codes[i]], MATERIALS[codes[i+1]],
                                               heads[i], heads[i+1], lu, ll)
            face[i+1] = q
            oracle_calls += 1
        else:
            raise ValueError(closure)

    if bottom_free_drainage:
        face[-1] = mats[-1].conductivity(heads[-1])
    else:
        face[-1] = 0.0

    rate = [face[i]-face[i+1] for i in range(n)]
    candidate = [base_storage[i] + step_duration*rate[i] for i in range(n)]
    expected = step_duration*(face[0]-face[-1])
    actual = sum(candidate)-sum(base_storage)
    mass_residual = actual-expected

    admissible = math.inf
    violated = []
    for i, (m, dz, r) in enumerate(zip(mats, thickness, rate)):
        lo = (m.theta_r+1.0e-10)*dz
        hi = (m.theta_s-1.0e-10)*dz
        if r > 0:
            admissible = min(admissible, max(0.0, (hi-base_storage[i])/r))
        elif r < 0:
            admissible = min(admissible, max(0.0, (base_storage[i]-lo)/(-r)))
        if candidate[i] < lo-1.0e-12 or candidate[i] > hi+1.0e-12:
            violated.append(i)
    advised = 0.95*admissible if math.isfinite(admissible) else None
    if violated:
        return {"accepted":False,"reason":"storage_bounds:"+str(violated),
                "state":list(base_storage),"heads":heads,"face":face,
                "mass_residual":mass_residual,"advised_step_duration":advised,
                "max_face_iterations":max_face_iterations,"oracle_calls":oracle_calls}
    return {"accepted":True,"reason":"accepted","state":candidate,"heads":heads,
            "face":face,"rate":rate,"mass_residual":mass_residual,
            "advised_step_duration":advised,"max_face_iterations":max_face_iterations,
            "oracle_calls":oracle_calls}


def integrate_candidate(codes, heads0, thickness, duration, dt, top_flux, closure, lookup_cache=None):
    mats = [MATERIAL_BY_CODE[c] for c in codes]
    state = [m.theta(h)*dz for m,h,dz in zip(mats, heads0, thickness)]
    initial_storage = sum(state)
    nsteps = round(duration/dt)
    if abs(nsteps*dt-duration) > 1.0e-10*max(1.0,duration):
        raise ValueError((duration,dt,nsteps))
    max_mass = 0.0
    max_face_iterations = 0
    oracle_calls = 0
    retries = 0
    final = None
    for _ in range(nsteps):
        tr = candidate_trial(state, codes, thickness, dt, top_flux, closure, lookup_cache)
        if not tr["accepted"]:
            retries += 1
            return {"accepted":False,"reason":tr["reason"],"retries":retries,
                    "dt":dt,"nsteps":nsteps,"initial_storage":initial_storage}
        state = tr["state"]
        final = tr
        max_mass = max(max_mass, abs(tr["mass_residual"]))
        max_face_iterations = max(max_face_iterations, tr["max_face_iterations"])
        oracle_calls += tr["oracle_calls"]
    theta = [w/dz for w,dz in zip(state, thickness)]
    heads = [m.head_from_theta(t) for m,t in zip(mats,theta)]
    return {
        "accepted":True,"closure":closure,"dt":dt,"nsteps":nsteps,
        "initial_storage":initial_storage,"final_storage":sum(state),
        "bottom_down": final["face"][-1] if final else mats[-1].conductivity(heads0[-1]),
        "mass_max":max_mass,"max_face_iterations":max_face_iterations,
        "oracle_calls":oracle_calls,"retries":retries,"theta":theta,"h":heads,
    }


def compare_to_fullrichards(ref, cand, codes, heads0):
    rtheta = [ref["nodes"][i]["theta"] for i in range(1,len(codes)+1)]
    rh = [ref["nodes"][i]["h"] for i in range(1,len(codes)+1)]
    dtheta = [a-b for a,b in zip(cand["theta"],rtheta)]
    dh = [a-b for a,b in zip(cand["h"],rh)]
    theta0 = [MATERIAL_BY_CODE[c].theta(h) for c,h in zip(codes,heads0)]
    sign_matches = 0
    sign_compared = 0
    for t0,tr,tc in zip(theta0,rtheta,cand["theta"]):
        ar=tr-t0; ac=tc-t0
        if max(abs(ar),abs(ac)) > 1.0e-9:
            sign_compared += 1
            if ar == 0 or ac == 0 or ar*ac > 0:
                sign_matches += 1
    return {
        "theta_max_abs":max(abs(x) for x in dtheta),
        "theta_rmse":rms(dtheta),
        "head_max_abs_cm":max(abs(x) for x in dh),
        "head_rmse_cm":rms(dh),
        "storage_abs_cm":abs(cand["final_storage"]-ref["summary"]["final_storage"]),
        "bottom_flux_abs_cm_d":abs(cand["bottom_down"]-ref["summary"]["bottom_down"]),
        "bottom_flux_rel":relerr(cand["bottom_down"],ref["summary"]["bottom_down"]),
        "direction_matches":sign_matches,"direction_compared":sign_compared,
    }


def run_fullrichards_abc(reference_path):
    ref = parse_reference(reference_path)
    lookup = LookupCache()
    cases = {}
    for case_id in range(1,7):
        name,codes,heads0,duration,base_dt,top = case_definition(case_id)
        ce={"refinements":{}}
        for refinement in (1,2):
            key=(case_id,refinement)
            if key not in ref:
                raise RuntimeError(f"missing FullRichards {key}")
            dt=base_dt/refinement
            mfp=integrate_candidate(codes,heads0,DZ,duration,dt,top,"mfp")
            dar=integrate_candidate(codes,heads0,DZ,duration,dt,top,"lookup",lookup)
            item={"fullrichards":ref[key],"mfp":mfp,"darcian_lookup":dar}
            if mfp["accepted"]:
                item["mfp_vs_fullrichards"]=compare_to_fullrichards(ref[key],mfp,codes,heads0)
            if dar["accepted"]:
                item["lookup_vs_fullrichards"]=compare_to_fullrichards(ref[key],dar,codes,heads0)
            ce["refinements"][str(refinement)]=item
        cases[name]=ce
    return cases, lookup


STRESS = [
    ("sand_strong_gradient_1", [1,1], [-183.9188,-3.05775], [11.37460,11.37460]),
    ("sand_strong_gradient_2", [1,1], [-300.0,-5.0], [12.0,12.0]),
    ("sand_strong_gradient_3", [1,1], [-200.0,-20.0], [10.0,10.0]),
    ("clay_strong_gradient_down", [2,2], [-200.0,-20.0], [10.0,10.0]),
    ("clay_strong_gradient_up", [2,2], [-30.0,-300.0], [10.0,10.0]),
]


def run_stress_transients():
    lookup=LookupCache()
    out={}
    for name,codes,heads0,dz in STRESS:
        duration=1.0e-4
        base_dt=1.0e-5
        row={"refinements":{}}
        for refinement in (1,2):
            dt=base_dt/refinement
            oracle=integrate_candidate(codes,heads0,dz,duration,dt,0.0,"oracle")
            mfp=integrate_candidate(codes,heads0,dz,duration,dt,0.0,"mfp")
            dar=integrate_candidate(codes,heads0,dz,duration,dt,0.0,"lookup",lookup)
            def cmp(c):
                return {
                    "theta_max_abs":max(abs(a-b) for a,b in zip(c["theta"],oracle["theta"])),
                    "head_max_abs_cm":max(abs(a-b) for a,b in zip(c["h"],oracle["h"])),
                    "storage_abs_cm":abs(c["final_storage"]-oracle["final_storage"]),
                    "bottom_flux_abs_cm_d":abs(c["bottom_down"]-oracle["bottom_down"]),
                }
            row["refinements"][str(refinement)]={
                "oracle":oracle,"mfp":mfp,"darcian_lookup":dar,
                "mfp_vs_direct_darcian":cmp(mfp) if mfp["accepted"] and oracle["accepted"] else None,
                "lookup_vs_direct_darcian":cmp(dar) if dar["accepted"] and oracle["accepted"] else None,
            }
        out[name]=row
    return out,lookup


def temporal_distance(a,b):
    return max(abs(x-y) for x,y in zip(a["theta"],b["theta"]))


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_lmfp07_transient_abc.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    cases,lookup_main=run_fullrichards_abc(Path(sys.argv[1]))
    stress,lookup_stress=run_stress_transients()

    structural=True
    all_mass=[]
    all_accept=[]
    lookup_better_count=0
    lookup_compared=0
    for ce in cases.values():
        for item in ce["refinements"].values():
            for key in ("mfp","darcian_lookup"):
                c=item[key]
                all_accept.append(c["accepted"])
                if c["accepted"]:
                    all_mass.append(c["mass_max"])
            if item["mfp"]["accepted"] and item["darcian_lookup"]["accepted"]:
                mm=item["mfp_vs_fullrichards"]["theta_rmse"]
                dd=item["lookup_vs_fullrichards"]["theta_rmse"]
                lookup_compared += 1
                if dd < mm:
                    lookup_better_count += 1
    structural = structural and all(all_accept) and max(all_mass,default=0.0) < 2.0e-10
    structural = structural and lookup_main.coverage_misses == 0

    stress_lookup_better=0
    stress_compared=0
    stress_temporal={}
    for name,row in stress.items():
        r1=row["refinements"]["1"]
        r2=row["refinements"]["2"]
        for item in (r1,r2):
            for key in ("oracle","mfp","darcian_lookup"):
                structural = structural and item[key]["accepted"] and item[key]["mass_max"] < 2.0e-10
        if r2["mfp_vs_direct_darcian"] and r2["lookup_vs_direct_darcian"]:
            stress_compared += 1
            if r2["lookup_vs_direct_darcian"]["theta_max_abs"] < r2["mfp_vs_direct_darcian"]["theta_max_abs"]:
                stress_lookup_better += 1
        stress_temporal[name]={
            "oracle_theta_coarse_fine":temporal_distance(r1["oracle"],r2["oracle"]),
            "mfp_theta_coarse_fine":temporal_distance(r1["mfp"],r2["mfp"]),
            "lookup_theta_coarse_fine":temporal_distance(r1["darcian_lookup"],r2["darcian_lookup"]),
        }
    structural = structural and lookup_stress.coverage_misses == 0

    evidence={
        "schema_version":1,"work_unit":"F-LMFP07",
        "scope":"hydraulic-only transient A/B/C; no production admission",
        "cases":cases,"stress_cases":stress,
        "tests":{
            "all_candidate_steps_accepted":{"pass":all(all_accept)},
            "candidate_mass_closure":{"pass":max(all_mass,default=0.0)<2.0e-10,
                                      "maximum":max(all_mass,default=0.0),"threshold":2.0e-10},
            "lookup_coverage_main":{"pass":lookup_main.coverage_misses==0,
                                    "diagnostics":lookup_main.diagnostics()},
            "lookup_coverage_stress":{"pass":lookup_stress.coverage_misses==0,
                                      "diagnostics":lookup_stress.diagnostics()},
            "stress_all_paths_mass_conservative":{"pass":all(
                item[key]["accepted"] and item[key]["mass_max"]<2.0e-10
                for row in stress.values() for item in row["refinements"].values()
                for key in ("oracle","mfp","darcian_lookup"))},
        },
        "comparative_summary":{
            "lookup_theta_rmse_better_than_mfp_vs_same_grid_fullrichards":{
                "count":lookup_better_count,"compared":lookup_compared,
                "interpretation":"diagnostic only; same-grid FullRichards uses SWKMEAN=1 and is not treated as unique interface truth"
            },
            "lookup_theta_better_than_mfp_vs_direct_darcian_stress":{
                "count":stress_lookup_better,"compared":stress_compared
            },
            "stress_temporal_sensitivity":stress_temporal,
            "runtime_cost_proxies":{
                "fullrichards_nonlinear_iterations_total":sum(
                    item["fullrichards"]["summary"]["nonlinear_iterations_total"]
                    for ce in cases.values() for item in ce["refinements"].values()),
                "mfp_max_local_interface_iterations":max(
                    item["mfp"].get("max_face_iterations",0)
                    for ce in cases.values() for item in ce["refinements"].values()),
                "lookup_main":lookup_main.diagnostics(),
                "lookup_stress":lookup_stress.diagnostics(),
                "lookup_generation_is_offline_cost":True,
            }
        },
        "structural_pass":structural,
        "interpretation":{
            "physical_acceptance_thresholds":"not predeclared; cross-model differences remain scientific evidence, not automatic admission gates",
            "lookup_behavior":"strict envelope in transient qualification; no silent extrapolation or fallback",
            "solver_policy":"LayeredMFP closure choice is explicit model configuration, not execution policy",
        }
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural else 1)


if __name__=="__main__":
    main()
