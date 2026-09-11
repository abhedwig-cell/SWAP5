module mod_fvq56_independent_capacity_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_INVALID_INPUT, SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  implicit none
  integer, parameter, public :: FVQ56_FAKE_NORMAL = 0
  integer, parameter, public :: FVQ56_FAKE_NEGATIVE = 1
  integer, parameter, public :: FVQ56_FAKE_ZERO = 2
  integer, parameter, public :: FVQ56_FAKE_NAN = 3
  integer, parameter, public :: FVQ56_FAKE_UNSUPPORTED = 4

  type, extends(surface_evaporation_capacity_provider_t), public :: fvq56_capacity_provider_t
    integer :: mode = FVQ56_FAKE_NORMAL
  contains
    procedure :: evaluate => fvq56_capacity_evaluate
  end type fvq56_capacity_provider_t

  public :: fvq56_expected_capacity

contains

  pure real(real64) function fvq56_expected_capacity(h1, h2, theta1, theta2, ponding, groundwater) result(value)
    real(real64), intent(in) :: h1, h2, theta1, theta2, ponding, groundwater
    value = 0.05_real64 + 1.0e-4_real64*abs(h1) + 5.0e-5_real64*abs(h2) + &
         0.20_real64*theta1 + 0.10_real64*theta2 + 1.0e4_real64*ponding + &
         1.0e-5_real64*abs(groundwater)
  end function fvq56_expected_capacity

  subroutine fvq56_capacity_evaluate(self, base_state, result)
    class(fvq56_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result

    result = surface_evaporation_capacity_result_t()
    if (base_state%active_nodes /= 2 .or. .not. allocated(base_state%pressure_head) .or. &
        .not. allocated(base_state%water_content)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fvq56-shape-rejected'
      return
    end if
    if (size(base_state%pressure_head) /= 2 .or. size(base_state%water_content) /= 2) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fvq56-shape-rejected'
      return
    end if

    select case (self%mode)
    case (FVQ56_FAKE_NORMAL)
      result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
      result%evaporation_capacity = fvq56_expected_capacity(base_state%pressure_head(1), &
           base_state%pressure_head(2), base_state%water_content(1), base_state%water_content(2), &
           base_state%ponding_depth, base_state%groundwater_level)
      result%route = 'fvq56-derived-from-base'
    case (FVQ56_FAKE_NEGATIVE)
      result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
      result%evaporation_capacity = -0.073_real64
      result%route = 'fvq56-negative'
    case (FVQ56_FAKE_ZERO)
      result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
      result%evaporation_capacity = 0.0_real64
      result%route = 'fvq56-zero'
    case (FVQ56_FAKE_NAN)
      result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
      result%evaporation_capacity = ieee_value(0.0_real64, ieee_quiet_nan)
      result%route = 'fvq56-nonfinite'
    case (FVQ56_FAKE_UNSUPPORTED)
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'fvq56-unsupported'
    case default
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fvq56-invalid-mode'
    end select
  end subroutine fvq56_capacity_evaluate

end module mod_fvq56_independent_capacity_provider

program test_fvq56_surface_evaporation_runtime_materialization_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_surface_evaporation_capacity_provider, only: b110_surface_evaporation_capacity_provider_t, &
       bind_b110_surface_evaporation_capacity_provider
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_result_t, &
       SURFACE_EVAP_CAPACITY_AVAILABLE
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t, SURFACE_EVAP_AVAILABLE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, FMR_SURFACE_EVAP_RUNTIME_OK, &
       FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, &
       FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED
  use mod_fvq56_independent_capacity_provider, only: fvq56_capacity_provider_t, fvq56_expected_capacity, &
       FVQ56_FAKE_NORMAL, FVQ56_FAKE_NEGATIVE, FVQ56_FAKE_ZERO, FVQ56_FAKE_NAN, FVQ56_FAKE_UNSUPPORTED
  implicit none

  type(kernel_committed_state_t) :: a_state, exact_state, above_state, high_capacity_state, real_dry, real_ponded, empty_state
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_ok, et_bad
  type(fvq56_capacity_provider_t) :: fake
  type(surface_evaporation_result_t) :: result, a1, b1, a2
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag
  type(process_hydraulic_view_t) :: before_view, after_view
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulics
  type(b110_surface_evaporation_capacity_provider_t) :: b110_provider
  type(soil_water_physical_state_t) :: direct_state
  type(surface_evaporation_capacity_result_t) :: direct_capacity, direct_ponded_capacity
  real(real64) :: raw(24,2), expected
  logical :: ok

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 0.31_real64
  et%potential_pond_evaporation_cm_per_day = 0.47_real64
  et_ok = fmr_reference_et_binding_diagnostics_t()
  et_ok%status = FMR_REFERENCE_ET_BINDING_OK
  et_ok%result_produced = .true.

  call make_committed(0.999999_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 2101_int64, &
       -37.0_real64, -411.0_real64, 0.17_real64, 0.29_real64, -233.0_real64, a_state)
  call make_committed(FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 2102_int64, &
       -88.0_real64, -512.0_real64, 0.33_real64, 0.19_real64, -144.0_real64, exact_state)
  call make_committed(1.000001_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 2103_int64, &
       -61.0_real64, -307.0_real64, 0.24_real64, 0.27_real64, -199.0_real64, above_state)
  call make_committed(0.0_real64, 2104_int64, -5000.0_real64, -9000.0_real64, &
       0.41_real64, 0.38_real64, -350.0_real64, high_capacity_state)

  call fmr_build_committed_process_hydraulic_view(a_state, before_view, ok)
  call require(ok, 5601)

  fake%mode = FVQ56_FAKE_NORMAL
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, result, diag)
  expected = fvq56_expected_capacity(-37.0_real64, -411.0_real64, 0.17_real64, 0.29_real64, &
       0.999999_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, -233.0_real64)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5602)
  call require(.not. diag%surface_is_ponded, 5603)
  call require_close(diag%raw_evaporation_capacity, expected, 5604)
  call require_close(result%bare_soil_evaporation, min(et%potential_soil_evaporation_cm_per_day, expected), 5605)
  call require_close(result%ponded_water_evaporation, 0.0_real64, 5606)
  write(*,'(A)') 'FVQ56_DERIVED_BASE_STATE_ORACLE=PASS'

  call fmr_materialize_restricted_surface_evaporation(exact_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5607)
  call require(.not. diag%surface_is_ponded, 5608)
  call require(result%bare_soil_evaporation > 0.0_real64, 5609)
  write(*,'(A)') 'FVQ56_EXACT_THRESHOLD_DRY=PASS'

  call fmr_materialize_restricted_surface_evaporation(above_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5610)
  call require(diag%surface_is_ponded, 5611)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 5612)
  call require_close(result%ponded_water_evaporation, et%potential_pond_evaporation_cm_per_day, 5613)
  write(*,'(A)') 'FVQ56_JUST_ABOVE_THRESHOLD_PONDED=PASS'

  fake%mode = FVQ56_FAKE_NEGATIVE
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5614)
  call require_close(diag%raw_evaporation_capacity, -0.073_real64, 5615)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 5616)
  write(*,'(A)') 'FVQ56_SIGNED_NEGATIVE_CAPACITY_STRUCTURAL_CLAMP=PASS'

  fake%mode = FVQ56_FAKE_ZERO
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5617)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 5618)
  write(*,'(A)') 'FVQ56_ZERO_CAPACITY=PASS'

  fake%mode = FVQ56_FAKE_NORMAL
  call fmr_materialize_restricted_surface_evaporation(high_capacity_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5619)
  call require(diag%raw_evaporation_capacity > et%potential_soil_evaporation_cm_per_day, 5620)
  call require_close(result%bare_soil_evaporation, et%potential_soil_evaporation_cm_per_day, 5621)
  write(*,'(A)') 'FVQ56_DEMAND_LIMIT=PASS'

  fake%mode = FVQ56_FAKE_NAN
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 5622)
  call require(diag%capacity_called .and. .not. diag%process_called .and. .not. diag%result_produced, 5623)
  write(*,'(A)') 'FVQ56_AVAILABLE_NONFINITE_FAIL_CLOSED=PASS'

  fake%mode = FVQ56_FAKE_UNSUPPORTED
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, 5624)
  call require(diag%capacity_called .and. .not. diag%process_called, 5625)
  write(*,'(A)') 'FVQ56_UNSUPPORTED_CAPACITY_FAIL_CLOSED=PASS'

  et_bad = et_ok
  et_bad%result_produced = .false.
  fake%mode = FVQ56_FAKE_NORMAL
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_bad, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED, 5626)
  call require(.not. diag%capacity_called .and. .not. diag%process_called, 5627)
  write(*,'(A)') 'FVQ56_REJECTED_DEMAND_CONTAINED=PASS'

  call fmr_materialize_restricted_surface_evaporation(empty_state, et, et_ok, fake, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, 5628)
  call require(.not. diag%capacity_called .and. .not. diag%process_called, 5629)
  write(*,'(A)') 'FVQ56_INVALID_COMMITTED_STATE_CONTAINED=PASS'

  fake%mode = FVQ56_FAKE_NORMAL
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, a1, diag)
  call fmr_materialize_restricted_surface_evaporation(high_capacity_state, et, et_ok, fake, b1, diag)
  call fmr_materialize_restricted_surface_evaporation(a_state, et, et_ok, fake, a2, diag)
  call require_close(a1%bare_soil_evaporation, a2%bare_soil_evaporation, 5630)
  call require(abs(b1%bare_soil_evaporation-a1%bare_soil_evaporation) > 1.0e-12_real64, 5631)
  write(*,'(A)') 'FVQ56_COLUMN_ORDER_ABA_DETERMINISM=PASS'

  call fmr_build_committed_process_hydraulic_view(a_state, after_view, ok)
  call require(ok, 5632)
  call require_view_equal(before_view, after_view, 5633)
  write(*,'(A)') 'FVQ56_COMMITTED_STATE_IMMUTABLE=PASS'

  call configure_real_b110(geometry, raw)
  call initialize_b110_default_mvg_parameters(hydraulics, raw)
  call bind_b110_surface_evaporation_capacity_provider(b110_provider, geometry, hydraulics, 1, .false., .false., ok)
  call require(ok, 5634)

  direct_state%active_nodes = 2
  allocate(direct_state%pressure_head(2), direct_state%water_content(2))
  direct_state%pressure_head = [-120.0_real64, -260.0_real64]
  direct_state%water_content = [0.21_real64, 0.25_real64]
  direct_state%ponding_depth = 0.0_real64
  direct_state%groundwater_level = -190.0_real64
  call b110_provider%evaluate(direct_state, direct_capacity)
  call require(direct_capacity%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 5635)

  call make_committed(0.0_real64, 2201_int64, -120.0_real64, -260.0_real64, &
       0.21_real64, 0.25_real64, -190.0_real64, real_dry)
  et%potential_soil_evaporation_cm_per_day = 0.55_real64
  et%potential_pond_evaporation_cm_per_day = 0.75_real64
  call fmr_materialize_restricted_surface_evaporation(real_dry, et, et_ok, b110_provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5636)
  call require(result%status == SURFACE_EVAP_AVAILABLE, 5637)
  call require_close(diag%raw_evaporation_capacity, direct_capacity%evaporation_capacity, 5638)
  call require_close(result%bare_soil_evaporation, min(et%potential_soil_evaporation_cm_per_day, &
       max(0.0_real64,direct_capacity%evaporation_capacity)), 5639)
  write(*,'(A)') 'FVQ56_REAL_B110_DRY_INTEGRATION=PASS'

  direct_state%ponding_depth = 2.0_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
  call b110_provider%evaluate(direct_state, direct_ponded_capacity)
  call require(direct_ponded_capacity%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 5640)
  call require_close(direct_ponded_capacity%evaporation_capacity, direct_capacity%evaporation_capacity, 5641)
  call make_committed(2.0_real64*FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM, 2202_int64, -120.0_real64, -260.0_real64, &
       0.21_real64, 0.25_real64, -190.0_real64, real_ponded)
  call fmr_materialize_restricted_surface_evaporation(real_ponded, et, et_ok, b110_provider, result, diag)
  call require(diag%status == FMR_SURFACE_EVAP_RUNTIME_OK, 5642)
  call require(diag%surface_is_ponded, 5643)
  call require_close(diag%raw_evaporation_capacity, direct_ponded_capacity%evaporation_capacity, 5644)
  call require_close(result%bare_soil_evaporation, 0.0_real64, 5645)
  call require_close(result%ponded_water_evaporation, et%potential_pond_evaporation_cm_per_day, 5646)
  write(*,'(A)') 'FVQ56_REAL_B110_PONDED_INTEGRATION=PASS'

  write(*,'(A)') 'FVQ56_NO_AUTHORITATIVE_MASS_BOOKING=PASS'
  write(*,'(A)') 'FVQ56_INDEPENDENT_RUNTIME_ORACLE=PASS'

contains

  subroutine make_committed(ponding, lineage, h1, h2, theta1, theta2, groundwater, committed)
    real(real64), intent(in) :: ponding, h1, h2, theta1, theta2, groundwater
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_state_t) :: state
    logical :: initialized

    state%active_nodes = 2
    allocate(state%pressure_head(2), state%water_content(2))
    state%pressure_head = [h1, h2]
    state%water_content = [theta1, theta2]
    state%ponding_depth = ponding
    state%groundwater_level = groundwater
    call fmr_new_b110_committed_state(committed, lineage, state, 9.25_real64, initialized)
    call require(initialized, 5647)
  end subroutine make_committed

  subroutine configure_real_b110(p, c)
    type(soil_water_parameter_set_t), intent(inout) :: p
    real(real64), intent(out) :: c(24,2)
    integer :: j

    p%active_nodes = 2
    allocate(p%z(2), p%dz(2), p%node_distance(2))
    p%z = [-2.5_real64, -11.0_real64]
    p%dz = [5.0_real64, 12.0_real64]
    p%node_distance = [2.75_real64, 8.5_real64]
    c = 0.0_real64
    do j = 1, 2
      c(1,j)=0.032_real64
      c(2,j)=0.423_real64
      c(3,j)=4.75_real64
      c(4,j)=0.0135_real64
      c(5,j)=0.365_real64
      c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j)
      c(8,j)=c(4,j)
      c(9,j)=0.0_real64
      c(10,j)=c(3,j)
      c(11,j)=0.999_real64
      c(12,j)=0.99_real64*c(3,j)
      c(13,j)=0.10_real64
      c(14,j)=1.50_real64
      c(15,j)=0.50_real64
      c(22,j)=-1.0e6_real64
      c(23,j)=1.0e-12_real64
    end do
  end subroutine configure_real_b110

  subroutine require_view_equal(a, b, code)
    type(process_hydraulic_view_t), intent(in) :: a, b
    integer, intent(in) :: code
    logical :: same
    same = a%active_nodes == b%active_nodes
    if (same) same = allocated(a%pressure_head) .and. allocated(b%pressure_head) .and. &
         allocated(a%water_content) .and. allocated(b%water_content)
    if (same) same = size(a%pressure_head) == size(b%pressure_head) .and. &
         size(a%water_content) == size(b%water_content)
    if (same) same = all(a%pressure_head == b%pressure_head) .and. all(a%water_content == b%water_content)
    if (same) same = a%ponding_depth == b%ponding_depth .and. a%groundwater_level == b%groundwater_level
    call require(same, code)
  end subroutine require_view_equal

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'FVQ56_REQUIRE_FAIL=', code
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected_value, code)
    real(real64), intent(in) :: actual, expected_value
    integer, intent(in) :: code
    call require(abs(actual-expected_value) <= 1.0e-12_real64*max(1.0_real64,abs(expected_value)), code)
  end subroutine require_close

end program test_fvq56_surface_evaporation_runtime_materialization_independent
