program empty_pocket_driver
 use iso_fortran_env,only:real64
 use mod_macropore_continuation_state
 use mod_macropore_standard_storage
 use mod_ppa_wu05a5_multi_domain_process
 use mod_ppa_wu05a5_top_partition
 use mod_ppa_wu05a6_vertical_flux_reconstruction
 implicit none
 type(macropore_continuation_state_t)::state,candidate
 type(macropore_standard_storage_view_t)::view
 type(macropore_standard_candidate_receipt_t)::receipt
 type(macropore_geometry_result_t)::geometry
 type(macropore_top_partition_result_t)::top
 type(vertical_flux_reconstruction_request_t)::request
 type(vertical_flux_reconstruction_result_t)::vertical
 real(real64),parameter::pocket=9.0556768483411758d-13,dt=.002d0
 real(real64)::z(3)=[-.5d0,-1.5d0,-2.5d0],dz(3)=1d0,q(1,3)=0d0,rapid(3)=0d0
 real(real64)::totals(7),total,old_water(1,3)
 integer::i
 logical::ok
 call state%initialize(1,3,ok);if(.not.ok)error stop 'state allocation'
 state%icp_bottom_domain=3;state%volume_domain_cp=.1d0
 totals=[0d0,pocket,.1d0-5d-13,.1d0+5d-13,.2d0-5d-13,.2d0+5d-13,.3d0]
 do i=1,size(totals)
  total=totals(i);state%water_domain_cp=0d0;state%water_domain_cp(1,3)=total
  call derive_macropore_standard_storage_view(state,1,z,dz,view)
  if(.not.view%valid)error stop 'regular storage view refused'
  if(total==pocket.and.sum(view%normalized_water_cm)/=total)error stop 'positive regular pocket discarded'
  if(abs(sum(view%normalized_water_cm)-total)>4d0*epsilon(1d0))error stop 'normal packing changed water'
  if(any(view%normalized_water_cm<0d0).or.any(view%normalized_water_cm>state%volume_domain_cp)) &
    error stop 'packing violates capacity'
 end do
 ! The existing tapered zero-capacity tip rule also preserves a positive pocket.
 state%volume_domain_cp(1,3)=0d0;state%water_domain_cp=0d0;state%water_domain_cp(1,3)=pocket
 call derive_macropore_standard_storage_view(state,1,z,dz,view)
 if(.not.view%valid.or.sum(view%normalized_water_cm)/=pocket)error stop 'tapered pocket lost'
 if(view%wet_fraction(1,3)/=1d0.or.view%normalized_water_cm(1,3)/=0d0)error stop 'zero tip changed'
 ! Positive capacities smaller than the former packing quantum still store water.
 state%volume_domain_cp(1,3)=pocket*.5d0
 call derive_macropore_standard_storage_view(state,1,z,dz,view)
 if(.not.view%valid.or.sum(view%normalized_water_cm)/=pocket)error stop 'small capacity lost water'
 ! Real candidate construction and vertical face reconstruction share the stock.
 state%water_domain_cp=0d0;state%volume_domain_cp=.1d0;old_water=state%water_domain_cp
 geometry%valid=.true.;geometry%num_domains=1;geometry%num_nodes=3
 geometry%volume_domain_cp=state%volume_domain_cp;geometry%dynamic_volume_cp=state%dynamic_volume_cp
 geometry%bottom_domain=[3]
 top%valid=.true.;top%num_domains=1;top%accepted_total_cm=pocket
 top%accepted_vertical_cm=[pocket];top%accepted_lateral_cm=[0d0]
 call build_macropore_standard_candidate(state,geometry,top,q,rapid,dt,1,z,dz,candidate,view,receipt,ok)
 if(.not.ok.or.sum(candidate%water_domain_cp)/=pocket)error stop 'candidate discarded accepted water'
 if(receipt%macro_balance_residual_cm/=0d0)error stop 'candidate mass receipt'
 request%num_domains=1;request%num_nodes=3;request%top_node=1;request%bottom_domain=[3]
 request%step_duration=dt;request%top_inflow_rate=[pocket/dt]
 request%previous_water_cm=old_water;request%current_water_cm=candidate%water_domain_cp
 request%exchange_to_matrix_rate=q;request%external_outflow_rate=q
 call reconstruct_vertical_flux(request,vertical)
 if(.not.vertical%valid.or.any(vertical%vertical_face_rate(:,4)/=0d0))error stop 'unbooked terminal export'
 if(any(candidate%water_domain_cp(:,:2)/=0d0))error stop 'wrong water front'
 state%volume_domain_cp(1,3)=-1d0
 call derive_macropore_standard_storage_view(state,1,z,dz,view)
 if(view%valid)error stop 'negative capacity admitted'
 print '(a)','POSITIVE_POCKETS_CANDIDATE_AND_CLOSED_VERTICAL_FACE_PASS'
end program
