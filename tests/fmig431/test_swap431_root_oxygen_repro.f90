program test_swap431_root_oxygen_repro
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters
  use mod_root_oxygen_reproduction_response
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_fmr_bartholomeus_activation
  use mod_fmr_bartholomeus_execution
  implicit none
  type(root_oxygen_reproduction_parameters_t)::p
  type(process_hydraulic_view_t)::h
  type(soil_temperature_field_view_t)::t
  type(BartholomeusImmutableDataset)::data
  type(BartholomeusCropParameters)::crop
  type(fmr_bartholomeus_selection_t)::config
  type(root_water_uptake_flux_result_t)::base,final
  real(real64),allocatable::factors(:)
  real(real64)::empty(0)
  integer::status
  real(real64),parameter::tol=1e-12_real64

  p%slope=0._real64;p%intercept=0._real64
  p%intercept(6)=0.2_real64;p%slope(6)=2._real64
  p%saturated_water_content=[0.4_real64,0.4_real64,0.4_real64]
  p%z_cm=[-5._real64,-15._real64,-25._real64]
  p%zbotcp_cm=[-10._real64,-20._real64,-30._real64]
  p%dz_cm=10._real64
  if(.not.p%ready())error stop 1

  h%active_nodes=3
  h%water_content=[0.30_real64,0.25_real64,0.20_real64]
  h%pressure_head=[-100._real64,-100._real64,-100._real64]
  t%active_nodes=3
  t%temperature_c=[10._real64,12._real64,14._real64]
  allocate(base%root_extraction_sink(3))
  base%root_extraction_sink=[0.3_real64,0.2_real64,0.0_real64]
  base%actual_uptake_total=0.5_real64

  config%oxygen_mode=FMR_OXYGEN_BARTHOLOMEUS
  config%oxygen_type=FMR_OXYGEN_TYPE_REPRODUCTION
  call fmr_apply_bartholomeus_to_root_sink(config,h,t,data,crop,empty,empty,0._real64, &
       base,final,status,factors,p,2)
  if(status/=FMR_BARTHOLOMEUS_EXEC_OK)error stop 2
  if(size(factors)/=3)error stop 3
  if(abs(factors(2)-0.45_real64)>tol)error stop 4
  if(abs(final%root_extraction_sink(2)-0.09_real64)>tol)error stop 5
  if(abs(final%root_extraction_sink(3))>tol)error stop 6
  if(abs(final%actual_uptake_total-sum(final%root_extraction_sink))>tol)error stop 7

  h%water_content(2)=0.45_real64
  call fmr_apply_bartholomeus_to_root_sink(config,h,t,data,crop,empty,empty,0._real64, &
       base,final,status,factors,p,2)
  if(status/=FMR_BARTHOLOMEUS_EXEC_OK.or.abs(factors(2))>tol)error stop 8
  if(abs(final%root_extraction_sink(2))>tol)error stop 9

  print '(a)','SW431_ROOT_OXYGEN_REPRO=PASS'
end program
