#!/usr/bin/env python3
"""Instrument the qualified RA02R target for the preregistered S3-D2 support sweep.

All quantities are diagnostic. The prescribed fine-node root sink and the
Reference hydraulic trajectory remain exactly those of RA02R.
"""
from __future__ import annotations

import argparse
import hashlib
import pathlib
import re

MARKER="ROM_ROOT_S3D2_DYADIC_SUPPORT_SWEEP"

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("S3-D2 diagnostic already materialized")
    if "SEGMENT_START=" not in text or "SEGMENT_END=" not in text:
        raise SystemExit("S3-D2 requires the segmented R2048_T32 harness")

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

    replacement=r"""  ! ROM_ROOT_S3D2_DYADIC_SUPPORT_SWEEP
  pure real(real64) function s3d2_alpha(h,h3,h4) result(value)
    real(real64),intent(in) :: h,h3,h4
    value=1.0_real64
    if(h<h4)then
      value=0.0_real64
    else if(h<=h3)then
      value=(h4-h)/(h4-h3)
    end if
  end function s3d2_alpha

  subroutine evaluate_committed_root_sink(ih,step,p,state,forcing,total_rate)
    integer,intent(in) :: ih,step
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(out) :: total_rate
    integer,parameter :: NSUPPORT=8
    integer,parameter :: support_nodes(NSUPPORT)=[128,64,32,16,8,4,2,1]
    real(real64),parameter :: diagnostic_guard=2.9103830456733704e-11_real64
    type(root_water_uptake_parameters_t) :: parameters
    type(root_water_uptake_request_t) :: request
    type(root_water_uptake_flux_result_t) :: fluxes
    type(root_water_uptake_diagnostics_t) :: diagnostics
    type(process_hydraulic_view_t) :: view
    class(transaction_state_t),allocatable :: snap
    logical :: got,cross3,cross4,cross_any
    integer :: rooted,j,kind,s,layer,lo_node,hi_node,npl,nlayers
    integer :: nle3,nge3,nle4,nge4
    real(real64) :: u,expected_potential,h3,h4,theta_r,theta_s,se_bar,theta_bar,h_storage,h_root
    real(real64) :: deltaf,thickness,layer_exact,layer_roothead,layer_storage,layer_a,layer_b
    real(real64) :: f_exact,f_roothead,f_storage,a_total,b_total,e_total,cross_l1,noncross_l1
    real(real64) :: pref_wh(0:numnod/2),pref_exact(0:numnod/2),pref_theta(0:numnod/2)
    integer :: pref_le3(0:numnod/2),pref_ge3(0:numnod/2),pref_le4(0:numnod/2),pref_ge4(0:numnod/2)
    real(real64),save :: sumsq_e(NSUPPORT)=0.0_real64,sumsq_a(NSUPPORT)=0.0_real64,sumsq_b(NSUPPORT)=0.0_real64
    real(real64),save :: sum_e(NSUPPORT)=0.0_real64,sum_a(NSUPPORT)=0.0_real64,sum_b(NSUPPORT)=0.0_real64
    real(real64),save :: max_e(NSUPPORT)=0.0_real64,max_a(NSUPPORT)=0.0_real64,max_b(NSUPPORT)=0.0_real64
    real(real64),save :: cross_l1_sum(NSUPPORT)=0.0_real64,noncross_l1_sum(NSUPPORT)=0.0_real64
    real(real64),save :: max_identity(NSUPPORT)=0.0_real64
    integer,save :: count_tx=0,cross_tx(NSUPPORT)=0

    rooted=numnod/2
    call require(numnod==2048.and.rooted==1024,'ROM-ROOT S3-D2 qualified target geometry')
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
    theta_r=p%cofgen(1,1)
    theta_s=p%cofgen(2,1)
    pref_wh=0.0_real64
    pref_exact=0.0_real64
    pref_theta=0.0_real64
    pref_le3=0;pref_ge3=0;pref_le4=0;pref_ge4=0
    do j=1,rooted
      u=request%cumulative_root_fraction(j+1)-request%cumulative_root_fraction(j)
      pref_wh(j)=pref_wh(j-1)+u*view%pressure_head(j)
      pref_exact(j)=pref_exact(j-1)+u*diagnostics%drought_reduction_factor(j)
      pref_theta(j)=pref_theta(j-1)+view%water_content(j)*p%dz(j)
      pref_le3(j)=pref_le3(j-1)+merge(1,0,view%pressure_head(j)<=h3)
      pref_ge3(j)=pref_ge3(j-1)+merge(1,0,view%pressure_head(j)>=h3)
      pref_le4(j)=pref_le4(j-1)+merge(1,0,view%pressure_head(j)<=h4)
      pref_ge4(j)=pref_ge4(j-1)+merge(1,0,view%pressure_head(j)>=h4)
    end do
    f_exact=pref_exact(rooted)
    call require(abs(f_exact-fluxes%actual_uptake_total/expected_potential)<=diagnostic_guard, &
         'ROM-ROOT S3-D2 fine exact/process identity')

    count_tx=count_tx+1
    do s=1,NSUPPORT
      npl=support_nodes(s)
      call require(mod(rooted,npl)==0,'ROM-ROOT S3-D2 exact dyadic support')
      nlayers=rooted/npl
      f_roothead=0.0_real64
      f_storage=0.0_real64
      cross_l1=0.0_real64
      noncross_l1=0.0_real64
      cross_any=.false.
      do layer=1,nlayers
        lo_node=(layer-1)*npl+1
        hi_node=layer*npl
        deltaf=request%cumulative_root_fraction(hi_node+1)-request%cumulative_root_fraction(lo_node)
        thickness=real(npl,real64)*p%dz(1)
        theta_bar=(pref_theta(hi_node)-pref_theta(lo_node-1))/thickness
        se_bar=(theta_bar-theta_r)/(theta_s-theta_r)
        call require(se_bar>0.0_real64.and.se_bar<1.0_real64,'ROM-ROOT S3-D2 invertible support mean theta')
        h_storage=pressure_head_from_se(p,se_bar)
        h_root=(pref_wh(hi_node)-pref_wh(lo_node-1))/deltaf
        layer_exact=pref_exact(hi_node)-pref_exact(lo_node-1)
        layer_roothead=deltaf*s3d2_alpha(h_root,h3,h4)
        layer_storage=deltaf*s3d2_alpha(h_storage,h3,h4)
        layer_a=layer_roothead-layer_exact
        layer_b=layer_storage-layer_roothead
        nle3=pref_le3(hi_node)-pref_le3(lo_node-1)
        nge3=pref_ge3(hi_node)-pref_ge3(lo_node-1)
        nle4=pref_le4(hi_node)-pref_le4(lo_node-1)
        nge4=pref_ge4(hi_node)-pref_ge4(lo_node-1)
        cross3=nle3>0.and.nge3>0
        cross4=nle4>0.and.nge4>0
        if(cross3.or.cross4)then
          cross_any=.true.
          cross_l1=cross_l1+abs(layer_storage-layer_exact)
        else
          noncross_l1=noncross_l1+abs(layer_storage-layer_exact)
        end if
        f_roothead=f_roothead+layer_roothead
        f_storage=f_storage+layer_storage
      end do
      a_total=f_roothead-f_exact
      b_total=f_storage-f_roothead
      e_total=f_storage-f_exact
      max_identity(s)=max(max_identity(s),abs(e_total-(a_total+b_total)))
      call require(abs(e_total-(a_total+b_total))<=diagnostic_guard,'ROM-ROOT S3-D2 A+B identity')
      sumsq_e(s)=sumsq_e(s)+e_total*e_total
      sumsq_a(s)=sumsq_a(s)+a_total*a_total
      sumsq_b(s)=sumsq_b(s)+b_total*b_total
      sum_e(s)=sum_e(s)+e_total
      sum_a(s)=sum_a(s)+a_total
      sum_b(s)=sum_b(s)+b_total
      max_e(s)=max(max_e(s),abs(e_total))
      max_a(s)=max(max_a(s),abs(a_total))
      max_b(s)=max(max_b(s),abs(b_total))
      cross_l1_sum(s)=cross_l1_sum(s)+cross_l1
      noncross_l1_sum(s)=noncross_l1_sum(s)+noncross_l1
      if(cross_any)cross_tx(s)=cross_tx(s)+1
    end do

    if(step==SEGMENT_END)then
      do s=1,NSUPPORT
        write(*,'(*(g0))') 'ROM_ROOT_S3D2_SUMMARY|CASE=',trim(case_label(ih)), &
             '|SEGMENT_START=',SEGMENT_START,'|SEGMENT_END=',SEGMENT_END, &
             '|SUPPORT_CM=',real(support_nodes(s),real64)*p%dz(1),'|NODES_PER_LAYER=',support_nodes(s), &
             '|COUNT=',count_tx,'|SUMSQ_E=',sumsq_e(s),'|SUMSQ_A=',sumsq_a(s),'|SUMSQ_B=',sumsq_b(s), &
             '|SUM_E=',sum_e(s),'|SUM_A=',sum_a(s),'|SUM_B=',sum_b(s), &
             '|MAXABS_E=',max_e(s),'|MAXABS_A=',max_a(s),'|MAXABS_B=',max_b(s), &
             '|CROSS_TX=',cross_tx(s),'|CROSS_L1=',cross_l1_sum(s),'|NONCROSS_L1=',noncross_l1_sum(s), &
             '|MAX_IDENTITY=',max_identity(s)
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
    print("ROM_ROOT_S3D2_MATERIALIZED=TRUE")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
