program test_swap431_root_oxygen_repro_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_oxygen_reproduction_response, only: root_oxygen_reproduction_parameters_t
  use mod_fmr_bartholomeus_activation
  use mod_fmr_bartholomeus_execution
  implicit none

  type(fmr_bartholomeus_selection_t) :: config
  type(process_hydraulic_view_t) :: hydraulic
  type(soil_temperature_field_view_t) :: thermal
  type(BartholomeusImmutableDataset) :: data
  type(BartholomeusCropParameters) :: crop
  type(root_oxygen_reproduction_parameters_t) :: repro
  type(root_water_uptake_flux_result_t) :: base, final
  real(real64), allocatable :: factors(:)
  real(real64) :: wroot(2), wrootz0(2)
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  config%oxygen_mode=FMR_OXYGEN_BARTHOLOMEUS
  config%oxygen_type=FMR_OXYGEN_TYPE_REPRODUCTION
  config%hydraulic_waterfilm_mode=99

  hydraulic%active_nodes=2
  allocate(hydraulic%pressure_head(2),hydraulic%water_content(2))
  hydraulic%pressure_head=[-100.0_real64,-100.0_real64]
  hydraulic%water_content=[0.30_real64,0.30_real64]
  thermal%active_nodes=2
  allocate(thermal%temperature_c(2))
  thermal%temperature_c=[10.0_real64,10.0_real64]

  allocate(base%root_extraction_sink(2))
  base%root_extraction_sink=[0.6_real64,0.4_real64]
  base%actual_uptake_total=1.0_real64

  repro%slope=0.0_real64
  repro%intercept=0.0_real64
  repro%intercept(6)=0.5_real64
  repro%saturated_water_content=0.40_real64
  repro%z_cm=[-5.0_real64,-15.0_real64]
  repro%zbotcp_cm=[-10.0_real64,-20.0_real64]
  repro%dz_cm=10.0_real64
  wroot=0.0_real64
  wrootz0=0.0_real64

  call fmr_apply_bartholomeus_to_root_sink(config,hydraulic,thermal,data,crop,wroot,wrootz0,0.0_real64, &
       base,final,status,factors,repro)
  if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 1
  if(maxval(abs(final%root_extraction_sink-[0.3_real64,0.2_real64]))>tol) error stop 2
  if(abs(final%actual_uptake_total-0.5_real64)>tol) error stop 3
  if(size(factors)/=2.or.maxval(abs(factors-0.5_real64))>tol) error stop 4

  ! Type2 fails closed when its explicit geometry/parameter inputs are absent.
  call fmr_apply_bartholomeus_to_root_sink(config,hydraulic,thermal,data,crop,wroot,wrootz0,0.0_real64, &
       base,final,status)
  if(status/=FMR_BARTHOLOMEUS_EXEC_INPUT) error stop 5

  print '(a)','SW431_ROOT_OXYGEN_REPRO_EXECUTION=PASS'
end program
