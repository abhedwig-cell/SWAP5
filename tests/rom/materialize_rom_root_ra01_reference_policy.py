#!/usr/bin/env python3
"""Materialize ROM-ROOT-RA01 research-only Reference policy.

Input is the already frozen C6R root-active harness. RA01 does not reopen C6R.
It applies the independently qualified PUB-P2E20 representation-floor total
balance discriminator prospectively before each root-active Reference trial:

    F_repr = sum_i dz_i * spacing(theta_s_i)
    total_tol_rate = max(original_total_tol, F_repr / dt)

All local/head tolerances, iteration/backtracking controls, physics, prescribed
root sink semantics and hard transaction mass gate remain unchanged. The
existing root-active fail-closed block remains in place, so there is no
second-attempt rescue if the floor-aware first solve fails.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MARKER="ROM_ROOT_RA01_P2E20_REPRESENTATION_FLOOR"

def git_blob(data:bytes)->str:
    h=hashlib.sha1()
    h.update(f"blob {len(data)}\0".encode())
    h.update(data)
    return h.hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    ap.add_argument("--manifest",type=Path)
    args=ap.parse_args()

    before=args.input.read_text()
    if MARKER in before:
        raise SystemExit("RA01 policy already materialized")

    anchor="""    call prospective_bound(state,p,rep_bound,bound_ok)
    call require(bound_ok.and.rep_bound>0.0_real64,'LAREDYN0R prospective representation bound')

    call sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
"""
    replacement="""    call prospective_bound(state,p,rep_bound,bound_ok)
    call require(bound_ok.and.rep_bound>0.0_real64,'LAREDYN0R prospective representation bound')

    if(p%root_extraction_active)then
      call rom_root_ra01_total_bound(p,rep_bound,bound_ok)
      call require(bound_ok.and.rep_bound>0.0_real64,'ROM-ROOT RA01 external representation bound')
      p%total_balance_tolerance=max(original_total_tol,rep_bound/(t1-t0))
    end if

    call sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
"""
    text=one(before,anchor,replacement,"prospective RA01 policy insertion")

    helper="""  subroutine rom_root_ra01_total_bound(p,bound,ok)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: bound
    logical,intent(out) :: ok
    integer :: i
    real(real64) :: theta_s
    bound=0.0_real64;ok=.false.
    if(.not.allocated(p%dz).or..not.allocated(p%cofgen))return
    if(size(p%dz)/=numnod.or.size(p%cofgen,2)/=numnod)return
    do i=1,numnod
      theta_s=p%cofgen(2,i)
      if(.not.ieee_is_finite(theta_s).or.theta_s<=0.0_real64)return
      if(.not.ieee_is_finite(p%dz(i)).or.p%dz(i)<=0.0_real64)return
      bound=bound+p%dz(i)*spacing(theta_s)
    end do
    ok=ieee_is_finite(bound).and.bound>0.0_real64
  end subroutine rom_root_ra01_total_bound

"""
    text=one(text,"  subroutine prospective_bound(state,p,bound,ok)\n",helper+"  subroutine prospective_bound(state,p,bound,ok)\n","RA01 bound helper")

    base_marker="  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\\n"
    segmented_marker="  write(*,'(A)') 'LAREDYN0R_C6R_SEGMENTED_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\\n"
    if base_marker in text:
        text=one(
            text,
            base_marker,
            base_marker+"  write(*,'(A)') 'ROM_ROOT_RA01_P2E20_REPRESENTATION_FLOOR=TRUE'\\n",
            "RA01 base completion marker"
        )
    elif segmented_marker in text:
        text=one(
            text,
            segmented_marker,
            segmented_marker+"  write(*,'(A)') 'ROM_ROOT_RA01_P2E20_REPRESENTATION_FLOOR=TRUE'\\n",
            "RA01 segmented completion marker"
        )
    else:
        raise SystemExit("RA01 completion marker source not found")

    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(text)

    manifest={
      "schema":"swap5.rom_root.ra01.materialization.v1",
      "policy":"PUB_P2E20_REPRESENTATION_FLOOR",
      "external_authority_head":"341b383c3e1872e9b5421c4f8742749259d9def4",
      "external_result_blob":"e6586623ec7c9d9f0d34fb741687deb8601f0615",
      "formula":"F_repr_cm=sum_i(dz_i*spacing(theta_s_i)); total_tol_rate=max(1e-12,F_repr_cm/dt_day)",
      "safety_factor":1,
      "root_active_only":True,
      "second_attempt_rescue":False,
      "max_iterations_changed":False,
      "max_backtracking_changed":False,
      "compartment_tolerance_changed":False,
      "head_tolerances_changed":False,
      "hard_mass_gate_changed":False,
      "production_source_changed":False,
      "input_git_blob":git_blob(before.encode()),
      "output_git_blob":git_blob(text.encode()),
      "output_sha256":hashlib.sha256(text.encode()).hexdigest()
    }
    if args.manifest:
      args.manifest.parent.mkdir(parents=True,exist_ok=True)
      args.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
