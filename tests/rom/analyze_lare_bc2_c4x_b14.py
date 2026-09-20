#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys

HERE=pathlib.Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

def patch_b14(c4v,p):
    mat=p["materials"]["blind_transfer_B14"]
    c4v.TR=float(mat["theta_r"]);c4v.TS=float(mat["theta_s"])
    c4v.ALPHA=float(mat["alpha_per_cm"]);c4v.N=float(mat["n"])
    c4v.M=1.0-1.0/c4v.N;c4v.KS=float(mat["Ksat_cm_per_day"]);c4v.ELL=float(mat["mualem_lambda"])
    c4v.DTHETA=(c4v.TS-c4v.TR)/c4v.NBINS;c4v.THETA_I=c4v.TR+c4v.I*c4v.DTHETA
    c4v.HISTS={k:float(v["lambda_B14"]) for k,v in p["initial_state_transfer"]["histories"].items()}
    c4v.THETA=[c4v.TR+j*c4v.DTHETA for j in range(c4v.J0,c4v.J1+1)]
    c4v.PSI=[c4v.psi_scalar(t) for t in c4v.THETA]
    b=c4v.bc1
    b.THETA_R=c4v.TR;b.THETA_S=c4v.TS;b.ALPHA=c4v.ALPHA;b.N_VG=c4v.N;b.M_VG=c4v.M;b.KS=c4v.KS;b.LAMBDA=c4v.ELL

def profile_cross(a,b,gwkeys,tol=1e-12):
    return c4v.no_worse(a,b,gwkeys,tol) and float(a["mapped_theta_rmse"])<=float(b["mapped_theta_rmse"])+tol

def min_dim(members,flag):
    xs=[int(m["dimension"]) for m in members if m.get(flag)]
    return None if not xs else min(xs)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-module",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-preflight",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4v-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4w-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text());pre=json.loads(a.fmc_preflight.read_text())
    c4vclose=json.loads(a.c4v_closeout.read_text());c4w=json.loads(a.c4w_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_B14_FIXED_WATER_TABLE_RESPONSE"
    assert pre["decision"]=="C4X_FMC_B14_DOMAIN_PREFLIGHT_PASS" and pre["pass"] is True
    assert c4vclose["decision"]=="C4V_HIGHER_DIMENSION_GW_FRONTIER_PERSISTS"
    assert c4w["decision"]=="C4W_SPURIOUS_REVERSAL_MAGNITUDE_CHARACTERIZED"
    global c4v
    c4v=load("c4v_for_c4x",HERE/"analyze_lare_bc2_c4v_one_day.py")
    patch_b14(c4v,p)
    fmc=load("c4x_fmc_runtime",a.fmc_module)
    r16=c4v.parse_ref(a.r16);r2=c4v.parse_ref(a.r2)
    if r16["n"]!=16 or r2["n"]!=2:
        raise SystemExit("C4X geometry mismatch")
    expected={k:float(v["lambda_B14"]) for k,v in p["initial_state_transfer"]["histories"].items()}
    for h,lam in expected.items():
        for ref in (r16,r2):
            if abs(float(ref["initial"][h]["LAMBDA"])-lam)>1e-15:
                raise SystemExit(f"C4X lambda mismatch {h}")
    ladder=list(p["representations"]["LARE"]["transferred_lower_zone_ladder"])
    controls=list(p["representations"]["LARE"]["frozen_placement_controls"])
    memberspec=ladder+controls
    lare=[c4v.run_lare(m,r16) for m in memberspec]
    r2route=c4v.run_r2(r2,r16);fmcroute=c4v.run_fmc(fmc,r16)
    summaries={"R2":c4v.summarize(r2route),"FMC":c4v.summarize(fmcroute)}
    for m in lare:
        if m["status"]=="QUALIFIED":
            summaries["LARE_"+m["id"]]=c4v.summarize(m)
    r16ctrl=next(m for m in lare if m["id"]=="R16")
    integrity=(r16ctrl["status"]=="QUALIFIED"
      and len(lare)==len(memberspec)
      and all(m["status"]!="QUALIFIED" or m["max_abs_water_ledger_cm"]<=float(p["hard_gates"]["lare_qualified_member_max_abs_water_ledger_cm"]) for m in lare))
    reduced=[m for m in lare if int(m["dimension"])<16 and m["status"]=="QUALIFIED"]
    prospective=[128,256,512,1024];gw=c4v.GW6
    persistence={}
    for m in reduced:
        key="LARE_"+m["id"]
        cr={str(cp):c4v.no_worse(summaries[key][str(cp)],summaries["R2"][str(cp)],gw) for cp in prospective}
        cf={str(cp):c4v.no_worse(summaries[key][str(cp)],summaries["FMC"][str(cp)],gw) for cp in prospective}
        p1024=summaries[key]["1024"]
        persistence[m["id"]]={
          "R2_by_checkpoint":cr,"FMC_by_checkpoint":cf,
          "crosses_R2_all":all(cr.values()),"crosses_FMC_all":all(cf.values()),
          "crosses_both_all":all(cr.values()) and all(cf.values()),
          "crosses_R2_PROFILE_1024":profile_cross(p1024,summaries["R2"]["1024"],gw),
          "crosses_FMC_PROFILE_1024":profile_cross(p1024,summaries["FMC"]["1024"],gw)
        }
    both=[m for m in reduced if persistence[m["id"]]["crosses_both_all"]]
    r2ok=[m for m in reduced if persistence[m["id"]]["crosses_R2_all"]]
    if not integrity:
        decision="C4X_REFERENCE_OR_REPRESENTATION_BLOCKED"
    elif both:
        decision="C4X_B14_GW_TRANSFER_FRONTIER_PRESENT"
    elif r2ok:
        decision="C4X_B14_R2_RELATIVE_FRONTIER_ONLY"
    else:
        decision="C4X_B14_REDUCED_GW_FRONTIER_NOT_PRESERVED"
    ladder_ids={m["id"] for m in ladder if int(m["dimension"])<16}
    ladder_reduced=[m for m in reduced if m["id"] in ladder_ids]
    controls_reduced=[m for m in reduced if m["id"] not in ladder_ids]
    out={
      "schema":"swap5.lare.bc2.c4x.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4X",
      "decision":decision,
      "material":"B14",
      "integrity":{
        "pass":integrity,"fmc_preflight_pass":pre["pass"],
        "R16_operator_control_status":r16ctrl["status"],
        "qualified_reduced_count":len(reduced),
        "maximum_lare_water_ledger_cm":max([m["max_abs_water_ledger_cm"] for m in lare if m["status"]=="QUALIFIED"] or [0.0])
      },
      "persistent_crossing":{
        "both_all_members":[m["id"] for m in both],
        "R2_all_members":[m["id"] for m in r2ok],
        "minimum_any_dimension_both":min([m["dimension"] for m in both],default=None),
        "transferred_ladder_both":[m["id"] for m in ladder_reduced if persistence[m["id"]]["crosses_both_all"]],
        "minimum_transferred_ladder_dimension_both":min([m["dimension"] for m in ladder_reduced if persistence[m["id"]]["crosses_both_all"]],default=None),
        "placement_controls_both":[m["id"] for m in controls_reduced if persistence[m["id"]]["crosses_both_all"]]
      },
      "profile_1024":{
        "crossing_R2":[m["id"] for m in reduced if persistence[m["id"]]["crosses_R2_PROFILE_1024"]],
        "crossing_FMC":[m["id"] for m in reduced if persistence[m["id"]]["crosses_FMC_PROFILE_1024"]],
        "minimum_dimension_R2":min_dim([{**m,**persistence[m["id"]]} for m in reduced],"crosses_R2_PROFILE_1024"),
        "minimum_dimension_FMC":min_dim([{**m,**persistence[m["id"]]} for m in reduced],"crosses_FMC_PROFILE_1024")
      },
      "placement_comparison":{
        "dimension4":{k:summaries["LARE_"+k]["1024"] for k in ("R4","P4_TOP_LOWER","U4") if "LARE_"+k in summaries},
        "dimension8":{k:summaries["LARE_"+k]["1024"] for k in ("R8","U8") if "LARE_"+k in summaries}
      },
      "summaries":summaries,
      "lare_member_status":[{k:m[k] for k in ("id","dimension","status","failure","max_abs_water_ledger_cm","max_corrector_iterations")} for m in lare],
      "persistence_by_member":persistence,
      "hypotheses":{
        "H_R8_MATERIAL_TRANSFER_exact":persistence.get("R8",{}).get("crosses_both_all",False) and
          min([m["dimension"] for m in ladder_reduced if persistence[m["id"]]["crosses_both_all"]],default=None)==8,
        "H_LAYER_PLACEMENT_MATTERS":"REPORT_COMPONENTWISE",
        "H_PROFILE_REQUIRES_MORE_STATE":"REPORT_COMPONENTWISE"
      },
      "interpretation":[
        "C4X transfers the fixed-water-table one-day laboratory from B01 to B14 using a preregistered constitutive front-height scaling before any B14 Reference response.",
        "The B01 lower-zone ladder is tested without retuning and pre-existing P4/U4/U8 placement controls are reported separately.",
        "Comparator-relative crossing is not cross-material generality or application acceptance.",
        "No lower-boundary semantics, coupling architecture, timing or production code is changed."
      ],
      "application_acceptance_adjudicated":False,
      "performance_comparison_authorized":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,"integrity":out["integrity"],
      "persistent_crossing":out["persistent_crossing"],
      "profile_1024":out["profile_1024"],
      "placement4":out["placement_comparison"]["dimension4"],
      "placement8":out["placement_comparison"]["dimension8"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
