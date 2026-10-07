module mod_crop_root_depth_rate_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t
  use mod_crop_root_profile_static, only: materialize_static_root_profile, CROP_ROOT_PROFILE_OK
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, CROP_ROOT_INPUT_OK
  use mod_crop_root_anaerobic_extension_gate, only: root_extension_allowed_by_daily_oxygen, ROOT_ANOX_GATE_OK
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_RATE_OK = 0
  integer, parameter, public :: CROP_ROOT_RATE_INVALID_PARAMETERS = 1
  integer, parameter, public :: CROP_ROOT_RATE_INVALID_STATE = 2
  integer, parameter, public :: CROP_ROOT_RATE_INVALID_FORCING = 3
  integer, parameter, public :: CROP_ROOT_RATE_PROFILE_ERROR = 4

  integer, parameter, public :: CROP_ROOT_RATE_UNSCALED = 0
  integer, parameter, public :: CROP_ROOT_RATE_WATER_SCALED = 1

  type, public :: crop_root_depth_rate_parameters_t
    real(real64) :: initial_root_depth_cm = 0.0_real64
    real(real64) :: maximum_root_depth_cm = 0.0_real64
    real(real64) :: maximum_daily_extension_cm = 0.0_real64
    integer :: actual_extension_mode = CROP_ROOT_RATE_UNSCALED
    logical :: require_root_growth = .true.
    real(real64) :: negligible_transpiration = 0.0_real64
    real(real64) :: negligible_root_growth = 0.0_real64
    real(real64) :: negligible_extension = 0.0_real64
    logical :: anaerobic_extension_gate_enabled = .false.
    real(real64) :: aeration_critical_factor = 0.0001_real64
  contains
    procedure, public :: ready => crop_root_depth_rate_parameters_ready
  end type crop_root_depth_rate_parameters_t

  type, extends(transaction_state_t), public :: crop_root_depth_rate_state_t
    real(real64) :: actual_root_depth_cm = 0.0_real64
    real(real64) :: potential_root_depth_cm = 0.0_real64
  contains
    procedure :: clone => crop_root_depth_rate_clone
    procedure, public :: validate => crop_root_depth_rate_validate
    procedure, public :: derive_root_uptake_input => crop_root_depth_rate_derive_input
  end type crop_root_depth_rate_state_t

  type, public :: crop_root_depth_rate_daily_forcing_t
    real(real64) :: potential_transpiration = 0.0_real64
    real(real64) :: actual_root_uptake = 0.0_real64
    real(real64) :: actual_root_growth = 0.0_real64
    real(real64) :: potential_root_growth = 0.0_real64
    logical :: deepest_root_oxygen_factor_available = .false.
    real(real64) :: deepest_root_oxygen_factor_integral = 0.0_real64
  end type crop_root_depth_rate_daily_forcing_t

  type, public :: crop_root_depth_rate_diagnostics_t
    logical :: potential_extension_allowed = .false.
    logical :: actual_extension_allowed = .false.
    real(real64) :: potential_extension_cm = 0.0_real64
    real(real64) :: actual_extension_before_scaling_cm = 0.0_real64
    real(real64) :: actual_extension_cm = 0.0_real64
    real(real64) :: water_scaling_factor = 1.0_real64
    logical :: candidate_built = .false.
  end type crop_root_depth_rate_diagnostics_t

  public :: initialize_crop_root_depth_rate_state
  public :: evaluate_crop_root_depth_rate_candidate

contains

  logical function crop_root_depth_rate_parameters_ready(self) result(ready)
    class(crop_root_depth_rate_parameters_t), intent(in) :: self
    ready = .false.
    if (.not. ieee_is_finite(self%initial_root_depth_cm) .or. self%initial_root_depth_cm < 0.0_real64) return
    if (.not. ieee_is_finite(self%maximum_root_depth_cm) .or. self%maximum_root_depth_cm <= 0.0_real64) return
    if (self%initial_root_depth_cm > self%maximum_root_depth_cm) return
    if (.not. ieee_is_finite(self%maximum_daily_extension_cm) .or. self%maximum_daily_extension_cm < 0.0_real64) return
    if (self%actual_extension_mode /= CROP_ROOT_RATE_UNSCALED .and. &
        self%actual_extension_mode /= CROP_ROOT_RATE_WATER_SCALED) return
    if (.not. ieee_is_finite(self%negligible_transpiration) .or. self%negligible_transpiration < 0.0_real64) return
    if (.not. ieee_is_finite(self%negligible_root_growth) .or. self%negligible_root_growth < 0.0_real64) return
    if (.not. ieee_is_finite(self%negligible_extension) .or. self%negligible_extension < 0.0_real64) return
    if (.not. ieee_is_finite(self%aeration_critical_factor) .or. self%aeration_critical_factor < 0.0_real64 .or. &
         self%aeration_critical_factor > 1.0_real64) return
    ready = .true.
  end function crop_root_depth_rate_parameters_ready

  integer function crop_root_depth_rate_validate(self) result(status)
    class(crop_root_depth_rate_state_t), intent(in) :: self
    status = CROP_ROOT_RATE_INVALID_STATE
    if (.not. ieee_is_finite(self%actual_root_depth_cm) .or. self%actual_root_depth_cm < 0.0_real64) return
    if (.not. ieee_is_finite(self%potential_root_depth_cm) .or. self%potential_root_depth_cm < 0.0_real64) return
    if (self%actual_root_depth_cm > self%potential_root_depth_cm) return
    status = CROP_ROOT_RATE_OK
  end function crop_root_depth_rate_validate

  subroutine crop_root_depth_rate_clone(self, copy)
    class(crop_root_depth_rate_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(crop_root_depth_rate_state_t :: copy)
    select type (typed => copy)
    type is (crop_root_depth_rate_state_t)
      typed%actual_root_depth_cm = self%actual_root_depth_cm
      typed%potential_root_depth_cm = self%potential_root_depth_cm
    class default
      error stop 'crop root depth rate clone failure'
    end select
  end subroutine crop_root_depth_rate_clone

  subroutine initialize_crop_root_depth_rate_state(parameters, state, status)
    type(crop_root_depth_rate_parameters_t), intent(in) :: parameters
    type(crop_root_depth_rate_state_t), intent(out) :: state
    integer, intent(out) :: status

    state = crop_root_depth_rate_state_t()
    status = CROP_ROOT_RATE_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    state%actual_root_depth_cm = min(parameters%initial_root_depth_cm, parameters%maximum_root_depth_cm)
    state%potential_root_depth_cm = state%actual_root_depth_cm
    status = state%validate()
  end subroutine initialize_crop_root_depth_rate_state

  subroutine evaluate_crop_root_depth_rate_candidate(parameters, committed, forcing, candidate, diagnostics, status)
    type(crop_root_depth_rate_parameters_t), intent(in) :: parameters
    type(crop_root_depth_rate_state_t), intent(in) :: committed
    type(crop_root_depth_rate_daily_forcing_t), intent(in) :: forcing
    type(crop_root_depth_rate_state_t), intent(out) :: candidate
    type(crop_root_depth_rate_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    real(real64) :: rrpot, rr, ratio
    logical :: oxygen_allows_actual_extension
    integer :: oxygen_status

    candidate = committed
    diagnostics = crop_root_depth_rate_diagnostics_t()
    status = CROP_ROOT_RATE_INVALID_PARAMETERS
    if (.not. parameters%ready()) return

    status = committed%validate()
    if (status /= CROP_ROOT_RATE_OK) return
    if (committed%potential_root_depth_cm > parameters%maximum_root_depth_cm .or. &
        committed%actual_root_depth_cm > parameters%maximum_root_depth_cm) then
      status = CROP_ROOT_RATE_INVALID_STATE
      return
    end if

    status = CROP_ROOT_RATE_INVALID_FORCING
    if (.not. forcing_valid(forcing)) return
    if (forcing%actual_root_uptake > forcing%potential_transpiration + &
        256.0_real64*epsilon(1.0_real64)*max(1.0_real64, forcing%potential_transpiration)) return

    diagnostics%potential_extension_allowed = forcing%potential_transpiration >= parameters%negligible_transpiration
    diagnostics%actual_extension_allowed = diagnostics%potential_extension_allowed
    if (parameters%anaerobic_extension_gate_enabled) then
      if (.not. forcing%deepest_root_oxygen_factor_available) then
        status = CROP_ROOT_RATE_INVALID_FORCING
        return
      end if
      call root_extension_allowed_by_daily_oxygen(.true., forcing%deepest_root_oxygen_factor_integral, &
           parameters%aeration_critical_factor, oxygen_allows_actual_extension, oxygen_status)
      if (oxygen_status /= ROOT_ANOX_GATE_OK) then
        status = CROP_ROOT_RATE_INVALID_FORCING
        return
      end if
      diagnostics%actual_extension_allowed = diagnostics%actual_extension_allowed .and. oxygen_allows_actual_extension
    end if
    if (parameters%require_root_growth) then
      diagnostics%potential_extension_allowed = diagnostics%potential_extension_allowed .and. &
           forcing%potential_root_growth >= parameters%negligible_root_growth
      diagnostics%actual_extension_allowed = diagnostics%actual_extension_allowed .and. &
           forcing%actual_root_growth >= parameters%negligible_root_growth
    end if

    rrpot = min(parameters%maximum_root_depth_cm - committed%potential_root_depth_cm, &
                parameters%maximum_daily_extension_cm)
    if (rrpot > 0.0_real64 .and. diagnostics%potential_extension_allowed) then
      candidate%potential_root_depth_cm = committed%potential_root_depth_cm + rrpot
      diagnostics%potential_extension_cm = rrpot
    end if

    rr = min(parameters%maximum_root_depth_cm - committed%actual_root_depth_cm, &
             parameters%maximum_daily_extension_cm)
    diagnostics%actual_extension_before_scaling_cm = max(0.0_real64, rr)
    if (rr > 0.0_real64 .and. diagnostics%actual_extension_allowed) then
      if (parameters%actual_extension_mode == CROP_ROOT_RATE_WATER_SCALED) then
        ! B1.11 SWDMI2RD=1: RR = RR * IQROT_DAY / IPTRA_DAY.
        ratio = forcing%actual_root_uptake / forcing%potential_transpiration
        diagnostics%water_scaling_factor = ratio
        rr = rr * ratio
      end if
      if (rr < parameters%negligible_extension) rr = 0.0_real64
      candidate%actual_root_depth_cm = committed%actual_root_depth_cm + rr
      diagnostics%actual_extension_cm = rr
    end if

    status = candidate%validate()
    if (status /= CROP_ROOT_RATE_OK) return
    if (candidate%potential_root_depth_cm > parameters%maximum_root_depth_cm .or. &
        candidate%actual_root_depth_cm > parameters%maximum_root_depth_cm) then
      status = CROP_ROOT_RATE_INVALID_STATE
      return
    end if
    diagnostics%candidate_built = .true.
  end subroutine evaluate_crop_root_depth_rate_candidate

  subroutine crop_root_depth_rate_derive_input(self, density_table, maximum_root_depth_cm, zbotcp_cm, input, available, status)
    class(crop_root_depth_rate_state_t), intent(in) :: self
    type(wofost_rate_table_t), intent(in) :: density_table
    real(real64), intent(in) :: maximum_root_depth_cm, zbotcp_cm(:)
    type(crop_root_uptake_input_t), intent(out) :: input
    logical, intent(out) :: available
    integer, intent(out) :: status

    real(real64), allocatable :: cumulative(:)
    integer :: rooted_nodes, profile_status, contract_status

    input = crop_root_uptake_input_t()
    available = .false.
    status = self%validate()
    if (status /= CROP_ROOT_RATE_OK) return

    call materialize_static_root_profile(density_table, zbotcp_cm, maximum_root_depth_cm, self%actual_root_depth_cm, &
         rooted_nodes, cumulative, profile_status)
    if (profile_status /= CROP_ROOT_PROFILE_OK) then
      status = CROP_ROOT_RATE_PROFILE_ERROR
      return
    end if
    input%crop_emerged = .true.
    input%potential_transpiration = 0.0_real64
    input%rooted_nodes = rooted_nodes
    if (allocated(cumulative)) input%cumulative_root_fraction = cumulative
    call validate_crop_root_uptake_input(input, size(zbotcp_cm), contract_status)
    if (contract_status /= CROP_ROOT_INPUT_OK) then
      input = crop_root_uptake_input_t()
      status = CROP_ROOT_RATE_PROFILE_ERROR
      return
    end if
    available = .true.
  end subroutine crop_root_depth_rate_derive_input

  logical function forcing_valid(forcing) result(valid)
    type(crop_root_depth_rate_daily_forcing_t), intent(in) :: forcing
    real(real64) :: values(5)
    values = [forcing%potential_transpiration, forcing%actual_root_uptake, &
              forcing%actual_root_growth, forcing%potential_root_growth, &
              forcing%deepest_root_oxygen_factor_integral]
    valid = all(ieee_is_finite(values)) .and. all(values >= 0.0_real64)
    if (.not. valid) return
    if (forcing%deepest_root_oxygen_factor_available) then
      valid = forcing%deepest_root_oxygen_factor_integral <= 1.0_real64 + 64.0_real64*epsilon(1.0_real64)
    else
      valid = abs(forcing%deepest_root_oxygen_factor_integral) <= tiny(1.0_real64)
    end if
  end function forcing_valid

end module mod_crop_root_depth_rate_owner
