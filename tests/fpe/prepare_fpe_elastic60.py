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

    old_decl="""  real(real64)::indicator_binf,indicator_raw,indicator_defect
"""
    new_decl="""  real(real64)::indicator_binf,indicator_raw,indicator_defect,direct_dinf
"""
    if old_decl not in s: raise SystemExit("F_PE_ELASTIC60_FAIL fixture declaration")
    s=s.replace(old_decl,new_decl,1)

    old_init="""  indicator_binf=0.0_real64;indicator_raw=0.0_real64;indicator_defect=0.0_real64
"""
    new_init="""  indicator_binf=0.0_real64;indicator_raw=0.0_real64;indicator_defect=0.0_real64;direct_dinf=0.0_real64
"""
    if old_init not in s: raise SystemExit("F_PE_ELASTIC60_FAIL fixture init")
    s=s.replace(old_init,new_init,1)

    old_call="""    call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
"""
    new_call="""    call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator,direct_dinf)
"""
    if old_call not in s: raise SystemExit("F_PE_ELASTIC60_FAIL fixture indicator call")
    s=s.replace(old_call,new_call,1)

    old_out="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
"""
    new_out="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect,'|direct_dinf=',direct_dinf, &
"""
    if old_out not in s: raise SystemExit("F_PE_ELASTIC60_FAIL fixture output")
    s=s.replace(old_out,new_out,1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC60_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
