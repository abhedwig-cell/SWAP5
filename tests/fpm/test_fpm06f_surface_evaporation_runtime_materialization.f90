module mod_fpm06f_fake_capacity_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE
  implicit none

  type, extends(surface_evaporation_capacity_provider_t) :: fake_capacity_provider_t
    real(real64) :: value = 0.0_real64
    integer :: return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  contains
    procedure :: evaluate => fake_capacity_evaluate
  end type fake_capacity_provider_t

contains

  subroutine fake_capacity_evaluate(self, base_state, result)
    class(fake_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result

    result = surface_evaporation_capacity_result_t()
    result%status = self%return_status
    result%evaporation_capacity = self%value
    if (base_state%active_nodes > 0) result%route = 'fake-capacity'
  end subroutine fake_capacity_evaluate

end module mod_fpm06f_fake_capacity_provider

program test_fpm06f_surface_evaporation_runtime_materialization
  use, intrinsic :: iso_fortran_env, only: int64, real64
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
       FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED
  use mod_fpm06f_fake_capacity_provider, only: fake_capacity_provider_t
  implicit none

  type(kernel_committed_state_t) :: dry_state, threshold_state, ponded_state, capacity_state, uninitialized_state
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag, rejected_et_diag
  type(fake_capacity_provider_t) :: provider
  type(surface_evaporation_result_t) :: result, a1, b, a2
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag
  type(process_hydraulic_view_t) :: before_view, after_view
  logical :: ok

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.4_real64
  et%potential_pond_evaporation_cm_per_day = 0.6_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.

  call make_committed(0.0_real64, 101_int64, dry_state)
  call make_committed(FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 102_int64, threshold_state)
  call make_committed(10.0_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 103_int64, ponded_state)
  call make_committed(0.0_real64, 104_int64, capacity_state)

  call fmr_build_committed_process_hydraulic_view(dry_state, before_view, ok)
  call require(ok, 601)

  provider%value = 0.25_real64
  provider%return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 602)
  call require(diag%result_produced .and. result%status == SURFACE_EVAP_AVAILABLE, 603)
  call require(.not. diag%surface_is_ponded, 604)
  call require_close(diag%raw_evaporation_capacity, 0.25_real64, 605)
  call require_close(result%bare_soil_evaporation, 0.25_real64, 606)
  call require_close(result%ponded_water_evaporation, 0.0_real64, 607)
  write(*,'(A)') 'FPM06F_DRY_CAPACITY_LIMIT=PASS'

  provider%value = -0.10_real64
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 608)
  call require_close(diag%raw_evaporation_capacity, -0.10_real64, 609)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 610)
  call require_close(result%ponded_water_evaporation, 0.0_real64, 611)
  write(*,'(A)') 'FPM06F_DRY_NEGATIVE_RAW_CAPACITY=PASS'

  provider%value = 0.30_real64
  call fmr_materialize_restricted_surface_evaporation(threshold_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 612)
  call require(.not. diag%surface_is_ponded, 613)
  call require_close(result%bare_soil_evaporation, 0.30_real64, 614)
  write(*,'(A)') 'FPM06F_PONDING_THRESHOLD_EXACT=PASS'

  provider%value = -0.15_real64
  call fmr_materialize_restricted_surface_evaporation(ponded_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 615)
  call require(diag%surface_is_ponded, 616)
  call require_close(diag%raw_evaporation_capacity, -0.15_real64, 617)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 618)
  call require_close(result%ponded_water_evaporation, 0.60_real64, 619)
  write(*,'(A)') 'FPM06F_PONDED_DEMAND=PASS'

  rejected_et_diag = et_diag
  rejected_et_diag%result_produced = .false.
  provider%value = 0.25_real64
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, rejected_et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, 620)
  call require(.not. diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 621)
  write(*,'(A)') 'FPM06F_INVALID_DEMAND_FAIL_CLOSED=PASS'

  call fmr_materialize_restricted_surface_evaporation(uninitialized_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, 622)
  call require(.not. diag%capacity_called .and. .not. diag%result_produced, 623)
  write(*,'(A)') 'FPM06F_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS'

  provider%value = 0.25_real64
  provider%return_status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  call fmr_materialize_restricted_surface_evaporation(capacity_state, et, et_diag, provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 624)
  call require(diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 625)
  write(*,'(A)') 'FPM06F_CAPACITY_FAIL_CLOSED=PASS'

  provider%return_status = SURFACE_EVAP_CAPACITY_AVAILABLE
  provider%value = 0.20_real64
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, et_diag, provider, a1, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 626)
  provider%value = 0.35_real64
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, et_diag, provider, b, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 627)
  provider%value = 0.20_real64
  call fmr_materialize_restricted_surface_evaporation(dry_state, et, et_diag, provider, a2, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 628)
  call require_close(a1%bare_soil_evaporation, a2%bare_soil_evaporation, 629)
  call require_close(a1%ponded_water_evaporation, a2%ponded_water_evaporation, 630)
  call require(abs(b%bare_soil_evaporation-a1%bare_soil_evaporation) > 1.0e-12_real64, 631)
  write(*,'(A)') 'FPM06F_ABA_REPEATABILITY=PASS'

  call fmr_build_committed_process_hydraulic_view(dry_state, after_view, ok)
  call require(ok, 632)
  call require(before_view%active_nodes == after_view%active_nodes, 633)
  call require(all(before_view%pressure_head == after_view%pressure_head), 634)
  call require(all(before_view%water_content == after_view%water_content), 635)
  call require(before_view%ponding_depth == after_view%ponding_depth, 636)
  call require(before_view%groundwater_level == after_view%groundwater_level, 637)
  write(*,'(A)') 'FPM06F_COMMITTED_BASE_UNCHANGED=PASS'
  write(*,'(A)') 'FPM06F_NO_MASS_BOOKING_RESULT_ONLY=PASS'
  write(*,'(A)') 'FPM06F_RUNTIME_MATERIALIZATION_TEST PASS'

contains

  subroutine make_committed(ponding, lineage, committed)
    real(real64), intent(in) :: ponding
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_state_t) :: state
    logical :: initialized

    state%active_nodes = 2
    allocate(state%pressure_head(2), state%water_content(2))
    state%pressure_head = [-100.0_real64, -250.0_real64]
    state%water_content = [0.20_real64, 0.24_real64]
    state%ponding_depth = ponding
    state%groundwater_level = -180.0_real64
    call fmr_new_b110_committed_state(committed, lineage, state, 12.5_real64, initialized)
    call require(initialized, 638)
  end subroutine make_committed

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) error stop code
  end subroutine require

  subroutine require_close(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    call require(abs(actual-expected) <= 1.0e-13_real64*max(1.0_real64,abs(expected)), code)
  end subroutine require_close

end program test_fpm06f_surface_evaporation_runtime_materialization
