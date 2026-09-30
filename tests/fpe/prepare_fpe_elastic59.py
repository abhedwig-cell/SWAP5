#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--profile-id",required=True,type=int)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()

    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()
    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic55.py"),"profile",
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id",str(a.profile_id),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    s=s.replace(
        "use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &\n       evaluate_fpe_elastic53_reference_richards_temporal_indicator",
        "use mod_fpe_elastic59_reference_richards_temporal_indicator, only: &\n       evaluate_fpe_elastic59_reference_richards_temporal_indicator",1)

    old="""  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
"""
    new="""  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
  real(real64)::raw_head_inf,defect_head_inf,head_candidate
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL declaration anchor")
    s=s.replace(old,new,1)

    old="""  indicator_available=.false.
  indicator_binf=0.0_real64;indicator_raw=0.0_real64;indicator_defect=0.0_real64
"""
    new="""  indicator_available=.false.
  indicator_binf=0.0_real64;indicator_raw=0.0_real64;indicator_defect=0.0_real64
  raw_head_inf=0.0_real64;defect_head_inf=0.0_real64;head_candidate=0.0_real64
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL init anchor")
    s=s.replace(old,new,1)

    old="""    call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
"""
    new="""    call evaluate_fpe_elastic59_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator, &
         raw_head_inf,defect_head_inf,head_candidate)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL call anchor")
    s=s.replace(old,new,1)

    old="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
"""
    new="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|raw_head_inf=',raw_head_inf,'|defect_head_inf=',defect_head_inf,'|head_candidate=',head_candidate, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("ELASTIC55_BANK|","ELASTIC59_BANK|")
    s=s.replace("F_PE_ELASTIC55_EXEC=PASS","F_PE_ELASTIC59_EXEC=PASS")
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
