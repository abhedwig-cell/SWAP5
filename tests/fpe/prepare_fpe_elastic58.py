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

    old="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
"""
    new="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::storage_signed,storage_l1,qbot_diff,qbot_rel,qbot_scale
  real(real64)::delta_theta(N)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL declaration anchor")
    s=s.replace(old,new,1)

    old="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
"""
    new="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
  storage_signed=0.0_real64;storage_l1=0.0_real64;qbot_diff=0.0_real64;qbot_rel=0.0_real64
  qbot_scale=0.0_real64;delta_theta=0.0_real64
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL init anchor")
    s=s.replace(old,new,1)

    old="""    dtheta_inf=maxval(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content))
    itheta=maxloc(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    storage_half=sum(res_half2%candidate_state%water_content*p%dz)
"""
    new="""    delta_theta=res_full%candidate_state%water_content-res_half2%candidate_state%water_content
    dtheta_inf=maxval(abs(delta_theta))
    itheta=maxloc(abs(delta_theta),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    storage_half=sum(res_half2%candidate_state%water_content*p%dz)
    storage_signed=abs(sum(p%dz*delta_theta))
    storage_l1=sum(p%dz*abs(delta_theta))
    qbot_diff=abs(res_full%bottom_flux-res_half2%bottom_flux)
    qbot_scale=max(abs(res_full%bottom_flux),abs(res_half2%bottom_flux),1.0e-30_real64)
    qbot_rel=qbot_diff/qbot_scale
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL calc anchor")
    s=s.replace(old,new,1)

    old="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
"""
    new="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
    call req(ieee_is_finite(storage_signed).and.ieee_is_finite(storage_l1).and.ieee_is_finite(qbot_diff).and. &
         ieee_is_finite(qbot_rel),'finite endpoint metrics')
    call req(storage_signed>=0.0_real64.and.storage_l1>=0.0_real64.and.qbot_diff>=0.0_real64.and.qbot_rel>=0.0_real64, &
         'nonnegative endpoint metrics')
    call req(storage_signed<=storage_l1+64.0_real64*epsilon(1.0_real64)*max(1.0_real64,storage_l1), &
         'signed storage bounded by unsigned')
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL finite anchor")
    s=s.replace(old,new,1)

    old="""       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
"""
    new="""       '|storage_half=',storage_half,'|storage_signed=',storage_signed,'|storage_l1=',storage_l1, &
       '|qbot_full=',res_full%bottom_flux,'|qbot_half=',res_half2%bottom_flux,'|qbot_diff=',qbot_diff, &
       '|qbot_rel=',qbot_rel,'|exact_identity=',exact_identity, &
       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("ELASTIC55_BANK|","ELASTIC58_METRIC|")
    s=s.replace("F_PE_ELASTIC55_EXEC=PASS","F_PE_ELASTIC58_EXEC=PASS")
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC58_PREP=PASS")

if __name__=="__main__":
    main()
