module mod_ebi10_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: ebi10_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => ebi10_clone
  end type ebi10_state_t

  type, extends(kernel_parameters_t), public :: ebi10_parameters_t
    real(real64) :: flux_rate = 0.1_real64
  end type ebi10_parameters_t

  type, extends(canonical_forcing_t), public :: ebi10_forcing_t
    real(real64) :: scale = 1.0_real64
  end type ebi10_forcing_t

  type, extends(kernel_model_t), public :: ebi10_model_t
    real(real64) :: flux_rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
  contains
    procedure :: configure_parameters => ebi10_configure_parameters
    procedure :: execution_admitted => ebi10_execution_admitted
    procedure :: prepare_interval => ebi10_prepare_interval
    procedure :: advance => ebi10_advance
    procedure :: storage => ebi10_storage
    procedure :: temporal_error => ebi10_temporal_error
  end type ebi10_model_t

contains

  subroutine ebi10_clone(self, copy)
    class(ebi10_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(ebi10_state_t :: copy)
    select type (copy)
    type is (ebi10_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine ebi10_clone

  subroutine ebi10_configure_parameters(self, parameters)
    class(ebi10_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (ebi10_parameters_t)
      self%flux_rate = parameters%flux_rate
    class default
      error stop 'EB-I10 unexpected parameter type'
    end select
  end subroutine ebi10_configure_parameters

  logical function ebi10_execution_admitted(self, parameters, numerical_config)
    class(ebi10_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (ebi10_parameters_t)
      parameter_ok = parameters%flux_rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    ebi10_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%scale >= 0.0_real64
  end function ebi10_execution_admitted

  subroutine ebi10_prepare_interval(self, forcing, interval, config)
    class(ebi10_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (ebi10_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'EB-I10 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'EB-I10 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'EB-I10 invalid config'
  end subroutine ebi10_prepare_interval

  subroutine ebi10_advance(self, state, t0, t1, outcome)
    class(ebi10_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: transfer_mass

    outcome = trial_outcome_t()
    transfer_mass = self%flux_rate * self%scale * (t1 - t0)
    select type (state)
    type is (ebi10_state_t)
      state%storage_value = state%storage_value + transfer_mass
    class default
      error stop 'EB-I10 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = transfer_mass
    outcome%nonlinear_iterations = 1
  end subroutine ebi10_advance

  real(real64) function ebi10_storage(self, state) result(value)
    class(ebi10_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%scale < 0.0_real64) error stop 'EB-I10 unreachable scale'
    select type (state)
    type is (ebi10_state_t)
      value = state%storage_value
    class default
      error stop 'EB-I10 unexpected state type'
    end select
  end function ebi10_storage

  real(real64) function ebi10_temporal_error(self, full_state, half_state) result(value)
    class(ebi10_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%scale < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'EB-I10 unexpected temporal state'
    end if
    value = 0.0_real64
  end function ebi10_temporal_error

end module mod_ebi10_test_model

program test_eb_i10_accepted_water_thermal_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt
  use mod_accepted_water_thermal_provenance
  use mod_ebi10_test_model
  implicit none

  type(kernel_executor_t) :: kernel
  type(ebi10_model_t), target :: model
  type(ebi10_parameters_t) :: parameters
  type(ebi10_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: state_a, state_b, state_c, state_d
  type(kernel_checkpoint_t) :: cp_a0, cp_a1, cp_b0, cp_c0, cp_d0
  type(kernel_candidate_state_t) :: cand_a, cand_a_interval, cand_a_near, cand_a_winner, cand_a_rev1
  type(kernel_candidate_state_t) :: cand_b, cand_c, cand_d, empty_candidate
  type(kernel_diagnostics_t) :: diag_a, diag_a_interval, diag_a_near, diag_a_winner, diag_a_rev1
  type(kernel_diagnostics_t) :: diag_b, diag_c, diag_d
  type(water_transfer_trial_provenance_t) :: water_a, water_c, water_d, water_invalid
  type(thermal_field_trial_provenance_t) :: thermal_a, thermal_other, thermal_c, thermal_d, thermal_invalid
  type(water_thermal_trial_binding_t) :: binding_a, binding_c, binding_d, binding_invalid
  type(accepted_water_thermal_provenance_t) :: accepted, accepted_invalid
  type(fmr_accepted_commit_receipt_t) :: receipt_c, empty_receipt
  logical :: ok, did_commit, available
  integer :: status, receipt_status, commit_status
  real(real64) :: t0, t1

  call setup_solver(parameters, forcing, config)
  call kernel%bind_model(model)

  call capture_water_transfer_trial_provenance(empty_candidate, water_invalid, status)
  call require(status == AWT_PROV_INVALID_WATER .and. .not. water_invalid%ready(), 'invalid water candidate fails closed')
  call capture_thermal_field_trial_provenance(empty_candidate, thermal_invalid, status)
  call require(status == AWT_PROV_INVALID_THERMAL .and. .not. thermal_invalid%ready(), 'invalid thermal candidate fails closed')

  call setup_committed(state_a, 101_int64, 0.0_real64)
  call state_a%capture_checkpoint(cp_a0, ok)
  call require(ok, 'capture A revision-zero checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, state_a, cp_a0, 0.0_real64, 0.5_real64, cand_a, diag_a)

  call capture_water_transfer_trial_provenance(cand_a, water_a, status)
  call require(status == AWT_PROV_OK .and. water_a%ready(), 'water provenance captured from real candidate')
  call capture_thermal_field_trial_provenance(cand_a, thermal_a, status)
  call require(status == AWT_PROV_OK .and. thermal_a%ready(), 'thermal provenance captured from real candidate')
  call bind_water_thermal_trial_provenance(water_a, thermal_a, binding_a, status)
  call require(status == AWT_PROV_OK .and. binding_a%ready(), 'same-candidate provenance binds')

  call setup_committed(state_b, 202_int64, 0.0_real64)
  call state_b%capture_checkpoint(cp_b0, ok)
  call require(ok, 'capture B checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, state_b, cp_b0, 0.0_real64, 0.5_real64, cand_b, diag_b)
  call capture_thermal_field_trial_provenance(cand_b, thermal_other, status)
  call require(status == AWT_PROV_OK, 'B thermal provenance captured')
  call bind_water_thermal_trial_provenance(water_a, thermal_other, binding_invalid, status)
  call require(status == AWT_PROV_LINEAGE_MISMATCH .and. .not. binding_invalid%ready(), 'lineage mismatch fails closed')

  call advance_candidate(kernel, parameters, forcing, config, state_a, cp_a0, 0.0_real64, 0.75_real64, &
       cand_a_interval, diag_a_interval)
  call capture_thermal_field_trial_provenance(cand_a_interval, thermal_other, status)
  call require(status == AWT_PROV_OK, 'different-interval thermal provenance captured')
  call bind_water_thermal_trial_provenance(water_a, thermal_other, binding_invalid, status)
  call require(status == AWT_PROV_INTERVAL_MISMATCH .and. .not. binding_invalid%ready(), 'interval mismatch fails closed')

  call advance_candidate(kernel, parameters, forcing, config, state_a, cp_a0, 0.0_real64, &
       0.5_real64 + 16.0_real64*epsilon(1.0_real64), cand_a_near, diag_a_near)
  call capture_thermal_field_trial_provenance(cand_a_near, thermal_other, status)
  call require(status == AWT_PROV_OK, 'near-identical thermal interval captured')
  call bind_water_thermal_trial_provenance(water_a, thermal_other, binding_invalid, status)
  call require(status == AWT_PROV_OK .and. binding_invalid%ready(), 'canonical time identity tolerance preserved')

  call advance_candidate(kernel, parameters, forcing, config, state_a, cp_a0, 0.0_real64, 0.25_real64, &
       cand_a_winner, diag_a_winner)
  call kernel%commit_candidate(state_a, cand_a_winner, diag_a_winner, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'advance A revision for mismatch test')
  call state_a%capture_checkpoint(cp_a1, ok)
  call require(ok, 'capture A revision-one checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, state_a, cp_a1, 0.25_real64, 0.5_real64, &
       cand_a_rev1, diag_a_rev1)
  call capture_thermal_field_trial_provenance(cand_a_rev1, thermal_other, status)
  call require(status == AWT_PROV_OK, 'revision-one thermal provenance captured')
  call bind_water_thermal_trial_provenance(water_a, thermal_other, binding_invalid, status)
  call require(status == AWT_PROV_REVISION_MISMATCH .and. .not. binding_invalid%ready(), 'revision mismatch fails closed')

  call setup_committed(state_c, 303_int64, 0.0_real64)
  call state_c%capture_checkpoint(cp_c0, ok)
  call require(ok, 'capture C checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, state_c, cp_c0, 0.0_real64, 0.6_real64, cand_c, diag_c)
  call capture_water_transfer_trial_provenance(cand_c, water_c, status)
  call require(status == AWT_PROV_OK, 'C water provenance captured')
  call capture_thermal_field_trial_provenance(cand_c, thermal_c, status)
  call require(status == AWT_PROV_OK, 'C thermal provenance captured')
  call bind_water_thermal_trial_provenance(water_c, thermal_c, binding_c, status)
  call require(status == AWT_PROV_OK .and. binding_c%ready(), 'C provenance binds before commit')

  call authorize_accepted_water_thermal_provenance(binding_c, empty_receipt, accepted_invalid, status)
  call require(status == AWT_PROV_RECEIPT_NOT_ACCEPTED .and. .not. accepted_invalid%ready(), &
       'uncommitted binding cannot become accepted')

  call fmr_commit_candidate_with_receipt(kernel, cp_c0, state_c, cand_c, diag_c, did_commit, receipt_c, &
       receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt_c%ready(), &
       'canonical receipt created by real accepted commit')
  call authorize_accepted_water_thermal_provenance(binding_c, receipt_c, accepted, status)
  call require(status == AWT_PROV_OK .and. accepted%ready(), 'matching accepted receipt authorizes provenance')
  call require(accepted%current_lineage_id() == 303_int64, 'accepted lineage preserved')
  call require(accepted%origin_revision() == 0_int64, 'accepted origin revision preserved')
  call require(accepted%committed_revision() == 1_int64, 'accepted committed revision preserved')
  call accepted%origin_interval(t0, t1, available)
  call require(available .and. bitwise_equal(t0, 0.0_real64) .and. bitwise_equal(t1, 0.6_real64), &
       'accepted interval preserved')

  call setup_committed(state_d, 404_int64, 0.0_real64)
  call state_d%capture_checkpoint(cp_d0, ok)
  call require(ok, 'capture D checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, state_d, cp_d0, 0.0_real64, 0.6_real64, cand_d, diag_d)
  call capture_water_transfer_trial_provenance(cand_d, water_d, status)
  call require(status == AWT_PROV_OK, 'D water provenance captured')
  call capture_thermal_field_trial_provenance(cand_d, thermal_d, status)
  call require(status == AWT_PROV_OK, 'D thermal provenance captured')
  call bind_water_thermal_trial_provenance(water_d, thermal_d, binding_d, status)
  call require(status == AWT_PROV_OK .and. binding_d%ready(), 'D provenance binds')
  call authorize_accepted_water_thermal_provenance(binding_d, receipt_c, accepted_invalid, status)
  call require(status == AWT_PROV_RECEIPT_MISMATCH .and. .not. accepted_invalid%ready(), &
       'receipt from another lineage cannot authorize binding')

  print '(a)', 'EB-I10 accepted water thermal provenance: PASS'

contains

  subroutine setup_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(ebi10_state_t :: physical)
    select type (physical)
    type is (ebi10_state_t)
      physical%storage_value = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'initialize committed state')
  end subroutine setup_committed

  subroutine setup_solver(p, f, c)
    type(ebi10_parameters_t), intent(out) :: p
    type(ebi10_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c

    p%flux_rate = 0.1_real64
    f%scale = 1.0_real64
    c%transaction%temporal_tolerance = 1.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine setup_solver

  subroutine advance_candidate(k, p, f, c, state, checkpoint, t0_in, t1_in, candidate_out, diagnostics_out)
    type(kernel_executor_t), intent(inout) :: k
    type(ebi10_parameters_t), intent(in) :: p
    type(ebi10_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(in) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0_in, t1_in
    type(kernel_candidate_state_t), intent(out) :: candidate_out
    type(kernel_diagnostics_t), intent(out) :: diagnostics_out
    type(kernel_result_t) :: result

    call k%advance_interval(p, state, f, c, t0_in, t1_in, result, candidate_out, diagnostics_out, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-KT trial completes')
    call require(candidate_out%ready(), 'F-KT candidate materialized')
  end subroutine advance_candidate

  logical function bitwise_equal(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function bitwise_equal

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(a,1x,a)', 'EB-I10 FAIL:', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i10_accepted_water_thermal_provenance
