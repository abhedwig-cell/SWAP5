program test_macropore_standard_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_result_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, &
       macropore_standard_candidate_receipt_t, canonicalize_macropore_standard_storage, &
       build_macropore_standard_candidate
  implicit none

  type(macropore_continuation_state_t)::state,candidate
  type(macropore_standard_storage_view_t)::view
  type(macropore_standard_candidate_receipt_t)::receipt
  type(macropore_geometry_result_t)::geometry
  type(macropore_top_partition_result_t)::top
  real(real64)::z(4),dz(4),qexc(1,4),rapid(4)
  logical::ok

  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  dz=10.0_real64
  call state%initialize(1,4,ok)
  if(.not.ok)error stop 'A8 standard init'
  state%icp_bottom_domain=4
  state%volume_domain_cp=0.2_real64
  state%water_domain_cp=0.0_real64
  state%water_domain_cp(1,:)=[0.02_real64,0.03_real64,0.04_real64,0.11_real64]

  call canonicalize_macropore_standard_storage(state,1,z,dz,view,ok)
  if(.not.ok)error stop 'A8 standard canonicalize'
  if(view%top_water_node(1)/=4)error stop 'A8 standard top water'
  if(abs(view%wet_fraction(1,4)-1.0_real64)>1.0e-12_real64)error stop 'A8 standard full bottom'
  ! Total 0.20 exactly fills bottom compartment.
  if(abs(view%water_level_cm(1)+30.0_real64)>1.0e-12_real64)error stop 'A8 standard water level'

  state%water_domain_cp=0.0_real64
  state%water_domain_cp(1,4)=0.27_real64
  ! Invalid: more than one compartment volume at one slot, but total itself is valid.
  call canonicalize_macropore_standard_storage(state,1,z,dz,view,ok)
  if(.not.ok)error stop 'A8 standard total-storage canonicalize'
  if(view%top_water_node(1)/=3)error stop 'A8 standard partial top node'
  if(abs(view%wet_fraction(1,3)-0.35_real64)>1.0e-12_real64)error stop 'A8 standard partial fraction'
  if(abs(view%water_level_cm(1)+26.5_real64)>1.0e-12_real64)error stop 'A8 standard partial water level'

  geometry%valid=.true.
  geometry%num_domains=1
  geometry%num_nodes=4
  geometry%top_node=1
  allocate(geometry%bottom_domain(1),geometry%dynamic_volume_cp(4),geometry%total_volume_cp(4), &
       geometry%volume_domain_cp(1,4))
  geometry%bottom_domain=4
  geometry%dynamic_volume_cp=0.0_real64
  geometry%total_volume_cp=0.2_real64
  geometry%volume_domain_cp=0.2_real64

  top%valid=.true.
  top%num_domains=1
  top%top_node=1
  allocate(top%requested_vertical_cm(1),top%requested_lateral_cm(1),top%accepted_vertical_cm(1), &
       top%accepted_lateral_cm(1),top%redistributed_cm(1))
  top%requested_vertical_cm=0.05_real64
  top%requested_lateral_cm=0.0_real64
  top%accepted_vertical_cm=0.05_real64
  top%accepted_lateral_cm=0.0_real64
  top%redistributed_cm=0.0_real64
  top%requested_total_cm=0.05_real64
  top%accepted_total_cm=0.05_real64
  top%returned_surface_cm=0.0_real64
  top%receipt_residual_cm=0.0_real64

  qexc=0.0_real64
  qexc(1,3)=0.10_real64
  rapid=0.0_real64
  rapid(4)=0.01_real64

  call build_macropore_standard_candidate(state,geometry,top,qexc,rapid,0.1_real64,1,z,dz, &
       candidate,view,receipt,ok)
  if(.not.ok)error stop 'A8 standard candidate'
  if(abs(receipt%macro_balance_residual_cm)>1.0e-12_real64)error stop 'A8 standard candidate mass'
  if(abs(sum(candidate%water_domain_cp)-0.30_real64)>1.0e-12_real64) &
       error stop 'A8 standard candidate total'
  if(view%top_water_node(1)/=3)error stop 'A8 standard candidate top node'

  print '(a)', 'PPA_WU05A8_STANDARD_STORAGE=PASS'
end program test_macropore_standard_storage
