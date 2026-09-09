program fkt13_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fkt05_test_model, only: fkt05_parameters_t, fkt05_forcing_t
  use mod_fkt12_mass_complete_test_model, only: fkt12_mass_complete_model_t
  use mod_fkt13_process_support
  implicit none

  type(kernel_committed_state_t) :: committed
  type(kernel_executor_t) :: kernel
  type(fkt12_mass_complete_model_t), target :: model
  type(fkt05_parameters_t) :: parameters
  type(fkt05_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(canonical_mass_accounting_t) :: mass_t1, mass_t2
  real(real64) :: water_t1, water_t2

  call fkt13_new_initial_committed(committed)
  call fkt13_setup(parameters, forcing, config)
  call kernel%bind_model(model)

  call fkt13_advance_and_commit(kernel, committed, parameters, forcing, config, FKT13_T0, FKT13_T1, mass_t1)
  water_t1 = fkt13_committed_water(committed)
  if (committed%current_revision() /= 1_int64) error stop 'FKT13 reference T1 revision mismatch'
  if (committed%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 reference lineage mismatch'
  if (transfer(fkt13_committed_time(committed), 0_int64) /= transfer(FKT13_T1, 0_int64)) &
       error stop 'FKT13 reference T1 time mismatch'

  call fkt13_advance_and_commit(kernel, committed, parameters, forcing, config, FKT13_T1, FKT13_T2, mass_t2)
  water_t2 = fkt13_committed_water(committed)
  if (committed%current_revision() /= 2_int64) error stop 'FKT13 reference T2 revision mismatch'
  if (.not. mass_t2%complete) error stop 'FKT13 reference mass incomplete'
  if (transfer(mass_t2%residual, 0_int64) /= transfer(0.0_real64, 0_int64)) &
       error stop 'FKT13 reference mass residual nonzero'
  if (transfer(mass_t2%storage_start, 0_int64) /= transfer(water_t1, 0_int64)) &
       error stop 'FKT13 reference storage start mismatch'
  if (transfer(mass_t2%storage_end, 0_int64) /= transfer(water_t2, 0_int64)) &
       error stop 'FKT13 reference storage end mismatch'

  write(*,'(A)') 'FKT13_CONTINUOUS_REFERENCE_MASS_AND_PROVENANCE=PASS'
  call fkt13_print_endpoint(committed, mass_t2)
end program fkt13_reference
