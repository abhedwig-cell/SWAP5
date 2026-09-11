module mod_fvq56_state_derived_capacity
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  implicit none
  private

  integer, parameter, public :: FVQ56_CAPACITY_DERIVED = 0
  integer, parameter, public :: FVQ56_CAPACITY_REJECT = 1
  integer, parameter, public :: FVQ56_CAPACITY_NONFINITE = 2

  type, extends(surface_evaporation_capacity_provider_t), public :: fvq56_capacity_provider_t
    integer :: behavior = FVQ56_CAPACITY_DERIVED
    real(real64) :: multiplier = 1.0_real64
  contains
    procedure :: evaluate => fvq56_evaluate_capacity
  end type fvq56_capacity_provider_t

  public :: fvq56_expected_capacity

contains

  pure real(real64) function fvq56_expected_capacity(state) result(value)
    type(soil_water_physical_state_t), intent(in) :: state
    value = 0.0007_real64 * sum(abs(state%pressure_head)) + &
            0.12_real64 * sum(state%water_content) / real(state%active_nodes, real64) + &
            0.0002_real64 * abs(state%groundwater_level)
  end function fvq56_expected_capacity

  subroutine fvq56_evaluate_capacity(self, base_state, result)
    class(fvq56_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result

    result = surface_evaporation_capacity_result_t()
    select case (self%behavior)
    case (FVQ56_CAPACITY_REJECT)
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'fvq56-reject'
      return
    case (FVQ56_CAPACITY_NONFINITE)
      result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
      result%evaporation_capacity = ieee_value(0.0_real64, ieee_quiet_nan)
      result%route = 'fvq56-nonfinite'
      return
    case default
      continue
    end select

    if (base_state%active_nodes <= 0) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'fvq56-invalid-base'
      return
    end if
    if (.not. allocated(base_state%pressure_head) .or. .not. allocated(base_state%water_content)) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'fvq56-invalid-base'
      return
    end if
    if (size(base_state%pressure_head) /= base_state%active_nodes .or. &
        size(base_state%water_content) /= base_state%active_nodes) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'fvq56-invalid-base'
      return
    end if

    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%evaporation_capacity = self%multiplier * fvq56_expected_capacity(base_state)
    result%route = 'fvq56-derived'
  end subroutine fvq56_evaluate_capacity

end module mod_fvq56_state_derived_capacity

program test_fvq56_surface_evaporation_runtime_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_surface_evaporation_capacity_contract, only: SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t, SURFACE_EVAP_AVAILABLE, &
       SURFACE_EVAP_NOT_RUN
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, FMR_SURFACE_EVAP_RUNTIME_OK, &
       FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, &
       FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED
  use mod_fvq56_state_derived_capacity, only: fvq56_capacity_provider_t, fvq56_expected_capacity, &
       FVQ56_CAPACITY_DERIVED, FVQ56_CAPACITY_REJECT, FVQ56_CAPACITY_NONFINITE
  implicit none

  real(real64), parameter :: bare_demands(4) = [0.0_real64, 0.03_real64, 0.17_real64, 0.90_real64]
  real(real64), parameter :: pond_demands(3) = [0.0_real64, 0.11_real64, 0.75_real64]
  real(real64), parameter :: pondings(4) = [0.0_real64, FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, &
       1.000001_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 0.015_real64]

  type(kernel_committed_state_t) :: committed, uninitialized
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag, bad_et_diag
  type(fvq56_capacity_provider_t) :: provider
  type(surface_evaporation_result_t) :: result, a1, b, a2
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag, da1, db, da2
  type(process_hydraulic_view_t) :: before_view, after_view
  type(soil_water_physical_state_t) :: expected_state
  real(real64) :: expected_capacity, expected_bare, expected_pond
  integer :: state_case, ip, ib, iw, cases
  logical :: ok

  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.
  provider = fvq56_capacity_provider_t()
  cases = 0

  do state_case = 1, 3
    do ip = 1, size(pondings)
      call make_committed_state(state_case, pondings(ip), committed, expected_state)
      expected_capacity = fvq56_expected_capacity(expected_state)
      do ib = 1, size(bare_demands)
        do iw = 1, size(pond_demands)
          et = reference_et_demand_result_t()
          et%potential_soil_evaporation_cm_per_day = bare_demands(ib)
          et%potential_pond_evaporation_cm_per_day = pond_demands(iw)
          provider%behavior = FVQ56_CAPACITY_DERIVED
          provider%multiplier = 1.0_real64

          call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
          call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5601)
          call require(result%status == SURFACE_EVAP_AVAILABLE .and. diag%result_produced, 5602)
          call require(diag%demand_accepted .and. diag%committed_view_built .and. diag%capacity_called .and. &
                       diag%process_called, 5603)
          call require_bits(diag%base_ponding_depth, pondings(ip), 5604)
          call require_close(diag%raw_evaporation_capacity, expected_capacity, 5605)
          call require(diag%surface_is_ponded .eqv. &
                       (pondings(ip) > FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM), 5606)

          if (pondings(ip) > FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM) then
            expected_bare = 0.0_real64
            expected_pond = pond_demands(iw)
            call require(trim(result%route) == 'ponded', 5607)
          else
            expected_bare = min(bare_demands(ib), max(0.0_real64, expected_capacity))
            expected_pond = 0.0_real64
            call require(trim(result%route) == 'dry', 5608)
          end if
          call require_close(result%bare_soil_evaporation, expected_bare, 5609)
          call require_close(result%ponded_water_evaporation, expected_pond, 5610)
          call require(trim(diag%route) == trim(result%route), 5611)
          cases = cases + 1
          write(*,'(A,I0,A,I0,A,I0,A,I0,A,Z16.16,A,Z16.16,A,Z16.16)') &
               'FVQ56_CASE=', cases, ' STATE=', state_case, ' POND=', ip, ' DEM=', 10*ib+iw, &
               ' CAP=', transfer(diag%raw_evaporation_capacity, 0_int64), &
               ' BARE=', transfer(result%bare_soil_evaporation, 0_int64), &
               ' PONDEV=', transfer(result%ponded_water_evaporation, 0_int64)
        end do
      end do
    end do
  end do
  call require(cases == 144, 5612)
  write(*,'(A)') 'FVQ56_HELDOUT_CLOSED_FORM_CASES_144=PASS'
  write(*,'(A)') 'FVQ56_STATE_DERIVED_CAPACITY_TRANSFER=PASS'
  write(*,'(A)') 'FVQ56_THRESHOLD_CLASSIFICATION=PASS'

  ! Finite negative raw capacity is diagnostic input; dry structural evaporation must clamp it to physical zero.
  call make_committed_state(2, 0.0_real64, committed, expected_state)
  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.44_real64
  et%potential_pond_evaporation_cm_per_day = 0.66_real64
  provider%behavior = FVQ56_CAPACITY_DERIVED
  provider%multiplier = -1.0_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. diag%result_produced, 5613)
  call require(diag%raw_evaporation_capacity < 0.0_real64, 5614)
  call require_bits(result%bare_soil_evaporation, 0.0_real64, 5615)
  call require_bits(result%ponded_water_evaporation, 0.0_real64, 5616)
  write(*,'(A)') 'FVQ56_NEGATIVE_FINITE_CAPACITY_DRY_ZERO=PASS'

  ! An active physical zero remains an available result, not a rejection.
  provider%multiplier = 1.0_real64
  et%potential_soil_evaporation_cm_per_day = 0.0_real64
  et%potential_pond_evaporation_cm_per_day = 0.0_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK .and. diag%result_produced, 5617)
  call require(result%status == SURFACE_EVAP_AVAILABLE, 5618)
  call require_bits(result%bare_soil_evaporation, 0.0_real64, 5619)
  write(*,'(A)') 'FVQ56_ACTIVE_ZERO_AVAILABLE=PASS'

  ! Rejected ET provenance must stop before the capacity provider or structural process.
  bad_et_diag = et_diag
  bad_et_diag%result_produced = .false.
  provider%behavior = FVQ56_CAPACITY_REJECT
  call fmr_materialize_restricted_surface_evaporation(committed, et, bad_et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, 5620)
  call require(.not. diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 5621)
  call require(result%status == SURFACE_EVAP_NOT_RUN, 5622)
  write(*,'(A)') 'FVQ56_DEMAND_PROVENANCE_FAIL_CLOSED=PASS'

  ! Unsupported and nonfinite capacity responses both fail before process publication.
  provider%behavior = FVQ56_CAPACITY_REJECT
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 5623)
  call require(diag%capacity_status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 5624)
  call require(diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 5625)
  provider%behavior = FVQ56_CAPACITY_NONFINITE
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 5626)
  call require(diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 5627)
  write(*,'(A)') 'FVQ56_CAPACITY_FAIL_CLOSED=PASS'

  ! Invalid structural demand can only fail after the admitted capacity call and must publish no result.
  provider%behavior = FVQ56_CAPACITY_DERIVED
  provider%multiplier = 1.0_real64
  et%potential_soil_evaporation_cm_per_day = -0.01_real64
  et%potential_pond_evaporation_cm_per_day = 0.25_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED, 5628)
  call require(diag%capacity_called .and. diag%process_called .and. .not. diag%result_produced, 5629)
  call require(result%status == SURFACE_EVAP_NOT_RUN, 5630)
  write(*,'(A)') 'FVQ56_PROCESS_INVALID_DEMAND_FAIL_CLOSED=PASS'

  ! An unavailable committed state must fail before capacity evaluation.
  et%potential_soil_evaporation_cm_per_day = 0.21_real64
  call fmr_materialize_restricted_surface_evaporation(uninitialized, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, 5631)
  call require(.not. diag%capacity_called .and. .not. diag%result_produced, 5632)
  write(*,'(A)') 'FVQ56_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS'

  ! A-B-A and committed-state immutability.
  call make_committed_state(3, 0.0_real64, committed, expected_state)
  call fmr_build_committed_process_hydraulic_view(committed, before_view, ok)
  call require(ok, 5633)
  et%potential_soil_evaporation_cm_per_day = 0.31_real64
  et%potential_pond_evaporation_cm_per_day = 0.47_real64
  provider%multiplier = 0.8_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, a1, da1)
  provider%multiplier = 1.7_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, b, db)
  provider%multiplier = 0.8_real64
  call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, a2, da2)
  call require_result_identical(a1, a2, 5634)
  call require_diag_identical(da1, da2, 5635)
  call require(.not. same_bits(b%bare_soil_evaporation, a1%bare_soil_evaporation), 5636)
  call fmr_build_committed_process_hydraulic_view(committed, after_view, ok)
  call require(ok, 5637)
  call require_views_identical(before_view, after_view, 5638)
  write(*,'(A)') 'FVQ56_ABA_REPEATABILITY=PASS'
  write(*,'(A)') 'FVQ56_COMMITTED_STATE_IMMUTABLE=PASS'
  write(*,'(A)') 'FVQ56_INDEPENDENT_ORACLE=PASS'

contains

  subroutine make_committed_state(state_case, ponding, value, physical)
    integer, intent(in) :: state_case
    real(real64), intent(in) :: ponding
    type(kernel_committed_state_t), intent(out) :: value
    type(soil_water_physical_state_t), intent(out) :: physical
    type(fmr_b110_physical_state_t) :: source
    integer :: i, n
    logical :: initialized

    n = state_case + 1
    source = fmr_b110_physical_state_t()
    source%active_nodes = n
    allocate(source%pressure_head(n), source%water_content(n))
    do i = 1, n
      source%pressure_head(i) = -real(17*state_case + 23*i, real64)
      source%water_content(i) = 0.08_real64 + 0.025_real64*real(state_case, real64) + &
                                0.011_real64*real(i, real64)
    end do
    source%ponding_depth = ponding
    source%groundwater_level = -70.0_real64 - 31.0_real64*real(state_case, real64)
    call fmr_new_b110_committed_state(value, int(56000 + state_case, int64), source, &
                                      -3.25_real64 + 0.5_real64*real(state_case, real64), initialized)
    call require(initialized, 5640 + state_case)

    physical = soil_water_physical_state_t()
    physical%active_nodes = n
    allocate(physical%pressure_head(n), physical%water_content(n))
    physical%pressure_head = source%pressure_head
    physical%water_content = source%water_content
    physical%ponding_depth = source%ponding_depth
    physical%groundwater_level = source%groundwater_level
  end subroutine make_committed_state

  subroutine require_views_identical(a, c, code)
    type(process_hydraulic_view_t), intent(in) :: a, c
    integer, intent(in) :: code
    call require(a%active_nodes == c%active_nodes, code)
    call require(allocated(a%pressure_head) .and. allocated(c%pressure_head), code)
    call require(allocated(a%water_content) .and. allocated(c%water_content), code)
    call require(size(a%pressure_head) == size(c%pressure_head), code)
    call require(size(a%water_content) == size(c%water_content), code)
    call require(all(transfer(a%pressure_head, [0_int64], size(a%pressure_head)) == &
                     transfer(c%pressure_head, [0_int64], size(c%pressure_head))), code)
    call require(all(transfer(a%water_content, [0_int64], size(a%water_content)) == &
                     transfer(c%water_content, [0_int64], size(c%water_content))), code)
    call require_bits(a%ponding_depth, c%ponding_depth, code)
    call require_bits(a%groundwater_level, c%groundwater_level, code)
  end subroutine require_views_identical

  subroutine require_result_identical(a, c, code)
    type(surface_evaporation_result_t), intent(in) :: a, c
    integer, intent(in) :: code
    call require(a%status == c%status, code)
    call require_bits(a%bare_soil_evaporation, c%bare_soil_evaporation, code)
    call require_bits(a%ponded_water_evaporation, c%ponded_water_evaporation, code)
    call require(a%route == c%route, code)
  end subroutine require_result_identical

  subroutine require_diag_identical(a, c, code)
    type(fmr_surface_evaporation_runtime_diagnostics_t), intent(in) :: a, c
    integer, intent(in) :: code
    call require(a%status == c%status .and. a%capacity_status == c%capacity_status .and. &
                 a%process_status == c%process_status, code)
    call require(a%demand_accepted .eqv. c%demand_accepted, code)
    call require(a%committed_view_built .eqv. c%committed_view_built, code)
    call require(a%capacity_called .eqv. c%capacity_called, code)
    call require(a%process_called .eqv. c%process_called, code)
    call require(a%surface_is_ponded .eqv. c%surface_is_ponded, code)
    call require(a%result_produced .eqv. c%result_produced, code)
    call require_bits(a%base_ponding_depth, c%base_ponding_depth, code)
    call require_bits(a%raw_evaporation_capacity, c%raw_evaporation_capacity, code)
    call require(a%route == c%route, code)
  end subroutine require_diag_identical

  pure logical function same_bits(a, c) result(same)
    real(real64), intent(in) :: a, c
    same = transfer(a, 0_int64) == transfer(c, 0_int64)
  end function same_bits

  subroutine require_bits(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    call require(same_bits(actual, expected), code)
  end subroutine require_bits

  subroutine require_close(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    call require(abs(actual-expected) <= 2.0e-13_real64*max(1.0_real64,abs(expected)), code)
  end subroutine require_close

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'FVQ56_REQUIRE_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_fvq56_surface_evaporation_runtime_independent
