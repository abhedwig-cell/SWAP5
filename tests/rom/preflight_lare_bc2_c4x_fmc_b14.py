#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys

def load(path:pathlib.Path):
    spec=importlib.util.spec_from_file_location("c4x_fmc_b14",path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fmc-module",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_B14_FIXED_WATER_TABLE_RESPONSE"
    f=load(a.fmc_module)
    expected={k:float(v["lambda_B14"]) for k,v in p["initial_state_transfer"]["histories"].items()}
    checks={
      "TR":abs(f.TR-float(p["materials"]["response_blind_transfer_B14"]["theta_r"])),
      "TS":abs(f.TS-float(p["materials"]["response_blind_transfer_B14"]["theta_s"])),
      "ALPHA":abs(f.ALPHA-float(p["materials"]["response_blind_transfer_B14"]["alpha_per_cm"])),
      "N":abs(f.N-float(p["materials"]["response_blind_transfer_B14"]["n"])),
      "KS":abs(f.KS-float(p["materials"]["response_blind_transfer_B14"]["Ksat_cm_per_day"])),
      "ELL":abs(f.ELL-float(p["materials"]["response_blind_transfer_B14"]["mualem_lambda"]))
    }
    failure=None;histories={};maxmass=0.0;maxrelax=0.0
    if f.HISTS!=expected or f.NSTEPS!=1024 or f.NSUB!=9 or any(v!=0.0 for v in checks.values()):
        failure={"stage":"binding","error":"material/history/horizon binding mismatch","checks":checks}
    if failure is None:
        for hist,lam in expected.items():
            try:
                h=[lam*x for x in f.PSI]
                initial_max=max(h);initial_min=min(h)
                declared=float(p["initial_state_transfer"]["histories"][hist]["deepest_front_cm"])
                if abs(initial_max-declared)>1e-12:
                    raise ValueError(f"deepest-front invariant drift {initial_max-declared}")
                if not all(math.isfinite(x) and 0.0<x<=f.DEPTH for x in h):
                    raise ValueError("initial front outside column")
                s0=f.storage(h);cum=0.0;minh=initial_min;maxh=initial_max
                for _step in range(1,f.NSTEPS+1):
                    for _ in range(f.NSUB):
                        h,db,mass,relax=f.advance_substep(h)
                        cum+=db;maxmass=max(maxmass,abs(mass));maxrelax=max(maxrelax,abs(relax))
                        minh=min(minh,min(h));maxh=max(maxh,max(h))
                        if not all(math.isfinite(x) and 0.0<x<=f.DEPTH for x in h):
                            raise ValueError("front outside column")
                    q=f.qout_terminal(h)
                    if not math.isfinite(q):
                        raise ValueError("nonfinite terminal flux")
                s1=f.storage(h)
                histories[hist]={
                  "lambda_B14":lam,"initial_storage_cm":s0,"final_storage_cm":s1,
                  "cumulative_bottom_exchange_cm":cum,
                  "ledger_residual_cm":s1-s0+cum,
                  "minimum_front_height_cm":minh,"maximum_front_height_cm":maxh,
                  "terminal_bottom_flux_cm_per_day":f.qout_terminal(h)
                }
            except Exception as exc:
                failure={"stage":"advance","history":hist,"error":str(exc)}
                break
    passed=(failure is None and len(histories)==4 and maxmass<=1e-12 and
            all(abs(v["ledger_residual_cm"])<=1e-10 for v in histories.values()))
    out={
      "schema":"swap5.lare.bc2.c4x.fmc-b14-preflight.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4X",
      "decision":"C4X_FMC_B14_DOMAIN_PREFLIGHT_PASS" if passed else "C4X_FMC_B14_DOMAIN_BLOCKED_BEFORE_REFERENCE",
      "pass":passed,"reference_response_used":False,"failure":failure,
      "max_abs_substep_mass_residual_cm":maxmass,
      "max_abs_relaxation_storage_difference_cm":maxrelax,
      "histories":histories,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
