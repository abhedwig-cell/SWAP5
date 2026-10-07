program test_mc_irr01_management_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_scheduled_irrigation_management_policy
  use mod_irrigation_root_zone_summary
  implicit none
  type(irrigation_management_policy_parameters_t)::p
  type(irrigation_management_policy_state_t)::s,c
  type(irrigation_management_policy_request_t)::r
  type(irrigation_management_policy_result_t)::y
  type(irrigation_root_zone_parameters_t)::rzp
  type(irrigation_root_zone_summary_t)::rz
  type(process_hydraulic_view_t)::h
  integer::st
  real(real64),parameter::tol=1e-12_real64

  call common(p,r)
  p%timing_criterion=2; p%tcs2_knot_count=2; p%tcs2_dvs(1:2)=[0d0,2d0]; p%tcs2_fraction(1:2)=[0.5d0,0.5d0]
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. .not.y%trigger .or. abs(y%selected_depth_cm-2.0d0)>tol) error stop 1

  call common(p,r); p%timing_criterion=3; p%tcs3_knot_count=2
  p%tcs3_dvs(1:2)=[0d0,2d0]; p%tcs3_fraction(1:2)=[0.2d0,0.2d0]
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. .not.y%trigger) error stop 2

  call common(p,r); p%timing_criterion=4; p%tcs4_knot_count=2
  p%tcs4_dvs(1:2)=[0d0,2d0]; p%tcs4_depletion_mm(1:2)=[15d0,15d0]
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. .not.y%trigger) error stop 3

  call common(p,r); p%timing_criterion=6; p%tcs6_threshold_mm=10d0; s%weekly_day_counter=5
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. y%trigger .or. c%weekly_day_counter/=6) error stop 4
  s%weekly_day_counter=6
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. .not.y%weekly_opportunity .or. .not.y%trigger .or. c%weekly_day_counter/=0) error stop 5

  call common(p,r); p%timing_criterion=4; p%tcs4_knot_count=2
  p%tcs4_dvs(1:2)=[0d0,2d0]; p%tcs4_depletion_mm(1:2)=[15d0,15d0]
  p%depth_limit_enabled=.true.; p%minimum_depth_cm=2.5d0; p%maximum_depth_cm=3d0
  p%salinity_excess_enabled=.true.; p%salinity_threshold=8d0; p%salinity_excess_percent=20d0
  r%sensor_concentration=9d0; r%solute_enabled=.true.
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. abs(y%selected_depth_cm-3.0d0)>tol .or. .not.y%depth_limited .or. .not.y%salinity_excess_applied) error stop 6

  call common(p,r); p%timing_criterion=4; p%tcs4_knot_count=2
  p%tcs4_dvs(1:2)=[0d0,2d0]; p%tcs4_depletion_mm(1:2)=[15d0,15d0]
  p%rainfall_threshold_cm=0.5d0; r%rainfall_cm=0.6d0
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=0 .or. abs(y%selected_depth_cm-1.4d0)>tol .or. .not.y%rainfall_deducted) error stop 7

  ! Root-zone summary reproduces full nodes plus the legacy fractional last root node.
  rzp%active_nodes=3; rzp%rooted_nodes=2; rzp%last_rooted_fraction=0.5d0
  allocate(rzp%node_thickness_cm(3),rzp%field_capacity_water_content(3),rzp%stress_water_content(3),rzp%wilting_water_content(3))
  rzp%node_thickness_cm=[10d0,20d0,30d0]
  rzp%field_capacity_water_content=[0.30d0,0.35d0,0.40d0]
  rzp%stress_water_content=[0.20d0,0.25d0,0.30d0]
  rzp%wilting_water_content=[0.10d0,0.15d0,0.20d0]
  h%active_nodes=3; allocate(h%pressure_head(3),h%water_content(3)); h%pressure_head=-100d0
  h%water_content=[0.25d0,0.30d0,0.99d0]
  call evaluate_irrigation_root_zone_summary(rzp,h,rz,st)
  if(st/=IRR_ROOT_ZONE_OK) error stop 8
  if(abs(rz%total_available_water_cm-4d0)>tol .or. abs(rz%stress_to_wilting_available_cm-2d0)>tol) error stop 9
  if(abs(rz%actual_available_water_cm-3d0)>tol .or. abs(rz%field_capacity_deficit_cm-1d0)>tol) error stop 10

  ! Negative source quantities remain representable; policy must not silently clamp them.
  call common(p,r); p%timing_criterion=6; p%tcs6_threshold_mm=10d0
  r%actual_available_water_cm=-0.1d0; r%field_capacity_deficit_cm=-0.2d0; s%weekly_day_counter=6
  call evaluate_irrigation_management_policy(p,s,r,c,y,st)
  if(st/=IRR_MGMT_OK .or. y%trigger) error stop 11

  print '(A)','MC_IRR01_MANAGEMENT_POLICY=PASS'
  print '(A)','MC_IRR01_ROOT_ZONE_SUMMARY=PASS'
contains
  subroutine common(p,r)
    type(irrigation_management_policy_parameters_t),intent(out)::p
    type(irrigation_management_policy_request_t),intent(out)::r
    p=irrigation_management_policy_parameters_t(); r=irrigation_management_policy_request_t()
    p%depth_criterion=1; p%dcs1_knot_count=2; p%dcs1_dvs(1:2)=[0d0,2d0]; p%dcs1_adjustment_mm(1:2)=[0d0,0d0]
    r%dvs=1d0; r%total_available_water_cm=10d0; r%stress_to_wilting_available_cm=6d0
    r%actual_available_water_cm=7d0; r%field_capacity_deficit_cm=2d0
  end subroutine
end program test_mc_irr01_management_policy
