#!/usr/bin/env python3
"""Instrument the frozen RA02R target harness for ROM-ROOT-S3-D1.

The instrumentation observes the committed fine-node hydraulic state immediately
before the already-qualified prescribed root sink is formed. It does not modify
that sink, the hydraulic trial, Reference Richards, or any persistent state.
"""
from __future__ import annotations

import argparse
import hashlib
import pathlib
import re

MARKER="ROM_ROOT_S3D1_FINE_NODE_FEDDES_DECOMPOSITION"

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("S3-D1 diagnostic already materialized")

    call_old="call evaluate_committed_root_sink(ih,p,state,forcing,root_rate)"
    if text.count(call_old)!=1:
        raise SystemExit(f"expected one root-evaluation call, found {text.count(call_old)}")
    text=text.replace(call_old,"call evaluate_committed_root_sink(ih,step,p,state,forcing,root_rate)",1)

    rx=re.compile(
        r"^  subroutine evaluate_committed_root_sink\(ih,p,state,forcing,total_rate\).*?"
        r"^  end subroutine evaluate_committed_root_sink\n",
        re.MULTILINE|re.DOTALL,
    )
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"expected one evaluate_committed_root_sink block, found {len(hits)}")

    replacement=r"""  ! ROM_ROOT_S3D1_FINE_NODE_FEDDES_DECOMPOSITION
  pure real(real64) function s3d1_alpha(h,h3,h4) result(value)
    real(real64),intent(in) :: h,h3,h4
    value=1.0_real64
    if(h<h4)then
      value=0.0_real64
    else if(h<=h3)then
      value=(h4-h)/(h4-h3)
    end if
  end function s3d1_alpha

  subroutine evaluate_committed_root_sink(ih,step,p,state,forcing,total_rate)
    integer,intent(in) :: ih,step
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(out) :: total_rate
    type(root_water_uptake_parameters_t) :: parameters
    type(root_water_uptake_request_t) :: request
    type(root_water_uptake_flux_result_t) :: fluxes
    type(root_water_uptake_diagnostics_t) :: diagnostics
    type(process_hydraulic_view_t) :: view
    class(transaction_state_t),allocatable :: snap
    logical :: got,cross3,cross4,cross_any
    integer :: rooted,j,kind,layer,lo_node,hi_node,nodes_per_layer,cross_h3_count,cross_h4_count
    real(real64) :: u,expected_potential,h3,h4,theta_r,theta_s,se_bar,theta_bar,h_storage,h_root
    real(real64) :: deltaf,w,layer_exact,layer_roothead,layer_r16,layer_a,layer_b,hmin,hmax
    real(real64) :: f_exact,f_roothead,f_r16,a_total,b_total,total_error,cross_root,cross_l1,noncross_l1
    real(real64),parameter :: diagnostic_guard=2.9103830456733704e-11_real64

    rooted=numnod/2
    call require(rooted>0.and.2*rooted==numnod,'LAREDYN0R C6R exact 80cm rooted half-column')
    call require(mod(rooted,8)==0,'ROM-ROOT S3-D1 exact R16 root-layer node support')
    nodes_per_layer=rooted/8
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
    call require(allocated(fluxes%root_extraction_sink).and.size(fluxes%root_extraction_sink)==numnod, &
         'LAREDYN0R C6R root sink shape')
    call require(all(ieee_is_finite(fluxes%root_extraction_sink)),'LAREDYN0R C6R finite root sink')
    call require(all(fluxes%root_extraction_sink>=0.0_real64),'LAREDYN0R C6R nonnegative root sink')
    call require(abs(sum(fluxes%root_extraction_sink)-fluxes%actual_uptake_total)<=1.0e-12_real64, &
         'LAREDYN0R C6R actual uptake reconciliation')

    h3=diagnostics%critical_pressure_head
    h4=parameters%hlim4
    theta_r=p%cofgen(1,1)
    theta_s=p%cofgen(2,1)
    f_exact=0.0_real64
    f_roothead=0.0_real64
    f_r16=0.0_real64
    a_total=0.0_real64
    b_total=0.0_real64
    cross_root=0.0_real64
    cross_l1=0.0_real64
    noncross_l1=0.0_real64
    cross_h3_count=0
    cross_h4_count=0

    do layer=1,8
      lo_node=(layer-1)*nodes_per_layer+1
      hi_node=layer*nodes_per_layer
      deltaf=request%cumulative_root_fraction(hi_node+1)-request%cumulative_root_fraction(lo_node)
      call require(deltaf>0.0_real64,'ROM-ROOT S3-D1 positive rooted R16 layer fraction')
      theta_bar=sum(view%water_content(lo_node:hi_node)*p%dz(lo_node:hi_node))/ &
           sum(p%dz(lo_node:hi_node))
      se_bar=(theta_bar-theta_r)/(theta_s-theta_r)
      call require(se_bar>0.0_real64.and.se_bar<1.0_real64,'ROM-ROOT S3-D1 invertible layer mean theta')
      h_storage=pressure_head_from_se(p,se_bar)
      h_root=0.0_real64
      layer_exact=0.0_real64
      do j=lo_node,hi_node
        w=request%cumulative_root_fraction(j+1)-request%cumulative_root_fraction(j)
        h_root=h_root+w*view%pressure_head(j)
        layer_exact=layer_exact+w*diagnostics%drought_reduction_factor(j)
      end do
      h_root=h_root/deltaf
      layer_roothead=deltaf*s3d1_alpha(h_root,h3,h4)
      layer_r16=deltaf*s3d1_alpha(h_storage,h3,h4)
      layer_a=layer_roothead-layer_exact
      layer_b=layer_r16-layer_roothead
      hmin=minval(view%pressure_head(lo_node:hi_node))
      hmax=maxval(view%pressure_head(lo_node:hi_node))
      cross3=hmin<=h3.and.h3<=hmax
      cross4=hmin<=h4.and.h4<=hmax
      cross_any=cross3.or.cross4
      if(cross3)cross_h3_count=cross_h3_count+1
      if(cross4)cross_h4_count=cross_h4_count+1
      if(cross_any)then
        cross_root=cross_root+deltaf
        cross_l1=cross_l1+abs(layer_r16-layer_exact)
      else
        noncross_l1=noncross_l1+abs(layer_r16-layer_exact)
      end if
      f_exact=f_exact+layer_exact
      f_roothead=f_roothead+layer_roothead
      f_r16=f_r16+layer_r16
      a_total=a_total+layer_a
      b_total=b_total+layer_b

      if(mod(step,OUTPUT_FACTOR)==0)then
        write(*,'(*(g0))') 'ROM_ROOT_S3D1_LAYER|CASE=',trim(case_label(ih)),'|STEP=',step, &
             '|OBS_STEP=',step/OUTPUT_FACTOR,'|LAYER=',layer,'|DELTAF=',deltaf, &
             '|THETA_BAR=',theta_bar,'|H_STORAGE=',h_storage,'|H_ROOT=',h_root, &
             '|HMIN=',hmin,'|HMAX=',hmax,'|H3=',h3,'|H4=',h4, &
             '|FEXACT=',layer_exact,'|FROOT=',layer_roothead,'|FR16=',layer_r16, &
             '|A=',layer_a,'|B=',layer_b,'|H3CROSS=',cross3,'|H4CROSS=',cross4
      end if
    end do

    total_error=f_r16-f_exact
    call require(abs(f_exact-fluxes%actual_uptake_total/expected_potential)<=diagnostic_guard, &
         'ROM-ROOT S3-D1 fine exact/process identity')
    call require(abs(total_error-(a_total+b_total))<=diagnostic_guard, &
         'ROM-ROOT S3-D1 exact A+B decomposition identity')
    write(*,'(*(g0))') 'ROM_ROOT_S3D1_TX|CASE=',trim(case_label(ih)),'|STEP=',step, &
         '|FEXACT=',f_exact,'|FROOT=',f_roothead,'|FR16=',f_r16, &
         '|A=',a_total,'|B=',b_total,'|TOTAL=',total_error, &
         '|H3CROSS=',cross_h3_count,'|H4CROSS=',cross_h4_count,'|CROSS_ROOT=',cross_root, &
         '|CROSS_L1=',cross_l1,'|NONCROSS_L1=',noncross_l1

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
    print("ROM_ROOT_S3D1_MATERIALIZED=TRUE")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
