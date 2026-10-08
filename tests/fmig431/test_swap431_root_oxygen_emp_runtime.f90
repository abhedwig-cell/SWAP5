program test_swap431_root_oxygen_emp_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t, ROOT_UPTAKE_OK
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, fmr_root_uptake_binding_diagnostics_t, &
       fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  implicit none
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: committed
  type(root_water_uptake_parameters_t) :: p
  type(fmr_root_uptake_crop_input_t) :: crop
  type(root_water_uptake_flux_result_t) :: fluxes
  type(root_water_uptake_diagnostics_t) :: process_diag
  type(fmr_root_uptake_binding_diagnostics_t) :: binding_diag
  logical :: ok
  real(real64), parameter :: tol=1.0e-12_real64

  physical%active_nodes=4
  allocate(physical%pressure_head(4),physical%water_content(4))
  physical%pressure_head=[-5.0_real64,-30.0_real64,-75.0_real64,-120.0_real64]
  physical%water_content=0.3_real64
  physical%ponding_depth=0.0_real64
  physical%groundwater_level=-20.0_real64
  call fmr_new_b110_committed_state(committed,88001_int64,physical,0.0_real64,ok)
  if(.not.ok) error stop 1

  p%active_nodes=4
  p%hlim3l=-500.0_real64; p%hlim3h=-800.0_real64; p%hlim4=-16000.0_real64
  p%adcrl=0.1_real64; p%adcrh=0.5_real64
  p%empirical_oxygen_enabled=.true.
  p%upper_layer_bottom_node=2
  p%hlim1=-10.0_real64; p%hlim2u=-50.0_real64; p%hlim2l=-100.0_real64

  crop%crop_emerged=.true.
  crop%potential_transpiration=1.0_real64
  crop%rooted_nodes=4
  crop%cumulative_root_fraction=[0.0_real64,0.25_real64,0.5_real64,0.75_real64,1.0_real64]

  call fmr_evaluate_committed_root_uptake(committed,p,crop,fluxes,process_diag,binding_diag)
  if(binding_diag%status/=FMR_ROOT_UPTAKE_BINDING_OK.or.process_diag%status/=ROOT_UPTAKE_OK) error stop 2
  if(.not.binding_diag%hydraulic_view_built.or..not.binding_diag%process_called) error stop 3
  if(maxval(abs(fluxes%root_extraction_sink-[0.0_real64,0.125_real64,0.25_real64*65.0_real64/90.0_real64,0.25_real64]))>tol) error stop 4
  if(abs(process_diag%oxygen_reduction_total-(1.0_real64-fluxes%actual_uptake_total))>tol) error stop 5
  if(committed%current_revision()/=0_int64) error stop 6

  print '(a)','SW431_ROOT_OXYGEN_EMP_RUNTIME=PASS'
end program
