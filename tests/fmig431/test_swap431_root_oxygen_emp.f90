program test_swap431_root_oxygen_emp
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process
  implicit none
  type(root_water_uptake_parameters_t) :: p
  type(root_water_uptake_request_t) :: q
  type(process_hydraulic_view_t) :: h
  type(root_water_uptake_flux_result_t) :: f
  type(root_water_uptake_diagnostics_t) :: d
  real(real64), parameter :: tol=1.0e-12_real64

  p%active_nodes=4
  p%hlim3l=-500.0_real64; p%hlim3h=-800.0_real64; p%hlim4=-16000.0_real64
  p%adcrl=0.1_real64; p%adcrh=0.5_real64
  q%potential_transpiration=1.0_real64; q%rooted_nodes=4
  q%cumulative_root_fraction=[0.0_real64,0.25_real64,0.5_real64,0.75_real64,1.0_real64]
  h%active_nodes=4
  h%pressure_head=[-5.0_real64,-30.0_real64,-75.0_real64,-120.0_real64]
  h%water_content=[0.3_real64,0.3_real64,0.3_real64,0.3_real64]

  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK) error stop 1
  if(maxval(abs(f%root_extraction_sink-0.25_real64))>tol) error stop 2
  if(abs(d%oxygen_reduction_total)>tol) error stop 3

  p%empirical_oxygen_enabled=.true.
  p%upper_layer_bottom_node=2
  p%hlim1=-10.0_real64
  p%hlim2u=-50.0_real64
  p%hlim2l=-100.0_real64
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK) error stop 4
  if(maxval(abs(d%oxygen_reduction_factor-[0.0_real64,0.5_real64,65.0_real64/90.0_real64,1.0_real64]))>tol) error stop 5
  if(maxval(abs(f%root_extraction_sink-[0.0_real64,0.125_real64,0.25_real64*65.0_real64/90.0_real64,0.25_real64]))>tol) error stop 6
  if(abs(d%drought_reduction_total)>tol) error stop 7
  if(abs(d%oxygen_reduction_total-(1.0_real64-sum(f%root_extraction_sink)))>tol) error stop 8

  h%pressure_head=[-10.0_real64,-50.0_real64,-100.0_real64,-101.0_real64]
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK) error stop 9
  if(maxval(abs(d%oxygen_reduction_factor-[0.0_real64,1.0_real64,1.0_real64,1.0_real64]))>tol) error stop 10

  ! Force wet and dry reductions to overlap and verify B1.11 proportional
  ! attribution of the one physical sink reduction.
  p%hlim3l=-20.0_real64; p%hlim3h=-20.0_real64; p%hlim4=-1000.0_real64
  p%hlim2u=-100.0_real64; p%hlim2l=-100.0_real64
  h%pressure_head=-50.0_real64
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK) error stop 11
  block
    real(real64) :: wet, dry, sink, red, denom
    wet=40.0_real64/90.0_real64
    dry=950.0_real64/980.0_real64
    sink=0.25_real64*wet*dry
    red=0.25_real64-sink
    denom=(1.0_real64-wet)+(1.0_real64-dry)
    if(abs(f%root_extraction_sink(1)-sink)>tol) error stop 12
    if(abs(d%oxygen_reduction(1)-red*(1.0_real64-wet)/denom)>tol) error stop 13
    if(abs(d%drought_reduction(1)-red*(1.0_real64-dry)/denom)>tol) error stop 14
  end block

  print '(a)','SW431_ROOT_OXYGEN_EMP_COMPONENT=PASS'
end program
