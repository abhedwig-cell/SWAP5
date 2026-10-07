program test_crop_adaptive_root_profile_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_adaptive_root_profile_owner
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_reference_et_root_uptake_composition, only: fmr_reference_et_root_uptake_diagnostics_t, &
       fmr_evaluate_adaptive_reference_et_root_uptake, FMR_REFERENCE_ET_ROOT_UPTAKE_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_kernel_transactions, only: kernel_committed_state_t
  implicit none
  type(wofost_rate_table_t)::density
  type(adaptive_root_profile_state_t)::profile
  type(root_water_uptake_parameters_t)::parameters
  type(reference_et_demand_result_t)::et_result
  type(fmr_reference_et_binding_diagnostics_t)::et_diag
  type(root_water_uptake_flux_result_t)::fluxes
  type(root_water_uptake_diagnostics_t)::process_diag
  type(fmr_ptra_root_input_binding_diagnostics_t)::ptra_diag
  type(fmr_crop_root_uptake_adapter_diagnostics_t)::adapter_diag
  type(fmr_root_uptake_binding_diagnostics_t)::binding_diag
  type(fmr_reference_et_root_uptake_diagnostics_t)::diagnostics
  type(fmr_b110_physical_state_t)::physical
  type(kernel_committed_state_t)::committed
  real(real64)::zbot(4)
  integer::status
  logical::ok

  zbot=[-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [2.0_real64,1.0_real64,0.0_real64],density,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 1
  call initialize_adaptive_root_profile_state(density,zbot,40.0_real64,20.0_real64,100.0_real64,profile,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 2

  parameters%active_nodes=4
  parameters%hlim3l=-500.0_real64;parameters%hlim3h=-800.0_real64
  parameters%hlim4=-16000.0_real64;parameters%adcrl=0.1_real64;parameters%adcrh=0.5_real64

  physical%active_nodes=4
  allocate(physical%pressure_head(4),physical%water_content(4))
  physical%pressure_head=-100.0_real64;physical%water_content=0.30_real64
  physical%ponding_depth=0.0_real64;physical%groundwater_level=-20.0_real64
  call fmr_new_b110_committed_state(committed,940101_int64,physical,0.0_real64,ok)
  if(.not.ok)error stop 3

  et_result%potential_transpiration_cm_per_day=0.04_real64
  et_diag%status=FMR_REFERENCE_ET_BINDING_OK;et_diag%result_produced=.true.
  call fmr_evaluate_adaptive_reference_et_root_uptake(committed,parameters,profile,2,et_result,et_diag, &
       fluxes,process_diag,ptra_diag,adapter_diag,binding_diag,diagnostics)
  if(diagnostics%status/=FMR_REFERENCE_ET_ROOT_UPTAKE_OK.or..not.diagnostics%result_produced)error stop 4
  if(maxval(abs(fluxes%root_extraction_sink-[0.03_real64,0.01_real64,0.0_real64,0.0_real64]))>1.0e-12_real64)error stop 5
  if(abs(fluxes%actual_uptake_total-0.04_real64)>1.0e-12_real64)error stop 6

  print '(a)','SW431_ROOT_DENSITY_ADAPTIVE_RUNTIME=PASS'
end program
