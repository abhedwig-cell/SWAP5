module mod_b110_surface_evaporation_capacity_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       evaluate_b110_default_mvg_conductivity
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_INVALID_INPUT, SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  implicit none
  private

  real(real64), parameter, public :: B110_SURFACE_ATMOSPHERIC_HEAD_CM = -2.75e5_real64

  type, extends(surface_evaporation_capacity_provider_t), public :: b110_surface_evaporation_capacity_provider_t
    private
    type(soil_water_parameter_set_t), pointer :: geometry => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
    integer :: conductivity_mean_method = 0
    logical :: frost_active = .false.
    logical :: macropore_active = .false.
    logical :: bound = .false.
  contains
    procedure :: evaluate => b110_surface_evaporation_capacity_evaluate
  end type b110_surface_evaporation_capacity_provider_t

  public :: bind_b110_surface_evaporation_capacity_provider

contains

  subroutine bind_b110_surface_evaporation_capacity_provider(provider, geometry, hydraulics, &
       conductivity_mean_method, frost_active, macropore_active, ok)
    type(b110_surface_evaporation_capacity_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    integer, intent(in) :: conductivity_mean_method
    logical, intent(in) :: frost_active, macropore_active
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = geometry%active_nodes
    if (n <= 0 .or. hydraulics%active_nodes /= n) return
    if (.not. allocated(geometry%dz) .or. .not. allocated(geometry%node_distance)) return
    if (size(geometry%dz) /= n .or. size(geometry%node_distance) /= n) return
    if (.not. allocated(hydraulics%cofgen)) return
    if (size(hydraulics%cofgen,2) /= n) return

    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%conductivity_mean_method = conductivity_mean_method
    provider%frost_active = frost_active
    provider%macropore_active = macropore_active
    provider%bound = .true.
    ok = .true.
  end subroutine bind_b110_surface_evaporation_capacity_provider

  subroutine b110_surface_evaporation_capacity_evaluate(self, base_state, result)
    class(b110_surface_evaporation_capacity_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    real(real64) :: atmospheric_conductivity, top_conductivity, face_conductivity
    real(real64) :: top_head, top_dz, top_distance
    logical :: ok

    result = surface_evaporation_capacity_result_t()
    if (.not. self%bound .or. .not. associated(self%geometry) .or. .not. associated(self%hydraulics)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'provider-not-bound'
      return
    end if

    if (self%frost_active) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'frost-not-qualified'
      return
    end if
    if (self%macropore_active) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'macropore-not-qualified'
      return
    end if
    if (self%conductivity_mean_method == 7) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'mean-7-szym-not-qualified'
      return
    end if
    if (self%conductivity_mean_method < 1 .or. self%conductivity_mean_method > 6) then
      result%status = SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
      result%route = 'mean-policy-not-qualified'
      return
    end if

    if (base_state%active_nodes /= self%geometry%active_nodes) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'state-shape-mismatch'
      return
    end if
    if (.not. allocated(base_state%pressure_head)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'missing-pressure-head'
      return
    end if
    if (size(base_state%pressure_head) /= base_state%active_nodes) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'pressure-head-shape'
      return
    end if
    if (.not. ieee_is_finite(base_state%ponding_depth)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'nonfinite-ponding'
      return
    end if

    top_head = base_state%pressure_head(1)
    top_dz = self%geometry%dz(1)
    top_distance = self%geometry%node_distance(1)
    if (.not. ieee_is_finite(top_head) .or. .not. ieee_is_finite(top_dz) .or. &
        .not. ieee_is_finite(top_distance) .or. top_dz <= 0.0_real64 .or. top_distance <= 0.0_real64) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'invalid-top-hydraulic-state'
      return
    end if

    call evaluate_b110_default_mvg_conductivity(self%hydraulics, 1, B110_SURFACE_ATMOSPHERIC_HEAD_CM, &
         atmospheric_conductivity, ok)
    if (.not. ok) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'invalid-atmospheric-k'
      return
    end if
    call evaluate_b110_default_mvg_conductivity(self%hydraulics, 1, top_head, top_conductivity, ok)
    if (.not. ok) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'invalid-top-k'
      return
    end if

    call restricted_b110_surface_hcomean(self%conductivity_mean_method, atmospheric_conductivity, &
         top_conductivity, top_dz, top_dz, face_conductivity, ok)
    if (.not. ok) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'invalid-face-k'
      return
    end if

    result%evaporation_capacity = -face_conductivity * &
         ((B110_SURFACE_ATMOSPHERIC_HEAD_CM-top_head)/top_distance + 1.0_real64)
    if (.not. ieee_is_finite(result%evaporation_capacity)) then
      result%evaporation_capacity = 0.0_real64
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'nonfinite-capacity'
      return
    end if
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    write(result%route,'(A,I0)') 'b110-restricted-mean-', self%conductivity_mean_method
  end subroutine b110_surface_evaporation_capacity_evaluate

  subroutine restricted_b110_surface_hcomean(method, kup, klow, dzup, dzlow, kmean, ok)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64), intent(out) :: kmean
    logical, intent(out) :: ok
    real(real64) :: a1, a2, denom

    kmean = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(kup) .or. .not. ieee_is_finite(klow) .or. &
        .not. ieee_is_finite(dzup) .or. .not. ieee_is_finite(dzlow)) return
    if (kup < 0.0_real64 .or. klow < 0.0_real64 .or. dzup <= 0.0_real64 .or. dzlow <= 0.0_real64) return
    denom = dzup + dzlow
    if (.not. ieee_is_finite(denom) .or. denom <= 0.0_real64) return
    a1 = dzup/denom
    a2 = 1.0_real64-a1

    select case (method)
    case (1)
      kmean = 0.5_real64*(kup+klow)
    case (2)
      kmean = (dzup*kup+dzlow*klow)/denom
    case (3)
      kmean = sqrt(kup*klow)
    case (4)
      kmean = kup**a1 * klow**a2
    case (5)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case (6)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(a1/kup+a2/klow)
    case default
      return
    end select
    if (.not. ieee_is_finite(kmean) .or. kmean < 0.0_real64) then
      kmean = 0.0_real64
      return
    end if
    ok = .true.
  end subroutine restricted_b110_surface_hcomean

end module mod_b110_surface_evaporation_capacity_provider
