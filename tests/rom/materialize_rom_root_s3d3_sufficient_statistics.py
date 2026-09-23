#!/usr/bin/env python3
"""Instrument the qualified RA02R target harness for ROM-ROOT-S3-D3.

The diagnostic observes the committed fine-node hydraulic state immediately
before the unchanged Feddes root sink is formed. It reconstructs the same-state
layer Feddes functional from preregistered UTH and UJ root-weighted sufficient
statistics for the frozen U4/U8/R8/R16 partitions. It does not alter the sink,
hydraulic trial, Reference Richards, or persistent state.
"""
from __future__ import annotations

import argparse
import hashlib
import pathlib
import re

MARKER="ROM_ROOT_S3D3_FEDDES_SUFFICIENT_STATISTICS"

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("S3-D3 diagnostic already materialized")
    if "SEGMENT_START=" not in text or "SEGMENT_END=" not in text:
        raise SystemExit("S3-D3 requires segmented R2048_T32 harness")

    call_old="call evaluate_committed_root_sink(ih,p,state,forcing,root_rate)"
    if text.count(call_old)!=1:
        raise SystemExit(f"expected one root-evaluation call, found {text.count(call_old)}")
    text=text.replace(call_old,"call evaluate_committed_root_sink(ih,step,p,state,forcing,root_rate)",1)

    rx=re.compile(
        r"^  subroutine evaluate_committed_root_sink\(ih,p,state,forcing,total_rate\).*?"
        r"^  end subroutine evaluate_committed_root_sink\n",
        re.MULTILINE|re.DOTALL,
    )
    if len(rx.findall(text))!=1:
        raise SystemExit("evaluate_committed_root_sink block not unique")

    replacement=r"""  ! ROM_ROOT_S3D3_FEDDES_SUFFICIENT_STATISTICS
  subroutine s3d3_layer_bounds(rep,layer,lo_node,hi_node,nlayers)
    integer,intent(in) :: rep,layer
    integer,intent(out) :: lo_node,hi_node,nlayers
    integer :: left,right
    select case(rep)
    case(1) ! U4
      nlayers=4
      left=(layer-1)*512
      right=layer*512
    case(2) ! U8
      nlayers=8
      left=(layer-1)*256
      right=layer*256
    case(3) ! R8 = [0,90,100,...,160] cm
      nlayers=8
      if(layer==1)then
        left=0
        right=1152
      else
        left=1152+(layer-2)*128
        right=1152+(layer-1)*128
      end if
    case(4) ! R16
      nlayers=16
      left=(layer-1)*128
      right=layer*128
    case default
      nlayers=0
      left=0
      right=0
    end select
    lo_node=left+1
    hi_node=right
  end subroutine s3d3_layer_bounds

  subroutine evaluate_committed_root_sink(ih,step,p,state,forcing,total_rate)
    integer,intent(in) :: ih,step
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(out) :: total_rate
    integer,parameter :: NREP=4
    real(real64),parameter :: diagnostic_guard=2.9103830456733704e-11_real64
    type(root_water_uptake_parameters_t) :: parameters
    type(root_water_uptake_request_t) :: request
    type(root_water_uptake_flux_result_t) :: fluxes
    type(root_water_uptake_diagnostics_t) :: diagnostics
    type(process_hydraulic_view_t) :: view
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: rooted,j,kind,rep,layer,lo_node,hi_node,nlayers
    integer :: active_layers,transition_layers,mixed_layers
    real(real64) :: u,expected_potential,h3,h4,w,deltaf
    real(real64) :: unstressed,transition,dry,ht,jmargin
    real(real64) :: layer_exact,layer_uth,layer_uj,total_exact,total_uth,total_uj
    real(real64) :: err_layer_uth,err_layer_uj
    real(real64),save :: max_layer_uth(NREP)=0.0_real64,max_layer_uj(NREP)=0.0_real64
    real(real64),save :: max_total_uth(NREP)=0.0_real64,max_total_uj(NREP)=0.0_real64
    real(real64),save :: max_uth_uj(NREP)=0.0_real64,max_occ_identity(NREP)=0.0_real64
    integer,save :: count_tx=0,transition_layer_count(NREP)=0,mixed_layer_count(NREP)=0

    rooted=numnod/2
    call require(numnod==2048.and.rooted==1024,'ROM-ROOT S3-D3 qualified target geometry')
    kind=root_profile_kind(ih)
    call require(kind==1.or.kind==2,'LAREDYN0R C6R valid root profile')

    parameters%active_nodes=numnod
    parameters%hlim4=pressure_head_from_se(p,0.08_real64)
    parameters%hlim3l=pressure_head_from_se(p,0.35_real64)
    parameters%hlim3h=pressure_head_from_se(p,0.55_real64)
    parameters%adcrl=0.10_real64
    parameters%adcrh=0.50_real64

    request%potential_transpiration=potential_transpiration(ih)
    request%rooted_nodes=rooted
    allocate(request%cumulative_root_fraction(rooted+1))
    do j=0,rooted
      u=real(j,real64)/real(rooted,real64)
      if(kind==1)then
        request%cumulative_root_fraction(j+1)=2.0_real64*u-u*u
      else
        request%cumulative_root_fraction(j+1)=u
      end if
    end do

    call state%snapshot(snap,got)
    call require(got,'LAREDYN0R C6R committed root snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      view%active_nodes=physical%active_nodes
      allocate(view%pressure_head(numnod),view%water_content(numnod))
      view%pressure_head=physical%pressure_head
      view%water_content=physical%water_content
      view%ponding_depth=physical%ponding_depth
      view%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'LAREDYN0R C6R expected B110 root state')
    end select

    call evaluate_macro_feddes_drought_uptake(parameters,view,request,fluxes,diagnostics)
    call require(diagnostics%status==ROOT_UPTAKE_OK.and.diagnostics%evaluated,'LAREDYN0R C6R root process evaluated')
    expected_potential=request%potential_transpiration
    call require(abs(diagnostics%potential_uptake_total-expected_potential)<=1.0e-12_real64, &
         'LAREDYN0R C6R potential uptake reconciliation')
    h3=diagnostics%critical_pressure_head
    h4=parameters%hlim4

    count_tx=count_tx+1
    do rep=1,NREP
      total_exact=0.0_real64
      total_uth=0.0_real64
      total_uj=0.0_real64
      active_layers=0
      transition_layers=0
      mixed_layers=0
      call s3d3_layer_bounds(rep,1,lo_node,hi_node,nlayers)
      call require(nlayers>0,'ROM-ROOT S3-D3 valid representation')
      do layer=1,nlayers
        call s3d3_layer_bounds(rep,layer,lo_node,hi_node,nlayers)
        if(lo_node>rooted)cycle
        hi_node=min(hi_node,rooted)
        deltaf=request%cumulative_root_fraction(hi_node+1)-request%cumulative_root_fraction(lo_node)
        if(deltaf<=0.0_real64)cycle
        active_layers=active_layers+1
        unstressed=0.0_real64
        transition=0.0_real64
        dry=0.0_real64
        ht=0.0_real64
        jmargin=0.0_real64
        layer_exact=0.0_real64
        do j=lo_node,hi_node
          w=request%cumulative_root_fraction(j+1)-request%cumulative_root_fraction(j)
          layer_exact=layer_exact+w*diagnostics%drought_reduction_factor(j)
          if(view%pressure_head(j)<h4)then
            dry=dry+w
          else if(view%pressure_head(j)<=h3)then
            transition=transition+w
            ht=ht+w*view%pressure_head(j)
            jmargin=jmargin+w*(view%pressure_head(j)-h4)
          else
            unstressed=unstressed+w
          end if
        end do
        max_occ_identity(rep)=max(max_occ_identity(rep),abs((unstressed+transition+dry)-deltaf))
        layer_uth=unstressed+(h4*transition-ht)/(h4-h3)
        layer_uj=unstressed+jmargin/(h3-h4)
        err_layer_uth=layer_uth-layer_exact
        err_layer_uj=layer_uj-layer_exact
        max_layer_uth(rep)=max(max_layer_uth(rep),abs(err_layer_uth))
        max_layer_uj(rep)=max(max_layer_uj(rep),abs(err_layer_uj))
        max_uth_uj(rep)=max(max_uth_uj(rep),abs(layer_uth-layer_uj))
        if(transition>0.0_real64)transition_layers=transition_layers+1
        if(merge(1,0,unstressed>0.0_real64)+merge(1,0,transition>0.0_real64)+merge(1,0,dry>0.0_real64)>=2) &
             mixed_layers=mixed_layers+1
        total_exact=total_exact+layer_exact
        total_uth=total_uth+layer_uth
        total_uj=total_uj+layer_uj
      end do
      transition_layer_count(rep)=transition_layer_count(rep)+transition_layers
      mixed_layer_count(rep)=mixed_layer_count(rep)+mixed_layers
      max_total_uth(rep)=max(max_total_uth(rep),abs(total_uth-total_exact))
      max_total_uj(rep)=max(max_total_uj(rep),abs(total_uj-total_exact))
      call require(abs(total_exact-fluxes%actual_uptake_total/expected_potential)<=diagnostic_guard, &
           'ROM-ROOT S3-D3 exact/process identity')
      call require(abs(total_uth-total_exact)<=diagnostic_guard,'ROM-ROOT S3-D3 UTH identity')
      call require(abs(total_uj-total_exact)<=diagnostic_guard,'ROM-ROOT S3-D3 UJ identity')
    end do

    if(step==SEGMENT_END)then
      do rep=1,NREP
        select case(rep)
        case(1)
          write(*,'(*(g0))') 'ROM_ROOT_S3D3_SUMMARY|CASE=',trim(case_label(ih)),'|REP=U4', &
               '|COUNT=',count_tx,'|MAX_LAYER_UTH=',max_layer_uth(rep),'|MAX_LAYER_UJ=',max_layer_uj(rep), &
               '|MAX_TOTAL_UTH=',max_total_uth(rep),'|MAX_TOTAL_UJ=',max_total_uj(rep), &
               '|MAX_UTH_UJ=',max_uth_uj(rep),'|MAX_OCC_ID=',max_occ_identity(rep), &
               '|TRANSITION_LAYERS=',transition_layer_count(rep),'|MIXED_LAYERS=',mixed_layer_count(rep)
        case(2)
          write(*,'(*(g0))') 'ROM_ROOT_S3D3_SUMMARY|CASE=',trim(case_label(ih)),'|REP=U8', &
               '|COUNT=',count_tx,'|MAX_LAYER_UTH=',max_layer_uth(rep),'|MAX_LAYER_UJ=',max_layer_uj(rep), &
               '|MAX_TOTAL_UTH=',max_total_uth(rep),'|MAX_TOTAL_UJ=',max_total_uj(rep), &
               '|MAX_UTH_UJ=',max_uth_uj(rep),'|MAX_OCC_ID=',max_occ_identity(rep), &
               '|TRANSITION_LAYERS=',transition_layer_count(rep),'|MIXED_LAYERS=',mixed_layer_count(rep)
        case(3)
          write(*,'(*(g0))') 'ROM_ROOT_S3D3_SUMMARY|CASE=',trim(case_label(ih)),'|REP=R8', &
               '|COUNT=',count_tx,'|MAX_LAYER_UTH=',max_layer_uth(rep),'|MAX_LAYER_UJ=',max_layer_uj(rep), &
               '|MAX_TOTAL_UTH=',max_total_uth(rep),'|MAX_TOTAL_UJ=',max_total_uj(rep), &
               '|MAX_UTH_UJ=',max_uth_uj(rep),'|MAX_OCC_ID=',max_occ_identity(rep), &
               '|TRANSITION_LAYERS=',transition_layer_count(rep),'|MIXED_LAYERS=',mixed_layer_count(rep)
        case(4)
          write(*,'(*(g0))') 'ROM_ROOT_S3D3_SUMMARY|CASE=',trim(case_label(ih)),'|REP=R16', &
               '|COUNT=',count_tx,'|MAX_LAYER_UTH=',max_layer_uth(rep),'|MAX_LAYER_UJ=',max_layer_uj(rep), &
               '|MAX_TOTAL_UTH=',max_total_uth(rep),'|MAX_TOTAL_UJ=',max_total_uj(rep), &
               '|MAX_UTH_UJ=',max_uth_uj(rep),'|MAX_OCC_ID=',max_occ_identity(rep), &
               '|TRANSITION_LAYERS=',transition_layer_count(rep),'|MIXED_LAYERS=',mixed_layer_count(rep)
        end select
      end do
    end if

    forcing%root_extraction_sink=fluxes%root_extraction_sink
    total_rate=fluxes%actual_uptake_total
    call require(ieee_is_finite(total_rate).and.total_rate>=0.0_real64.and. &
         total_rate<=request%potential_transpiration+1.0e-12_real64,'LAREDYN0R C6R bounded actual uptake')
    if(allocated(snap))deallocate(snap)
  end subroutine evaluate_committed_root_sink
"""
    text=rx.sub(replacement,text,count=1)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(text)
    print(f"input_sha256={sha256(args.input)}")
    print(f"output_sha256={sha256(args.output)}")
    print("ROM_ROOT_S3D3_MATERIALIZED=TRUE")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
