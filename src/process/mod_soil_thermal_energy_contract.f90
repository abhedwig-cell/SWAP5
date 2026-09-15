module mod_soil_thermal_energy_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_temperature_contract, only: SOIL_TEMP_OK, soil_temperature_result_t, soil_temperature_diagnostics_t
  implicit none
  private

  integer, parameter, public :: SOIL_THERMAL_ENERGY_OK = 0
  integer, parameter, public :: SOIL_THERMAL_ENERGY_INVALID_INTERVAL = 1
  integer, parameter, public :: SOIL_THERMAL_ENERGY_INVALID_RESULT = 2
  integer, parameter, public :: SOIL_THERMAL_ENERGY_UNSUPPORTED_SCOPE = 3
  integer, parameter, public :: SOIL_THERMAL_ENERGY_INCONSISTENT_ACCOUNTING = 4

  real(real64), parameter :: J_CM2_TO_J_M2 = 1.0e4_real64

  type, public :: soil_thermal_energy_coverage_t
    logical :: sensible_storage_accounted = .false.
    logical :: top_conduction_accounted = .false.
    logical :: bottom_conduction_accounted = .false.
    logical :: liquid_advection_accounted = .false.
    logical :: vapor_transport_accounted = .false.
    logical :: phase_change_accounted = .false.
    logical :: surface_energy_accounted = .false.
  contains
    procedure, public :: restricted_sensible_conduction_complete => coverage_restricted_complete
    procedure, public :: full_physical_energy_complete => coverage_full_physical_complete
  end type soil_thermal_energy_coverage_t

  type, public :: soil_thermal_energy_interval_t
    logical :: available = .false.
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: sensible_storage_change_j_m2 = 0.0_real64
    real(real64) :: top_conductive_energy_into_soil_j_m2 = 0.0_real64
    real(real64) :: bottom_conductive_energy_into_soil_j_m2 = 0.0_real64
    real(real64) :: restricted_sensible_residual_j_m2 = 0.0_real64
    logical :: legacy_restricted_energy_accounting_complete = .false.
    type(soil_thermal_energy_coverage_t) :: coverage
  contains
    procedure, public :: ready => soil_thermal_energy_interval_ready
    procedure, public :: restricted_sensible_conduction_complete => interval_restricted_complete
    procedure, public :: full_physical_energy_complete => interval_full_physical_complete
  end type soil_thermal_energy_interval_t

  public :: build_restricted_soil_thermal_energy_interval

contains

  subroutine build_restricted_soil_thermal_energy_interval(t0, t1, result, diagnostics, interval, status)
    real(real64), intent(in) :: t0, t1
    type(soil_temperature_result_t), intent(in) :: result
    type(soil_temperature_diagnostics_t), intent(in) :: diagnostics
    type(soil_thermal_energy_interval_t), intent(out) :: interval
    integer, intent(out) :: status
    real(real64) :: expected_boundary, expected_residual, scale, tolerance

    interval = soil_thermal_energy_interval_t()
    status = SOIL_THERMAL_ENERGY_INVALID_INTERVAL
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    status = SOIL_THERMAL_ENERGY_INVALID_RESULT
    if (result%status /= SOIL_TEMP_OK .or. .not. result%produced) return
    if (diagnostics%status /= SOIL_TEMP_OK) return
    if (.not. ieee_is_finite(result%top_heat_flux_into_soil_j_cm2_day)) return
    if (.not. ieee_is_finite(result%sensible_storage_change_j_cm2)) return
    if (.not. ieee_is_finite(result%boundary_energy_into_soil_j_cm2)) return
    if (.not. ieee_is_finite(result%energy_residual_j_cm2)) return

    ! This adapter intentionally recognizes only the already-qualified F-PM07B
    ! restricted scope: prescribed top temperature, zero conductive bottom flux,
    ! no snow/frost/latent-heat process in this provider.
    status = SOIL_THERMAL_ENERGY_UNSUPPORTED_SCOPE
    if (.not. diagnostics%prescribed_surface_temperature_used) return
    if (.not. diagnostics%zero_bottom_heat_flux_used) return
    if (diagnostics%frost_active .or. diagnostics%snow_active) return

    expected_boundary = (t1 - t0) * result%top_heat_flux_into_soil_j_cm2_day
    expected_residual = result%sensible_storage_change_j_cm2 - result%boundary_energy_into_soil_j_cm2
    scale = max(1.0_real64, abs(expected_boundary), abs(result%boundary_energy_into_soil_j_cm2), &
         abs(expected_residual), abs(result%energy_residual_j_cm2))
    tolerance = 128.0_real64 * epsilon(1.0_real64) * scale
    status = SOIL_THERMAL_ENERGY_INCONSISTENT_ACCOUNTING
    if (abs(expected_boundary - result%boundary_energy_into_soil_j_cm2) > tolerance) return
    if (abs(expected_residual - result%energy_residual_j_cm2) > tolerance) return

    interval%t0 = t0
    interval%t1 = t1
    interval%sensible_storage_change_j_m2 = J_CM2_TO_J_M2 * result%sensible_storage_change_j_cm2
    interval%top_conductive_energy_into_soil_j_m2 = J_CM2_TO_J_M2 * result%boundary_energy_into_soil_j_cm2
    interval%bottom_conductive_energy_into_soil_j_m2 = 0.0_real64
    interval%restricted_sensible_residual_j_m2 = J_CM2_TO_J_M2 * result%energy_residual_j_cm2
    interval%legacy_restricted_energy_accounting_complete = diagnostics%energy_accounting_complete
    interval%coverage%sensible_storage_accounted = .true.
    interval%coverage%top_conduction_accounted = .true.
    interval%coverage%bottom_conduction_accounted = .true.

    ! These remain false by construction. process_hydraulic_view_t does not
    ! carry phase-resolved water fluxes, and F-PM07B deliberately excluded
    ! latent/ice and a prognostic surface energy balance. Unchanged water
    ! content is therefore not evidence that advective energy transport is zero.
    interval%coverage%liquid_advection_accounted = .false.
    interval%coverage%vapor_transport_accounted = .false.
    interval%coverage%phase_change_accounted = .false.
    interval%coverage%surface_energy_accounted = .false.

    interval%available = .true.
    status = SOIL_THERMAL_ENERGY_OK
  end subroutine build_restricted_soil_thermal_energy_interval

  pure logical function coverage_restricted_complete(self) result(complete)
    class(soil_thermal_energy_coverage_t), intent(in) :: self
    complete = self%sensible_storage_accounted .and. self%top_conduction_accounted .and. &
         self%bottom_conduction_accounted
  end function coverage_restricted_complete

  pure logical function coverage_full_physical_complete(self) result(complete)
    class(soil_thermal_energy_coverage_t), intent(in) :: self
    complete = self%restricted_sensible_conduction_complete() .and. self%liquid_advection_accounted .and. &
         self%vapor_transport_accounted .and. self%phase_change_accounted .and. self%surface_energy_accounted
  end function coverage_full_physical_complete

  pure logical function soil_thermal_energy_interval_ready(self) result(ready)
    class(soil_thermal_energy_interval_t), intent(in) :: self
    ready = self%available .and. ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0 .and. &
         ieee_is_finite(self%sensible_storage_change_j_m2) .and. &
         ieee_is_finite(self%top_conductive_energy_into_soil_j_m2) .and. &
         ieee_is_finite(self%bottom_conductive_energy_into_soil_j_m2) .and. &
         ieee_is_finite(self%restricted_sensible_residual_j_m2) .and. &
         self%coverage%restricted_sensible_conduction_complete()
  end function soil_thermal_energy_interval_ready

  pure logical function interval_restricted_complete(self) result(complete)
    class(soil_thermal_energy_interval_t), intent(in) :: self
    complete = self%ready() .and. self%coverage%restricted_sensible_conduction_complete()
  end function interval_restricted_complete

  pure logical function interval_full_physical_complete(self) result(complete)
    class(soil_thermal_energy_interval_t), intent(in) :: self
    complete = self%ready() .and. self%coverage%full_physical_energy_complete()
  end function interval_full_physical_complete

end module mod_soil_thermal_energy_contract
