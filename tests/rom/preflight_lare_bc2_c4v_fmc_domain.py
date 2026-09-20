#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys

def load(path:pathlib.Path):
    spec=importlib.util.spec_from_file_location("c4v_fmc_materialized",path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--analyzer",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_ONE_DAY_RESPONSE_EXPOSURE"
    assert p["pre_reference_fmc_domain_preflight"]["before_any_C4V_reference_response"] is True
    f=load(a.analyzer)
    expected={k:float(v["lambda"]) for k,v in p["physical_workload"]["histories"].items()}
    if f.HISTS!=expected or f.NSTEPS!=1024 or f.NSUB!=9:
        raise SystemExit("C4V FMC materialization drift")

    maxmass=0.0;maxrelax=0.0;histories={};failure=None
    for hist,lam in expected.items():
        h=[lam*x for x in f.PSI]
        s0=f.storage(h)
        cum=0.0
        min_h=min(h);max_h=max(h)
        try:
            for step in range(1,f.NSTEPS+1):
                obs=0.0
                for _ in range(f.NSUB):
                    h,db,mass,relax=f.advance_substep(h)
                    obs+=db;cum+=db
                    maxmass=max(maxmass,abs(mass));maxrelax=max(maxrelax,relax)
                    min_h=min(min_h,min(h));max_h=max(max_h,max(h))
                    if not all(math.isfinite(x) and 0.0<x<=f.DEPTH for x in h):
                        raise ValueError("front bounds")
                q=f.qout_terminal(h)
                if not math.isfinite(q):
                    raise ValueError("terminal flux")
            s1=f.storage(h)
            histories[hist]={
              "lambda":lam,
              "steps":f.NSTEPS,
              "substeps":f.NSTEPS*f.NSUB,
              "initial_storage_cm":s0,
              "final_storage_cm":s1,
              "cumulative_bottom_outward_exchange_cm":cum,
              "ledger_residual_cm":s1-s0+cum,
              "terminal_bottom_flux_cm_per_day":f.qout_terminal(h),
              "minimum_front_height_cm":min_h,
              "maximum_front_height_cm":max_h
            }
        except Exception as exc:
            failure={"history":hist,"error":str(exc)}
            break

    passed=(failure is None and len(histories)==4 and maxmass<=1e-12 and
            all(abs(v["ledger_residual_cm"])<=1e-10 for v in histories.values()))
    out={
      "schema":"swap5.lare.bc2.c4v.fmc-domain-preflight.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4V",
      "decision":"C4V_FMC_ONE_DAY_DOMAIN_PREFLIGHT_PASS" if passed else "C4V_FMC_ONE_DAY_DOMAIN_PREFLIGHT_BLOCKED",
      "pass":passed,"reference_response_used":False,
      "failure":failure,"max_abs_substep_mass_residual_cm":maxmass,
      "max_abs_relaxation_storage_difference_cm":maxrelax,
      "histories":histories,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
