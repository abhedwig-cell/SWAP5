module mod_fvq56_observing_capacity_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  implicit none
  private

  type, extends(surface_evaporation_capacity_provider_t), public :: observing_capacity_provider_t
    real(real64) :: value = 0.0_real64
    integer :: return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
    logical :: verify_base = .false.
    real(real64) :: expected_ponding = 0.0_real64
  contains
    procedure :: evaluate => observing_capacity_evaluate
  end type observing_capacity_provider_t

contains

  subroutine observing_capacity_evaluate(self, base_state, result)
    class(observing_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    logical :: base_ok

    result = surface_evaporation_capacity_result_t()
    base_ok = .true.
    if (self%verify_base) then
      base_ok = base_state%active_nodes == 3
      base_ok = base_ok .and. allocated(base_state%pressure_head)
      base_ok = base_ok .and. allocated(base_state%water_content)
      if (allocated(base_state%pressure_head)) then
        base_ok = base_ok .and. size(base_state%pressure_head) == 3
        if (size(base_state%pressure_head) == 3) &
          base_ok = base_ok .and. all(base_state%pressure_head == [-80.0_real64, -160.0_real64, -320.0_real64])
      end if
      if (allocated(base_state%water_content)) then
        base_ok = base_ok .and. size(base_state%water_content) == 3
        if (size(base_state%water_content) == 3) &
          base_ok = base_ok .and. all(base_state%water_content == [0.18_real64, 0.23_real64, 0.29_real64])
      end if
      base_ok = base_ok .and. base_state%ponding_depth == self%expected_ponding
      base_ok = base_ok .and. base_state%groundwater_level == -245.0_real64
    end if

    if (.not. base_ok) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'base-mismatch'
      return
    end if

    result%status = self%return_status
    result%evaporation_capacity = self%value
    if (ieee_is_finite(self%value)) then
      result%route = 'heldout-finite'
    else
      result%route = 'heldout-nonfinite'
    end if
  end subroutine observing_capacity_evaluate

end module mod_fvq56_observing_capacity_provider

program test_fvq56_surface_evaporation_runtime_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_surface_evaporation_capacity_contract, only: SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t, SURFACE_EVAP_AVAILABLE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, FMR_SURFACE_EVAP_RUNTIME_OK, &
       FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, &
       FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED
  use mod_fvq56_observing_capacity_provider, only: observing_capacity_provider_t
  implicit none

  type(kernel_committed_state_t) :: dry, below, exact, above, ponded, uninitialized
  type(reference_et_demand_result_t) :: demand, bad_demand
  type(fmr_reference_et_binding_diagnostics_t) :: demand_diag, rejected_diag
  type(observing_capacity_provider_t) :: provider
  type(surface_evaporation_result_t) :: result, a1, b1, a2
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag
  type(process_hydraulic_view_t) :: before_view, after_view
  real(real64) :: threshold, just_above, nanv
  logical :: ok

  threshold = FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
  just_above = threshold + spacing(threshold)
  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  demand = reference_et_demand_result_t()
  demand%potential_soil_evaporation_cm_per_day = 0.73_real64
  demand%potential_pond_evaporation_cm_per_day = 0.91_real64
  demand_diag = fmr_reference_et_binding_diagnostics_t()
  demand_diag%status = FMR_REFERENCE_ET_BINDING_OK
  demand_diag%result_produced = .true.

  call make_committed(0.0_real64, 5601_int64, dry)
  call make_committed(0.5_real64*threshold, 5602_int64, below)
  call make_committed(threshold, 5603_int64, exact)
  call make_committed(just_above, 5604_int64, above)
  call make_committed(0.25_real64, 5605_int64, ponded)

  provider%verify_base = .true.
  provider%expected_ponding = 0.0_real64
  provider%value = 0.31_real64
  provider%return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 1)
  call require(diag%result_produced .and. result%status == SURFACE_EVAP_AVAILABLE, 2)
  call require(.not. diag%surface_is_ponded, 3)
  call require_same(diag%raw_evaporation_capacity, 0.31_real64, 4)
  call require_same(result%bare_soil_evaporation, 0.31_real64, 5)
  call require_same(result%ponded_water_evaporation, 0.0_real64, 6)
  write(*,'(A)') 'FVQ56_EXACT_COMMITTED_BASE_TO_CAPACITY=PASS'
  write(*,'(A)') 'FVQ56_DRY_POSITIVE_CAPACITY=PASS'

  provider%verify_base = .false.
  provider%value = 0.0_real64
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 7)
  call require_same(result%bare_soil_evaporation, 0.0_real64, 8)
  write(*,'(A)') 'FVQ56_DRY_ZERO_CAPACITY=PASS'

  provider%value = -0.27_real64
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 9)
  call require_same(diag%raw_evaporation_capacity, -0.27_real64, 10)
  call require_same(result%bare_soil_evaporation, 0.0_real64, 11)
  write(*,'(A)') 'FVQ56_SIGNED_NEGATIVE_CAPACITY_PRESERVED_AND_CLAMPED=PASS'

  provider%value = 0.42_real64
  call assert_dry_route(below, demand, demand_diag, provider, 12)
  call assert_dry_route(exact, demand, demand_diag, provider, 20)
  call assert_ponded_route(above, demand, demand_diag, provider, 30)
  write(*,'(A)') 'FVQ56_PONDING_BELOW_EXACT_ABOVE_BOUNDARY=PASS'

  provider%value = -3.0_real64
  call assert_ponded_route(ponded, demand, demand_diag, provider, 40)
  write(*,'(A)') 'FVQ56_PONDED_ROUTE_INDEPENDENT_OF_SIGNED_CAPACITY=PASS'

  provider%value = nanv
  provider%return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 50)
  call require(diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 51)
  write(*,'(A)') 'FVQ56_AVAILABLE_NONFINITE_CAPACITY_FAIL_CLOSED=PASS'

  provider%value = 0.2_real64
  provider%return_status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 52)
  call require(.not. diag%process_called .and. .not. diag%result_produced, 53)
  write(*,'(A)') 'FVQ56_CAPACITY_STATUS_FAIL_CLOSED=PASS'

  rejected_diag = demand_diag
  rejected_diag%result_produced = .false.
  provider%return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  call fmr_materialize_restricted_surface_evaporation(dry, demand, rejected_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, 54)
  call require(.not. diag%capacity_called .and. .not. diag%process_called, 55)
  write(*,'(A)') 'FVQ56_REJECTED_DEMAND_SHORT_CIRCUIT=PASS'

  bad_demand = demand
  bad_demand%potential_soil_evaporation_cm_per_day = -0.01_real64
  provider%value = 0.2_real64
  call fmr_materialize_restricted_surface_evaporation(dry, bad_demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED, 56)
  call require(diag%capacity_called .and. diag%process_called .and. .not. diag%result_produced, 57)
  call require(result%status == 0, 58)
  write(*,'(A)') 'FVQ56_NEGATIVE_ET_DEMAND_PROCESS_FAIL_CLOSED=PASS'

  call fmr_materialize_restricted_surface_evaporation(uninitialized, demand, demand_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, 59)
  call require(.not. diag%capacity_called .and. .not. diag%result_produced, 60)
  write(*,'(A)') 'FVQ56_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS'

  call fmr_build_committed_process_hydraulic_view(dry, before_view, ok)
  call require(ok, 61)
  provider%value = 0.19_real64
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, a1, diag)
  provider%value = 0.37_real64
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, b1, diag)
  provider%value = 0.19_real64
  call fmr_materialize_restricted_surface_evaporation(dry, demand, demand_diag, provider, a2, diag)
  call require_same(a1%bare_soil_evaporation, a2%bare_soil_evaporation, 62)
  call require_same(a1%ponded_water_evaporation, a2%ponded_water_evaporation, 63)
  call require(abs(b1%bare_soil_evaporation-a1%bare_soil_evaporation) > 0.0_real64, 64)
  call fmr_build_committed_process_hydraulic_view(dry, after_view, ok)
  call require(ok, 65)
  call require(same_view(before_view, after_view), 66)
  write(*,'(A)') 'FVQ56_ABA_DETERMINISTIC_REPLAY=PASS'
  write(*,'(A)') 'FVQ56_COMMITTED_STATE_NONMUTATION=PASS'
  write(*,'(A)') 'FVQ56_HARD_MASS_NONINTERFERENCE=PASS'
  write(*,'(A)') 'FVQ56_INDEPENDENT_ORACLE=PASS'

contains

  subroutine make_committed(ponding, lineage, committed)
    real(real64), intent(in) :: ponding
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_state_t) :: state
    logical :: initialized

    state%active_nodes = 3
    allocate(state%pressure_head(3), state%water_content(3))
    state%pressure_head = [-80.0_real64, -160.0_real64, -320.0_real64]
    state%water_content = [0.18_real64, 0.23_real64, 0.29_real64]
    state%ponding_depth = ponding
    state%groundwater_level = -245.0_real64
    call fmr_new_b110_committed_state(committed, lineage, state, 7.25_real64, initialized)
    call require(initialized, 67)
  end subroutine make_committed

  subroutine assert_dry_route(committed, et, et_diag, cap, code)
    type(kernel_committed_state_t), intent(in) :: committed
    type(reference_et_demand_result_t), intent(in) :: et
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diag
    type(observing_capacity_provider_t), intent(in) :: cap
    integer, intent(in) :: code
    type(surface_evaporation_result_t) :: local_result
    type(fmr_surface_evaporation_runtime_diagnostics_t) :: local_diag
    call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, cap, local_result, local_diag)
    call require(local_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, code)
    call require(.not. local_diag%surface_is_ponded, code+1)
    call require_same(local_result%bare_soil_evaporation, min(et%potential_soil_evaporation_cm_per_day, cap%value), code+2)
    call require_same(local_result%ponded_water_evaporation, 0.0_real64, code+3)
  end subroutine assert_dry_route

  subroutine assert_ponded_route(committed, et, et_diag, cap, code)
    type(kernel_committed_state_t), intent(in) :: committed
    type(reference_et_demand_result_t), intent(in) :: et
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diag
    type(observing_capacity_provider_t), intent(in) :: cap
    integer, intent(in) :: code
    type(surface_evaporation_result_t) :: local_result
    type(fmr_surface_evaporation_runtime_diagnostics_t) :: local_diag
    call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, cap, local_result, local_diag)
    call require(local_diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, code)
    call require(local_diag%surface_is_ponded, code+1)
    call require_same(local_result%bare_soil_evaporation, 0.0_real64, code+2)
    call require_same(local_result%ponded_water_evaporation, et%potential_pond_evaporation_cm_per_day, code+3)
  end subroutine assert_ponded_route

  logical function same_view(a, b)
    type(process_hydraulic_view_t), intent(in) :: a, b
    same_view = a%active_nodes == b%active_nodes
    same_view = same_view .and. allocated(a%pressure_head) .and. allocated(b%pressure_head)
    same_view = same_view .and. allocated(a%water_content) .and. allocated(b%water_content)
    if (.not. same_view) return
    same_view = same_view .and. all(a%pressure_head == b%pressure_head)
    same_view = same_view .and. all(a%water_content == b%water_content)
    same_view = same_view .and. a%ponding_depth == b%ponding_depth
    same_view = same_view .and. a%groundwater_level == b%groundwater_level
  end function same_view

  subroutine require_same(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    call require(abs(actual-expected) <= 1.0e-13_real64*max(1.0_real64,abs(expected)), code)
  end subroutine require_same

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'FVQ56_REQUIRE_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_fvq56_surface_evaporation_runtime_independent
