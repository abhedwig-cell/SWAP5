#!/usr/bin/env python3
from __future__ import annotations
import argparse
import subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()

    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()
    cmd=[
        "python3",str(root/"tests/fpe/prepare_fpe_elastic50.py"),
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve()),
    ]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")

    s=fixture.read_text(encoding="utf-8")
    old_decl="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  integer::ih,itheta,i
"""
    new_decl="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::h_rms_dz,storage_l1,storage_signed,storage_l1_rel,storage_signed_rel,storage_denom
  real(real64)::delta_h(N),delta_theta(N)
  integer::ih,itheta,i
"""
    if old_decl not in s:
        raise SystemExit("F_PE_ELASTIC51_FAIL declaration anchor")
    s=s.replace(old_decl,new_decl,1)

    old_init="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
"""
    new_init="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
  h_rms_dz=0.0_real64;storage_l1=0.0_real64;storage_signed=0.0_real64
  storage_l1_rel=0.0_real64;storage_signed_rel=0.0_real64;storage_denom=0.0_real64
  delta_h=0.0_real64;delta_theta=0.0_real64
"""
    if old_init not in s:
        raise SystemExit("F_PE_ELASTIC51_FAIL init anchor")
    s=s.replace(old_init,new_init,1)

    old_calc="""    dh_inf=maxval(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head))
    ih=maxloc(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head),dim=1)
    dtheta_inf=maxval(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content))
    itheta=maxloc(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    storage_half=sum(res_half2%candidate_state%water_content*p%dz)
"""
    new_calc="""    delta_h=res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head
    delta_theta=res_full%candidate_state%water_content-res_half2%candidate_state%water_content
    dh_inf=maxval(abs(delta_h))
    ih=maxloc(abs(delta_h),dim=1)
    dtheta_inf=maxval(abs(delta_theta))
    itheta=maxloc(abs(delta_theta),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    storage_half=sum(res_half2%candidate_state%water_content*p%dz)
    h_rms_dz=sqrt(sum(p%dz*delta_h*delta_h)/sum(p%dz))
    storage_l1=sum(p%dz*abs(delta_theta))
    storage_signed=abs(sum(p%dz*delta_theta))
    storage_denom=max(abs(storage_full),abs(storage_half))
    if(storage_denom>0.0_real64)then
      storage_l1_rel=storage_l1/storage_denom
      storage_signed_rel=storage_signed/storage_denom
    end if
"""
    if old_calc not in s:
        raise SystemExit("F_PE_ELASTIC51_FAIL calc anchor")
    s=s.replace(old_calc,new_calc,1)

    old_req="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
"""
    new_req="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
    call req(ieee_is_finite(h_rms_dz).and.ieee_is_finite(storage_l1).and.ieee_is_finite(storage_signed).and. &
         ieee_is_finite(storage_l1_rel).and.ieee_is_finite(storage_signed_rel),'finite candidate metrics')
    call req(h_rms_dz>=0.0_real64.and.storage_l1>=0.0_real64.and.storage_signed>=0.0_real64,'nonnegative candidate metrics')
    call req(storage_signed<=storage_l1+64.0_real64*epsilon(1.0_real64)*max(1.0_real64,storage_l1), &
         'signed storage bounded by unsigned')
"""
    if old_req not in s:
        raise SystemExit("F_PE_ELASTIC51_FAIL request anchor")
    s=s.replace(old_req,new_req,1)

    old_write="""       '|dtheta_node=',itheta,'|dpond=',dpond,'|dgwl=',dgwl,'|storage_full=',storage_full, &
       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
"""
    new_write="""       '|dtheta_node=',itheta,'|dpond=',dpond,'|dgwl=',dgwl,'|storage_full=',storage_full, &
       '|storage_half=',storage_half,'|h_rms_dz=',h_rms_dz,'|storage_l1=',storage_l1, &
       '|storage_signed=',storage_signed,'|storage_l1_rel=',storage_l1_rel, &
       '|storage_signed_rel=',storage_signed_rel,'|exact_identity=',exact_identity, &
"""
    if old_write not in s:
        raise SystemExit("F_PE_ELASTIC51_FAIL write anchor")
    s=s.replace(old_write,new_write,1)
    s=s.replace("ELASTIC50_DIFF|","ELASTIC51_METRIC|")
    s=s.replace("F_PE_ELASTIC50_EXEC=PASS","F_PE_ELASTIC51_EXEC=PASS")
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC51_PREP=PASS")

if __name__=="__main__":
    main()
