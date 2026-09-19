#!/usr/bin/env python3
from __future__ import annotations
import argparse, collections, json, math, pathlib

GEOMS={"R16":16,"R8":8,"R4":4,"R2":2}
HISTS=[*(f"D{i:02d}" for i in range(1,9)),*(f"V{i:02d}" for i in range(1,5))]
THETA_R=0.02
THETA_S=0.427494
MASS_GATE=1e-12

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse(path):
    states={}; nodes=collections.defaultdict(dict); geometry=None
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D2_GEOMETRY|"):
            geometry=fields(line.split("|",1)[1])
        elif "F_ROMV2_D2_STATE|" in line:
            r=fields(line.split("F_ROMV2_D2_STATE|",1)[1]); states[(r["HISTORY"],int(r["STEP"]))]=r
        elif "F_ROMV2_D2_NODE|" in line:
            r=fields(line.split("F_ROMV2_D2_NODE|",1)[1]); nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]=r
    if geometry is None: raise SystemExit(f"missing geometry record {path}")
    n=int(geometry["N"])
    expected={(h,s) for h in HISTS for s in range(1,65)}
    if set(states)!=expected or set(nodes)!=expected:
        raise SystemExit(f"state structure mismatch {path}")
    if any(set(nodes[k])!=set(range(1,n+1)) for k in expected):
        raise SystemExit(f"node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes,"path":str(path)}

def qstats(vals):
    vals=[float(x) for x in vals]
    if not vals:return {"count":0}
    av=sorted(abs(x) for x in vals)
    return {
      "count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(x) for x in vals)/len(vals),
      "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
      "p95_abs":av[min(len(av)-1,math.ceil(.95*len(av))-1)],"max_abs":av[-1]
    }

def sign(x): return 1 if x>0 else -1 if x<0 else 0

def reversals(flux):
    out=[]; prev=None
    for s in sorted(flux):
        sg=sign(flux[s])
        if sg==0: continue
        if prev is not None and sg!=prev: out.append(s)
        prev=sg
    return out

def mapped_profile_errors(coarse,fine,h,step):
    n=coarse["n"]; group=16//n
    th=[]; hd=[]
    for i in range(1,n+1):
        c=coarse["nodes"][(h,step)][i]
        fs=[fine["nodes"][(h,step)][j] for j in range((i-1)*group+1,i*group+1)]
        th.append(float(c["THETA"])-sum(float(x["THETA"]) for x in fs)/group)
        hd.append(float(c["H"])-sum(float(x["H"]) for x in fs)/group)
    return th,hd

def dominates(a,b,axes):
    le=all(a[x]<=b[x] for x in axes); lt=any(a[x]<b[x] for x in axes)
    return le and lt

def frontier(rows,axes):
    names=[]
    for name,a in rows.items():
        if not any(other!=name and dominates(b,a,axes) for other,b in rows.items()):
            names.append(name)
    return sorted(names,key=lambda x: GEOMS[x],reverse=True)

def main():
    ap=argparse.ArgumentParser()
    for g in GEOMS: ap.add_argument("--"+g.lower(),required=True)
    ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    runs={g:parse(getattr(a,g.lower())) for g in GEOMS}
    for g,n in GEOMS.items():
        if runs[g]["n"]!=n: raise SystemExit(f"{g} node mismatch")
    ref=runs["R16"]

    integrity={}
    for g,run in runs.items():
        nonfinite=theta_bad=mass_bad=0
        for key,r in run["states"].items():
            vals=[float(r[k]) for k in ("TOTAL_STORAGE","UPPER_STORAGE","LOWER_STORAGE","BOTTOM_OUTWARD_EXCHANGE","BOTTOM_FLUX","MASS")]
            if not all(math.isfinite(x) for x in vals): nonfinite+=1
            if abs(float(r["MASS"]))>MASS_GATE: mass_bad+=1
            for nr in run["nodes"][key].values():
                t=float(nr["THETA"])
                if not math.isfinite(t) or t<THETA_R or t>THETA_S: theta_bad+=1
        integrity[g]={"pass":nonfinite==theta_bad==mass_bad==0,"nonfinite_state_count":nonfinite,
                      "theta_bound_failure_count":theta_bad,"mass_failure_count":mass_bad}

    results={}
    pooled={}
    for g in ("R8","R4","R2"):
        run=runs[g]
        all_storage=[]; all_upper=[]; all_lower=[]; all_cum=[]; all_q=[]; all_th=[]; all_h=[]
        byhist={}
        sign_errors_total=0; reversal_mismatch_hist=0
        for h in HISTS:
            cum_c=cum_r=0.; es=[]; eu=[]; el=[]; ec=[]; eq=[]; eth=[]; ehd=[]
            cf={}; rf={}
            for step in range(1,65):
                c=run["states"][(h,step)]; r=ref["states"][(h,step)]
                cum_c+=float(c["BOTTOM_OUTWARD_EXCHANGE"]); cum_r+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
                es.append(float(c["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"]))
                eu.append(float(c["UPPER_STORAGE"])-float(r["UPPER_STORAGE"]))
                el.append(float(c["LOWER_STORAGE"])-float(r["LOWER_STORAGE"]))
                ec.append(cum_c-cum_r)
                q=float(c["BOTTOM_FLUX"])-float(r["BOTTOM_FLUX"]); eq.append(q)
                cf[step]=float(c["BOTTOM_FLUX"]); rf[step]=float(r["BOTTOM_FLUX"])
                te,he=mapped_profile_errors(run,ref,h,step); eth.extend(te); ehd.extend(he)
            sig=sum(sign(cf[s])!=sign(rf[s]) for s in rf if sign(rf[s])!=0)
            cr=reversals(cf); rr=reversals(rf)
            sign_errors_total+=sig; reversal_mismatch_hist+=int(cr!=rr)
            byhist[h]={
              "total_storage_error_cm":qstats(es),"upper_0_80_storage_error_cm":qstats(eu),
              "lower_80_160_storage_error_cm":qstats(el),"cumulative_bottom_exchange_error_cm":qstats(ec),
              "terminal_bottom_flux_error_cm_per_day":qstats(eq),"mapped_theta_error":qstats(eth),
              "mapped_head_error_cm":qstats(ehd),"bottom_flux_sign_error_count":sig,
              "R16_reversal_steps":rr,"coarse_reversal_steps":cr,
              "final_cumulative_bottom_exchange_error_cm":ec[-1],
              "R16_cumulative_bottom_exchange_cm":cum_r
            }
            all_storage+=es; all_upper+=eu; all_lower+=el; all_cum+=ec; all_q+=eq; all_th+=eth; all_h+=ehd
        nl=sum(int(r["NL"]) for r in run["states"].values())
        back=sum(int(r["BACKTRACK"]) for r in run["states"].values())
        fb=sum(str(r["FALLBACK"]).strip().lower() in ("t","true",".true.") for r in run["states"].values())
        results[g]={
          "nodes":run["n"],"integrity":integrity[g],"by_history":byhist,
          "pooled":{"total_storage_error_cm":qstats(all_storage),"upper_0_80_storage_error_cm":qstats(all_upper),
                    "lower_80_160_storage_error_cm":qstats(all_lower),"cumulative_bottom_exchange_error_cm":qstats(all_cum),
                    "terminal_bottom_flux_error_cm_per_day":qstats(all_q),"mapped_theta_error":qstats(all_th),
                    "mapped_head_error_cm":qstats(all_h),"bottom_flux_sign_error_count":sign_errors_total,
                    "history_reversal_sequence_mismatch_count":reversal_mismatch_hist},
          "computational_proxies":{"node_count":run["n"],"total_nonlinear_iterations":nl,
                                   "mean_nonlinear_iterations_per_interval":nl/768.,
                                   "total_backtracking_attempts":back,"research_reference_fallback_count":fb}
        }

    ref_nl=sum(int(r["NL"]) for r in ref["states"].values())
    ref_back=sum(int(r["BACKTRACK"]) for r in ref["states"].values())
    ref_fb=sum(str(r["FALLBACK"]).strip().lower() in ("t","true",".true.") for r in ref["states"].values())
    proxy_rows={"R16":{"nodes":16,"storage":0.0,"bottom":0.0,"q":0.0,"sign":0,
                        "nl":ref_nl,"back":ref_back}}
    for g,x in results.items():
        proxy_rows[g]={"nodes":x["nodes"],"storage":x["pooled"]["total_storage_error_cm"]["rmse"],
                       "bottom":x["pooled"]["cumulative_bottom_exchange_error_cm"]["rmse"],
                       "q":x["pooled"]["terminal_bottom_flux_error_cm_per_day"]["rmse"],
                       "sign":x["pooled"]["bottom_flux_sign_error_count"],
                       "nl":x["computational_proxies"]["total_nonlinear_iterations"],
                       "back":x["computational_proxies"]["total_backtracking_attempts"]}

    balance_frontier=frontier(proxy_rows,["nodes","storage","bottom"])
    transient_frontier=frontier(proxy_rows,["nodes","q","sign"])
    solverwork_balance_frontier=frontier(proxy_rows,["nl","storage","bottom"])
    surviving=[g for g in ("R8","R4","R2") if integrity[g]["pass"] and
               (g in balance_frontier or g in transient_frontier or g in solverwork_balance_frontier)]
    decision="COARSE_RICHARDS_REMAINS_SERIOUS_PHYSICAL_REDUCTION_CANDIDATE" if surviving else "COARSE_RICHARDS_NOT_COMPETITIVE_IN_TESTED_B01_DEVELOPMENT_DOMAIN"
    out={
      "schema":"swap5.f-romv2-d2.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D2",
      "decision":decision,"blind_confirmation":False,"application_acceptance":False,
      "reference":{"id":"R16","nodes":16,"integrity":integrity["R16"],
                   "computational_proxies":{"total_nonlinear_iterations":ref_nl,
                                            "mean_nonlinear_iterations_per_interval":ref_nl/768.,
                                            "total_backtracking_attempts":ref_back,
                                            "research_reference_fallback_count":ref_fb}},
      "candidates":results,
      "frontiers":{"structural_balance_nodes_storage_bottom":balance_frontier,
                   "structural_transient_nodes_q_sign":transient_frontier,
                   "solverwork_balance_nonlinear_iterations_storage_bottom":solverwork_balance_frontier,
                   "retained_coarse_candidates":surviving},
      "interpretation_rule":"Multi-objective development frontier only; no weighted score and no application threshold is inferred from D2.",
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"frontiers":out["frontiers"],
                      "reference":out["reference"],"candidate_pooled":{g:results[g]["pooled"] for g in results},
                      "candidate_proxies":{g:results[g]["computational_proxies"] for g in results}},sort_keys=True))
    return 0 if all(x["pass"] for x in integrity.values()) else 2

if __name__=="__main__":
    raise SystemExit(main())
