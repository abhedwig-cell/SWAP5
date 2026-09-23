#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys

MATERIALS=("B02","B05","B06","B11","B12","B16")
PURPOSES=("SURF_P","GW_LB")

def load(path):
    spec=importlib.util.spec_from_file_location("p4q",str(path))
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod
    spec.loader.exec_module(mod); return mod

def case(args):
    p4=load(args.p4_qualifier)
    ns=argparse.Namespace(
      exe=args.exe,reference64=args.reference64,reference128=args.reference128,
      materials=args.materials,base=args.base,p3_runner=args.p3_runner,p3_analyzer=args.p3_analyzer,
      outdir=args.outdir,purpose=args.purpose,material=args.material)
    p4.case(ns)

def aggregate(args):
    rows=[json.loads(p.read_text()) for p in sorted(args.input_dir.rglob("result.json"))]
    expected={(p,m) for p in PURPOSES for m in MATERIALS}
    ids={(r["purpose"],r["material"]) for r in rows}
    if len(rows)!=12 or ids!=expected:
        raise RuntimeError(f"expected 12 unique cases, got {len(rows)} {sorted(ids)}")
    cases=[]
    for r in rows:
        primary=r["routes"]["RK4_HALF"]
        cases.append({
          "purpose":r["purpose"],"material":r["material"],
          "panel_role":"extension" if r["material"] in ("B06","B12") else "established",
          "equation_conformance":r["equation_conformance"],
          "primary_status":primary["status"],
          "primary_wall_ratio_vs_R128":primary["wall_ratio_vs_same_job_R128"],
          "primary_metrics_vs_R128":primary["metrics_vs_R128"],
          "reference_comparator":r["reference_comparator"],
          "max_water_ledger_cm":primary.get("max_water_ledger_cm"),
          "fixed_0_01_status":r["routes"]["RK4_FIXED"]["status"],
          "fixed_0_01_failure":r["routes"]["RK4_FIXED"]["failure"],
          "python_heun":r["python_heun"]
        })
    eq=all(c["equation_conformance"]["status"]=="PASS" for c in cases)
    robust=all(c["primary_status"]=="QUALIFIED" and c["max_water_ledger_cm"] is not None and c["max_water_ledger_cm"]<=1e-8 for c in cases)
    speed=all(c["primary_wall_ratio_vs_R128"] is not None and c["primary_wall_ratio_vs_R128"]<1 for c in cases)
    extension=all(c["primary_wall_ratio_vs_R128"] is not None and c["primary_wall_ratio_vs_R128"]<1 for c in cases if c["panel_role"]=="extension")
    status="P5_ROBUST_FAST_RESEARCH_POLICY_QUALIFIED" if (eq and robust and speed and extension) else "P5_RESEARCH_POLICY_NOT_QUALIFIED"
    result={
      "schema":"swap5.rom-practical.p5.result.v1","workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P5",
      "status":status,
      "gates":{"equation_conformance":eq,"robustness":robust,"speed_all_cases":speed,"extension_speed":extension,
               "practical_research_viability":bool(eq and robust and speed and extension)},
      "summary":{
        "wall_ratio_vs_R128":{
          p:{m:next(c["primary_wall_ratio_vs_R128"] for c in cases if c["purpose"]==p and c["material"]==m) for m in MATERIALS}
          for p in PURPOSES
        },
        "completed_cases":sum(c["primary_status"]=="QUALIFIED" for c in cases),
        "total_cases":12
      },
      "cases":cases,
      "interpretation":[
        "The primary P5 numerical policy is compiled RK4 dt=0.005 day; P4 dt=0.01 remains a rejected prior policy.",
        "Qualification here is numerical/practical research viability, not application acceptance.",
        "Hydrological representation errors are retained explicitly and are not converted into a scalar overall score.",
        "Same-runner process speed ratios are workload-specific and non-portable."
      ],
      "P_ROM_ET_opened":False,"production_rom_authorized":False,"application_acceptance_adjudicated":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"gates":result["gates"],"summary":result["summary"]},sort_keys=True))

def main():
    ap=argparse.ArgumentParser(); sp=ap.add_subparsers(dest="mode",required=True)
    cp=sp.add_parser("case")
    for name in ("p4-qualifier","exe","reference64","reference128","materials","base","p3-runner","p3-analyzer","outdir"):
        cp.add_argument("--"+name,required=True,type=pathlib.Path)
    cp.add_argument("--purpose",required=True,choices=PURPOSES); cp.add_argument("--material",required=True,choices=MATERIALS)
    ag=sp.add_parser("aggregate"); ag.add_argument("--input-dir",required=True,type=pathlib.Path); ag.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args(); case(a) if a.mode=="case" else aggregate(a)
if __name__=="__main__": main()
