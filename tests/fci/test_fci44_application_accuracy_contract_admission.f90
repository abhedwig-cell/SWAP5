program test_fci44_application_accuracy_contract_admission
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD, COUPLING_QOI_GROUNDWATER_DRAWDOWN
  implicit none

  type(coupling_application_accuracy_contract_t) :: contract
  type(canonical_numerical_config_t) :: config
  real(real64) :: budget
  logical :: available, materialized
  integer :: failures

  failures = 0

  config%model_temporal_indicator_budget_available = .true.
  config%model_temporal_indicator_budget = 99.0_real64
  call contract%materialize_model_temporal_budget(config, materialized)
  call check(.not. materialized, 'unconfigured contract does not materialize', failures)
  call check(.not. config%model_temporal_indicator_budget_available, 'unconfigured contract clears stale availability', failures)
  call check(close_real(config%model_temporal_indicator_budget, 0.0_real64), 'unconfigured contract clears stale value', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.25_real64)
  call contract%evaluate_temporal_budget_cm(budget, available)
  call check(available .and. close_real(budget, 3.0_real64), 'HEAD budget composes exactly', failures)
  call contract%materialize_model_temporal_budget(config, materialized)
  call check(materialized, 'HEAD budget materializes', failures)
  call check(config%model_temporal_indicator_budget_available, 'generic carrier availability set', failures)
  call check(close_real(config%model_temporal_indicator_budget, 3.0_real64), 'generic carrier receives native head budget', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_DRAWDOWN, 8.0_real64, 0.125_real64)
  call contract%evaluate_temporal_budget_cm(budget, available)
  call check(available .and. close_real(budget, 1.0_real64), 'DRAWDOWN budget composes exactly', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.25_real64)
  contract%h_app_externally_qualified = .false.
  call check(.not. contract%temporal_budget_ready(), 'unqualified H_app fails closed', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.25_real64)
  contract%a_temporal_externally_qualified = .false.
  call check(.not. contract%temporal_budget_ready(), 'unqualified A_temporal fails closed', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.25_real64)
  contract%application_provenance_id = 0_int64
  call check(.not. contract%temporal_budget_ready(), 'missing application provenance fails closed', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.25_real64)
  contract%temporal_allocation_provenance_id = 0_int64
  call check(.not. contract%temporal_budget_ready(), 'missing temporal allocation provenance fails closed', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 0.0_real64, 0.25_real64)
  call check(.not. contract%temporal_budget_ready(), 'zero H_app fails closed', failures)
  contract%h_app_cm = ieee_value(0.0_real64, ieee_quiet_nan)
  call check(.not. contract%temporal_budget_ready(), 'NaN H_app fails closed', failures)
  contract%h_app_cm = ieee_value(0.0_real64, ieee_positive_inf)
  call check(.not. contract%temporal_budget_ready(), 'infinite H_app fails closed', failures)

  call set_valid_contract(contract, COUPLING_QOI_GROUNDWATER_HEAD, 12.0_real64, 0.0_real64)
  call check(.not. contract%temporal_budget_ready(), 'zero A_temporal fails closed', failures)
  contract%a_temporal = -0.1_real64
  call check(.not. contract%temporal_budget_ready(), 'negative A_temporal fails closed', failures)
  contract%a_temporal = 1.01_real64
  call check(.not. contract%temporal_budget_ready(), 'A_temporal above one fails closed', failures)
  contract%a_temporal = ieee_value(0.0_real64, ieee_quiet_nan)
  call check(.not. contract%temporal_budget_ready(), 'NaN A_temporal fails closed', failures)

  call set_valid_contract(contract, 999, 12.0_real64, 0.25_real64)
  call check(.not. contract%temporal_budget_ready(), 'unsupported QOI fails closed', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FCI44_FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'FCI44_CONTRACT_MATRIX=PASS'
  write(*,'(A)') 'FCI44_NO_DEFAULT_NUMERIC_POLICY=PASS'
  write(*,'(A)') 'FCI44_STALE_BUDGET_CLEARING=PASS'
  write(*,'(A)') 'FCI44_APPLICATION_ACCURACY_CONTRACT=PASS'

contains

  pure logical function close_real(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    close_real = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function close_real

  subroutine set_valid_contract(value, qoi_kind, h_app_cm, a_temporal)
    type(coupling_application_accuracy_contract_t), intent(out) :: value
    integer, intent(in) :: qoi_kind
    real(real64), intent(in) :: h_app_cm, a_temporal

    value%contract_id = 101_int64
    value%contract_version = 3
    value%qoi_kind = qoi_kind
    value%h_app_available = .true.
    value%h_app_cm = h_app_cm
    value%h_app_externally_qualified = .true.
    value%application_provenance_id = 1001_int64
    value%a_temporal_available = .true.
    value%a_temporal = a_temporal
    value%a_temporal_externally_qualified = .true.
    value%temporal_allocation_provenance_id = 2001_int64
  end subroutine set_valid_contract

  subroutine check(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FCI44_CHECK_FAIL: ', trim(label)
    end if
  end subroutine check

end program test_fci44_application_accuracy_contract_admission
