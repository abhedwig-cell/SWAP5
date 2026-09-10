from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a_top_node_saturation_event_fixture_characterization as a1

CONTRACT = "F-ROSS01_GATE_E3H_A6_O14_POST_CAP_FIXED_HEAD_TRAJECTORY_AND_ASYMPTOTIC_TOPOLOGY_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
HSURF = 1.0
HBOT = -15.0
SUPPLY_FRAC = 12.0
HUP = -1.0e-8
SAT_APPROACH = -1.0e-6
MASS_TOL = 1.0e-9
FLUX_TOL = 1.0e-8
MAX_NFEV = 200

CAP_STATES = {
    "P0_A1_CONTROL": (-0.14612442301092474,-3.4365807674561273,-8.231314064881142),
    "P1_DRIER_SUBSOIL": (-0.23356049032180035,-3.7808381225488468,-8.689972381245196),
    "P2_DRIER_TOP_AND_SUBSOIL": (-0.47697860016578836,-4.718962776786451,-10.022018575369172),
    "P3_STRONG_DRY_SEPARATION": (-1.472189253257072,-8.509653922626015,-16.120819017592716),
}
SCHEDULE = ((20, 0.0005), (18, 0.005), (18, 0.05))
STEADY_STARTS = (
    (-0.2,-3.0,-8.0),
    (-1.0,-5.0,-10.0),
    (-5.0,-10.0,-12.0),
    (-0.05,-1.0,-5.0),
    (-10.0,-12.0,-14.0),
)


def bits(heads) -> bytes:
    return struct.pack("!3d", *map(float, heads))


def configure(row: dict) -> None:
    a1.configure(row)


def theta(h: float) -> float:
    return float(a1.theta(float(h)))


def q_surface_exact(h0: float, row: dict) -> tuple[float, str, float]:
    ref = a1.e3g.exact_surface_reference(HSURF, float(h0), row)
    return float(ref["q"]), str(ref["branch"]), float(ref["residual_cm"])


def q_internal_reference(heads, row: dict):
    q, routes = a1.internal_q(float(heads[0]), float(heads[1]), float(heads[2]), row, False, None)
    return tuple(float(v) for v in q), tuple(str(v) for v in routes)


def flux_state(heads, row: dict) -> dict:
    qtop, branch, surf_res = q_surface_exact(float(heads[0]), row)
    (q01,q12,qb), routes = q_internal_reference(heads, row)
    return {
        "qtop": qtop, "q01": q01, "q12": q12, "qb": qb,
        "surface_reference_branch": branch,
        "surface_reference_path_residual_cm": surf_res,
        "internal_routes": list(routes),
    }


def initial_tendency(cap_heads, row: dict) -> dict:
    f = flux_state(cap_heads, row)
    rates = [f["qtop"]-f["q01"], f["q01"]-f["q12"], f["q12"]-f["qb"]]
    return {
        "heads_cm": list(cap_heads),
        "fluxes_cm_per_day": f,
        "cell_storage_rate_cm_per_day": rates,
        "top_storage_rate_cm_per_day": rates[0],
        "top_initially_wets": rates[0] > 0.0,
        "top_initially_dries_or_neutral": rates[0] <= 0.0,
    }


def be_residual(new_heads, old_heads, dt: float, row: dict):
    f = flux_state(new_heads, row)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    return np.asarray([
        a1.DZ * (theta(float(new_heads[i])) - theta(float(old_heads[i]))) - dt * (q[i]-q[i+1])
        for i in range(3)
    ], dtype=np.float64)


def solve_step(old_heads, dt: float, row: dict) -> dict:
    snapshot = bits(old_heads)
    try:
        sol = least_squares(
            lambda h: be_residual(h, old_heads, dt, row),
            np.asarray(old_heads, dtype=np.float64),
            bounds=(np.full(3,-10000.0), np.full(3,HUP)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        hh = tuple(float(v) for v in sol.x)
        f = flux_state(hh, row)
        r = be_residual(hh, old_heads, dt, row)
        soil_storage = math.fsum(a1.DZ*(theta(hh[i])-theta(float(old_heads[i]))) for i in range(3))
        qsup = SUPPLY_FRAC*float(row["ksatfit_cm_per_day"])
        runoff_rate = qsup-f["qtop"]
        runoff_amount = dt*runoff_rate
        system = soil_storage + runoff_amount + dt*f["qb"] - dt*qsup
        maxres = max(max(abs(float(v)) for v in r), abs(system))
        finite = all(math.isfinite(v) for v in (*hh, *r, runoff_rate, runoff_amount, system, maxres))
        accepted = bool(sol.success and finite and maxres <= MASS_TOL and runoff_rate >= 0.0)
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "dt_day": dt,
            "heads_cm": list(hh),
            "fluxes_cm_per_day": f,
            "runoff_rate_cm_per_day": runoff_rate,
            "runoff_amount_cm": runoff_amount,
            "cell_residuals_cm": [float(v) for v in r],
            "system_balance_residual_cm": float(system),
            "max_abs_balance_residual_cm": maxres,
            "top_saturation_approach": hh[0] >= SAT_APPROACH,
            "input_state_bitwise_unchanged_during_trial": bits(old_heads)==snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "dt_day": dt,
            "input_state_bitwise_unchanged_during_trial": bits(old_heads)==snapshot,
            "mass_repair_or_clipping_used": False,
        }


def transient(cap_heads, row: dict) -> dict:
    heads = tuple(float(v) for v in cap_heads)
    records=[]; t=0.0; runoff=0.0; maxres=0.0; maxh0=heads[0]; failed_at=None
    for count,dt in SCHEDULE:
        for _ in range(count):
            s=solve_step(heads,float(dt),row)
            s["t0_after_cap_day"]=t
            s["t1_after_cap_day"]=t+float(dt)
            records.append(s)
            if not s.get("accepted"):
                failed_at=len(records)-1
                return {
                    "complete":False,"failed_step_index":failed_at,"records":records,
                    "accepted_step_count":sum(int(x.get("accepted",False)) for x in records),
                    "top_saturation_approach_count":sum(int(x.get("top_saturation_approach",False)) for x in records),
                    "max_top_head_cm":maxh0,"max_abs_balance_residual_cm":maxres,
                    "cumulative_runoff_cm":runoff,"horizon_day":t,
                }
            heads=tuple(float(v) for v in s["heads_cm"]); t+=float(dt); runoff+=float(s["runoff_amount_cm"])
            maxres=max(maxres,float(s["max_abs_balance_residual_cm"])); maxh0=max(maxh0,heads[0])
    return {
        "complete":True,"failed_step_index":None,"records":records,
        "accepted_step_count":len(records),
        "top_saturation_approach_count":sum(int(x["top_saturation_approach"]) for x in records),
        "max_top_head_cm":maxh0,"final_heads_cm":list(heads),
        "max_abs_balance_residual_cm":maxres,"cumulative_runoff_cm":runoff,"horizon_day":t,
    }


def steady_residual(heads, row: dict):
    f=flux_state(heads,row)
    return np.asarray([f["qtop"]-f["q01"], f["q01"]-f["q12"], f["q12"]-f["qb"]],dtype=np.float64)


def steady_roots(row: dict) -> dict:
    attempts=[]
    for i,start in enumerate(STEADY_STARTS):
        try:
            sol=least_squares(
                lambda h: steady_residual(h,row), np.asarray(start,dtype=np.float64),
                bounds=(np.full(3,-10000.0),np.full(3,HUP)), xtol=1e-13,ftol=1e-13,gtol=1e-13,
                max_nfev=300,x_scale="jac",
            )
            hh=tuple(float(v) for v in sol.x); r=steady_residual(hh,row); f=flux_state(hh,row)
            maxr=max(abs(float(v)) for v in r)
            valid=bool(sol.success and all(math.isfinite(v) for v in (*hh,*r)) and maxr<=FLUX_TOL and hh[0]<-1e-4)
            attempts.append({"start_id":i,"start":list(start),"solver_success":bool(sol.success),"nfev":int(sol.nfev),"heads_cm":list(hh),"fluxes_cm_per_day":f,"flux_continuity_residuals_cm_per_day":[float(v) for v in r],"max_abs_flux_continuity_residual_cm_per_day":maxr,"valid_unsaturated_root":valid})
        except Exception as exc:
            attempts.append({"start_id":i,"start":list(start),"solver_success":False,"valid_unsaturated_root":False,"error":repr(exc)})
    valid=[a for a in attempts if a.get("valid_unsaturated_root")]
    clusters=[]
    used=set()
    for i,a in enumerate(valid):
        if i in used: continue
        members=[]
        for j,b in enumerate(valid):
            if max(abs(x-y) for x,y in zip(a["heads_cm"],b["heads_cm"]))<=0.001:
                members.append(b); used.add(j)
        rep=min(members,key=lambda x:x["start_id"])
        clusters.append({"member_count":len(members),"reproducible":len(members)>=2,"start_ids":[x["start_id"] for x in members],"representative":rep})
    clusters.sort(key=lambda x:(-int(x["reproducible"]),-x["member_count"]))
    reproducible=[c for c in clusters if c["reproducible"]]
    return {"attempts":attempts,"valid_root_count":len(valid),"clusters":clusters,"reproducible_cluster_count":len(reproducible),"representative":reproducible[0]["representative"] if reproducible else None}


def run_profile(row: dict, profile_id: str) -> dict:
    cap=CAP_STATES[profile_id]; configure(row)
    tendency=initial_tendency(cap,row)
    traj=transient(cap,row)
    steady=steady_roots(row)
    rep=steady["representative"]
    unsat_attractor=bool(
        tendency["top_initially_dries_or_neutral"]
        and traj["complete"] and traj["accepted_step_count"]==56
        and traj["top_saturation_approach_count"]==0
        and traj["max_abs_balance_residual_cm"]<=MASS_TOL
        and rep is not None and float(rep["heads_cm"][0]) < -1e-4
    )
    tests={
        "initial_tendency_finite":math.isfinite(tendency["top_storage_rate_cm_per_day"]),
        "transient_complete":traj["complete"] is True,
        "transient_step_count":traj["accepted_step_count"]==56,
        "transient_mass":traj["max_abs_balance_residual_cm"]<=MASS_TOL,
        "runoff_nonnegative":traj["cumulative_runoff_cm"]>=0.0,
        "steady_reproducible":rep is not None,
    }
    return {"profile_id":profile_id,"cap_heads_cm":list(cap),"initial_tendency":tendency,"transient_summary":{k:v for k,v in traj.items() if k!="records"},"transient_records":traj["records"],"steady":steady,"unsaturated_attractor_evidence":unsat_attractor,"tests":tests,"diagnostic_complete":all(tests.values())}


def main():
    if len(sys.argv)!=3: raise SystemExit("usage: run_ross01_gate_e3h_a6_o14_postcap_reference_topology.py PROFILE OUTPUT.json")
    profile=sys.argv[1]
    if profile not in CAP_STATES: raise SystemExit(profile)
    catalog=json.loads(CATALOG.read_text(encoding="utf-8")); row=next(r for r in catalog["rows"] if r["sfu"]==MATERIAL)
    pr=run_profile(row,profile)
    if not pr["diagnostic_complete"]:
        decision="O14_POST_CAP_REFERENCE_TRAJECTORY_OR_STEADY_DIAGNOSTIC_INCOMPLETE"
        passed=False
    elif pr["unsaturated_attractor_evidence"]:
        decision="O14_POST_CAP_UNSATURATED_ATTRACTOR_CHARACTERIZED_NO_FORCED_TOP_SATURATION_EVENT_REQUIRED_IN_FROZEN_CAP_TOPOLOGY"
        passed=True
    else:
        decision="O14_POST_CAP_TOP_SATURATION_REACHABLE_OR_UNSATURATED_ATTRACTOR_NOT_ESTABLISHED"
        passed=False
    payload={"schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"E3H_A6_O14_POST_CAP_FIXED_HEAD_TRAJECTORY_AND_ASYMPTOTIC_TOPOLOGY_DIAGNOSTIC","contract":CONTRACT,"production_implementation":False,"qualification_use":False,"material":MATERIAL,"profile_result":pr,"pass":passed,"decision":decision,"hard_nonclaims":["No production runoff qualification.","No Ross candidate performance qualification.","No theorem that top saturation is impossible under every forcing or surface cap.","No response tangent, runtime, MultiSWAP or groundwater admission."]}
    out=Path(sys.argv[2]); out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"profile":profile,"pass":passed,"decision":decision,"initial_top_storage_rate":pr["initial_tendency"]["top_storage_rate_cm_per_day"],"trajectory_complete":pr["transient_summary"]["complete"],"max_top_head_cm":pr["transient_summary"].get("max_top_head_cm"),"final_heads_cm":pr["transient_summary"].get("final_heads_cm"),"steady_heads_cm":None if pr["steady"]["representative"] is None else pr["steady"]["representative"]["heads_cm"],"max_mass":pr["transient_summary"].get("max_abs_balance_residual_cm")},sort_keys=True),flush=True)
    if not passed: raise SystemExit(1)

if __name__=="__main__": main()
