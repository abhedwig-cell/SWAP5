from __future__ import annotations
import argparse, copy, json, math
from pathlib import Path
import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q


def set_dt(req, t0, dt):
    req = copy.deepcopy(req)
    req["forcing_process_requests"]["t0_day"] = float(t0)
    req["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return req


def ok_mass(result):
    value = result.get("unrounded_mass_residual_cm")
    return isinstance(value, (int, float)) and math.isfinite(float(value)) and abs(float(value)) <= 1e-12


def main():
    p = argparse.ArgumentParser(); p.add_argument("--output", type=Path, required=True); p.add_argument("--canonical-head", required=True); a = p.parse_args()
    rows, max_mass, max_h, max_t = [], 0.0, 0.0, 0.0
    for material in adapter.MATERIAL_IDS:
        for i in range(adapter.CANONICAL_MAX_RETRIES + 1):
            full_dt, half_dt = adapter.DURATION_LADDER_DAY[i], adapter.DURATION_LADDER_DAY[i + 1]
            t0 = 37.125 + i
            base = d2q.base_request(material, steps=8, perturb=0.0, pre=False)
            full_req, h1_req = set_dt(base, t0, full_dt), set_dt(base, t0, half_dt)
            full = adapter.execute_research_trial(copy.deepcopy(full_req))
            h1 = adapter.execute_research_trial(copy.deepcopy(h1_req))
            h2_req = set_dt(base, t0 + half_dt, half_dt)
            if h1.get("solver_disposition") == "candidate_ready":
                h2_req["committed_state"] = copy.deepcopy(h1["candidate_hydraulic_state"])
            h2 = adapter.execute_research_trial(copy.deepcopy(h2_req))
            ready = all(x.get("solver_disposition") == "candidate_ready" for x in (full, h1, h2))
            mass = all(ok_mass(x) for x in (full, h1, h2))
            immutable = all(x.get("committed_state_mutated") is False for x in (full, h1, h2))
            same_forcing = h1_req["forcing_process_requests"]["top_boundary"] == h2_req["forcing_process_requests"]["top_boundary"] and h1_req["forcing_process_requests"]["bottom_boundary"] == h2_req["forcing_process_requests"]["bottom_boundary"]
            dh = dt = None
            if ready:
                fh, hh = full["candidate_hydraulic_state"]["pressure_head_cm"], h2["candidate_hydraulic_state"]["pressure_head_cm"]
                ft, ht = full["candidate_hydraulic_state"]["water_content"], h2["candidate_hydraulic_state"]["water_content"]
                dh = max(abs(float(x)-float(y)) for x,y in zip(fh,hh)); dt = max(abs(float(x)-float(y)) for x,y in zip(ft,ht)); max_h=max(max_h,dh); max_t=max(max_t,dt)
            for x in (full,h1,h2):
                r=x.get("unrounded_mass_residual_cm"); max_mass=max(max_mass,abs(float(r))) if isinstance(r,(int,float)) else max_mass
            rows.append({"material":material,"attempt_index":i,"pass":ready and mass and immutable and same_forcing,"ready":ready,"mass":mass,"same_forcing":same_forcing,"full_class":full.get("failure_classification"),"half1_class":h1.get("failure_classification"),"half2_class":h2.get("failure_classification"),"head_delta_cm":dh,"theta_delta":dt})
    supported = all(x["pass"] for x in rows)
    out={"work_unit":"F-ROSS01 D3R","kind":"two_half_probe","live_canonical_head":a.canonical_head,"canonical_two_half_candidate_chain_supported":supported,"chain_count":len(rows),"max_abs_mass_residual_cm":max_mass,"max_abs_full_vs_two_half_head_delta_cm":max_h,"max_abs_full_vs_two_half_theta_delta":max_t,"external_temporal_error_semantics_qualified":False,"temporal_error_disposition":"DIAGNOSTIC_STATE_DELTAS_ONLY_NO_ACCEPTANCE_METRIC_OR_TOLERANCE_CLAIM","chains":rows,"production_source_delta":[]}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n"); print(json.dumps({"chain_supported":supported,"chain_count":len(rows),"max_mass":max_mass,"max_head_delta_cm":max_h,"max_theta_delta":max_t},sort_keys=True)); return 0

if __name__ == "__main__": raise SystemExit(main())
