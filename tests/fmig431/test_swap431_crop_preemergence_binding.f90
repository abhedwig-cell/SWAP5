program test_swap431_crop_preemergence_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_crop_preemergence_owner
  use mod_fmr_crop_preemergence_binding
  implicit none

  type(crop_preemergence_parameters_t) :: p
  type(crop_preemergence_daily_forcing_t) :: f
  type(process_hydraulic_view_t) :: h,empty_h
  type(soil_temperature_field_view_t) :: t,empty_t
  real(real64) :: zbot(3),dz(3),value,expected
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  dz=10.0_real64
  zbot=[-10.0_real64,-20.0_real64,-30.0_real64]
  h%active_nodes=3
  h%pressure_head=[-10.0_real64,-100.0_real64,-1000.0_real64]
  h%water_content=[0.2_real64,0.2_real64,0.2_real64]
  t%active_nodes=3
  t%temperature_c=[5.0_real64,10.0_real64,15.0_real64]

  call b111_average_pressure_head_to_depth(h%pressure_head,dz,-15.0_real64,value,status)
  expected=-10.0_real64**((1.0_real64*10.0_real64+2.0_real64*5.0_real64)/15.0_real64)
  if(status/=FMR_PREEMERGENCE_BINDING_OK.or.abs(value-expected)>tol) error stop 1

  call b111_average_pressure_head_to_depth(h%pressure_head,dz,0.0_real64,value,status)
  if(status/=FMR_PREEMERGENCE_BINDING_OK.or.abs(value+10.0_real64)>tol) error stop 2

  ! Positive pressure head maps to pF zero and therefore H_AVERAGE=-1 cm.
  h%pressure_head(1)=5.0_real64
  call b111_average_pressure_head_to_depth(h%pressure_head,dz,0.0_real64,value,status)
  if(status/=FMR_PREEMERGENCE_BINDING_OK.or.abs(value+1.0_real64)>tol) error stop 3
  h%pressure_head(1)=-10.0_real64

  p%preparation_enabled=.true.
  p%preparation_monitor_depth_cm=-15.0_real64
  p%preparation_head_threshold_cm=-50.0_real64
  p%sowing_enabled=.true.
  p%sowing_head_monitor_depth_cm=-10.0_real64
  p%sowing_head_threshold_cm=-50.0_real64
  p%sowing_temperature_monitor_depth_cm=-10.0_real64
  p%sowing_temperature_threshold_c=8.0_real64
  p%maximum_preparation_delay_days=2
  p%maximum_sowing_delay_days=2
  p%germination_mode=GERMINATION_TEMPERATURE_WATER
  p%optimal_emergence_temperature_sum=20.0_real64
  p%germination_base_temperature_c=0.0_real64
  p%germination_effective_max_temperature_c=20.0_real64
  p%germination_head_monitor_depth_cm=-25.0_real64
  p%dry_germination_head_cm=-500.0_real64
  p%wet_germination_head_cm=-100.0_real64
  p%germination_head_slope=5.0_real64
  if(.not.p%ready()) error stop 4

  call fmr_bind_crop_preemergence_forcing(p,h,t,zbot,dz,12.0_real64,f,status)
  if(status/=FMR_PREEMERGENCE_BINDING_OK) error stop 5
  if(abs(f%preparation_average_head_cm-expected)>tol) error stop 6
  if(abs(f%sowing_average_head_cm+10.0_real64)>tol) error stop 7
  ! zbot(1)=-10 < ztempsow+1e-8 selects node 1 exactly as B1.11.
  if(abs(f%sowing_soil_temperature_c-5.0_real64)>tol) error stop 8
  call b111_average_pressure_head_to_depth(h%pressure_head,dz,-25.0_real64,value,status)
  if(abs(f%germination_average_head_cm-value)>tol) error stop 9
  if(abs(f%average_air_temperature_c-12.0_real64)>tol) error stop 10

  ! Temperature-only germination has no hydraulic/soil-temperature dependency.
  p%preparation_enabled=.false.
  p%sowing_enabled=.false.
  p%germination_mode=GERMINATION_TEMPERATURE
  call fmr_bind_crop_preemergence_forcing(p,empty_h,empty_t,[real(real64)::],[real(real64)::], &
       12.0_real64,f,status)
  if(status/=FMR_PREEMERGENCE_BINDING_OK) error stop 11
  if(abs(f%average_air_temperature_c-12.0_real64)>tol) error stop 12

  call b111_average_pressure_head_to_depth(h%pressure_head,dz,-31.0_real64,value,status)
  if(status/=FMR_PREEMERGENCE_BINDING_DEPTH_OUTSIDE_PROFILE) error stop 13

  print '(a)','SW431_CROP_PREEMERGENCE_BINDING=PASS'
end program
