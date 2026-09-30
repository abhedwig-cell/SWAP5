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
        "--geometry-json",str(Path(a.geometry_json).resolve()),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")

    s=fixture.read_text(encoding="utf-8")
    old="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
"""
    new="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::full_storage0,full_storage1,full_total_in,full_total_out,full_ledger_mass
  logical::full_mass_available
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC57_FAIL declaration anchor")
    s=s.replace(old,new,1)

    old="""  call solver_full%solve(req_full,ws_full,res_full)

  indicator_available=.false.
"""
    new="""  call solver_full%solve(req_full,ws_full,res_full)

  full_mass_available=.false.
  full_storage0=0.0_real64;full_storage1=0.0_real64
  full_total_in=0.0_real64;full_total_out=0.0_real64;full_ledger_mass=0.0_real64
  if(res_full%status==SW_SOLVE_CONVERGED)then
    full_storage0=sum(water*p%dz)+max(0.0_real64,h0)
    full_storage1=sum(res_full%candidate_state%water_content*p%dz)+res_full%candidate_state%ponding_depth
    full_total_in=max(0.0_real64,-res_full%top_flux)*dt+max(0.0_real64,res_full%bottom_flux)*dt
    full_total_out=max(0.0_real64,res_full%top_flux)*dt+max(0.0_real64,-res_full%bottom_flux)*dt
    full_ledger_mass=full_storage1-full_storage0-(full_total_in-full_total_out)
    full_mass_available=ieee_is_finite(full_ledger_mass)
  end if

  indicator_available=.false.
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC57_FAIL solve anchor")
    s=s.replace(old,new,1)

    old="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
"""
    new="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|full_mass_available=',full_mass_available,'|full_ledger_mass=',full_ledger_mass, &
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC57_FAIL output anchor")
    s=s.replace(old,new,1)

    s=s.replace("ELASTIC55_BANK|","ELASTIC57_BANK|",1)
    s=s.replace("F_PE_ELASTIC55_EXEC=PASS","F_PE_ELASTIC57_EXEC=PASS",1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC57_PREP=PASS")

if __name__=="__main__":
    main()
