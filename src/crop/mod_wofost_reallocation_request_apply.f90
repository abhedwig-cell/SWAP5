module mod_wofost_reallocation_request_apply
  use iso_fortran_env, only: real64, int64
  use mod_wofost73_reallocation, only: &
    wofost73_reallocation_parameters_t, &
    wofost73_reallocation_state_t, &
    wofost73_reallocation_biomass_t, &
    wofost73_reallocation_flux_t
  implicit none
  private

  integer, parameter, public :: WOFRAP_OK = 0
  integer, parameter, public :: WOFRAP_INVALID_INTERVAL = 1
  integer, parameter, public :: WOFRAP_UNADMITTED_DURATION = 2
  integer, parameter, public :: WOFRAP_INVALID_PARAMETERS = 3
  integer, parameter, public :: WOFRAP_INVALID_ACTIVATION_BIOMASS = 4
  integer, parameter, public :: WOFRAP_INVALID_STATE = 5
  integer, parameter, public :: WOFRAP_INVALID_REQUEST = 6
  integer, parameter, public :: WOFRAP_INVALID_AVAILABILITY = 7

  type, public :: wofost_reallocation_request_t
    real(real64) :: leaf = 0.0_real64
    real(real64) :: stem = 0.0_real64
  end type wofost_reallocation_request_t

  type, public :: wofost_reallocation_request_diagnostics_t
    integer :: status = WOFRAP_OK
    logical :: activated_this_trial = .false.
  end type wofost_reallocation_request_diagnostics_t

  type, public :: wofost_reallocation_apply_diagnostics_t
    integer :: status = WOFRAP_OK
    logical :: leaf_availability_limited = .false.
    logical :: stem_availability_limited = .false.
    real(real64) :: dry_matter_residual = 0.0_real64
  end type wofost_reallocation_apply_diagnostics_t

  type, public :: wofost_reallocation_trial_diagnostics_t
    integer :: status = WOFRAP_OK
    integer :: request_status = WOFRAP_OK
    integer :: apply_status = WOFRAP_OK
    logical :: activated_this_trial = .false.
    logical :: leaf_availability_limited = .false.
    logical :: stem_availability_limited = .false.
    real(real64) :: dry_matter_residual = 0.0_real64
  end type wofost_reallocation_trial_diagnostics_t

  public :: evaluate_wofost_reallocation_request
  public :: apply_wofost_reallocation_request
  public :: evaluate_wofost_reallocation_trial

contains

  pure subroutine evaluate_wofost_reallocation_request(parameters, committed_state, activation_biomass, &
                                                        dvs, t0, t1, requested_state, request, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost73_reallocation_state_t), intent(in) :: committed_state
    type(wofost73_reallocation_biomass_t), intent(in) :: activation_biomass
    real(real64), intent(in) :: dvs, t0, t1
    type(wofost73_reallocation_state_t), intent(out) :: requested_state
    type(wofost_reallocation_request_t), intent(out) :: request
    type(wofost_reallocation_request_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: duration, leaf_remaining, stem_remaining

    requested_state = committed_state
    request = wofost_reallocation_request_t()
    diagnostics = wofost_reallocation_request_diagnostics_t()

    if (t1 <= t0) then
      diagnostics%status = WOFRAP_INVALID_INTERVAL
      return
    end if

    duration = t1 - t0
    if (transfer(duration, 0_int64) /= transfer(1.0_real64, 0_int64)) then
      diagnostics%status = WOFRAP_UNADMITTED_DURATION
      return
    end if

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = WOFRAP_INVALID_PARAMETERS
      return
    end if

    if (.not. valid_biomass(activation_biomass)) then
      diagnostics%status = WOFRAP_INVALID_ACTIVATION_BIOMASS
      return
    end if

    if (.not. valid_state(committed_state)) then
      diagnostics%status = WOFRAP_INVALID_STATE
      return
    end if

    if (dvs < parameters%activation_dvs) return

    if (.not. requested_state%activated) then
      requested_state%activated = .true.
      requested_state%leaf_cap = activation_biomass%leaf * parameters%leaf_fraction
      requested_state%stem_cap = activation_biomass%stem * parameters%stem_fraction
      diagnostics%activated_this_trial = .true.
    end if

    leaf_remaining = max(0.0_real64, requested_state%leaf_cap - requested_state%leaf_reallocated)
    stem_remaining = max(0.0_real64, requested_state%stem_cap - requested_state%stem_reallocated)

    request%leaf = min(requested_state%leaf_cap * parameters%leaf_rate, leaf_remaining) * duration
    request%stem = min(requested_state%stem_cap * parameters%stem_rate, stem_remaining) * duration
  end subroutine evaluate_wofost_reallocation_request

  pure subroutine apply_wofost_reallocation_request(parameters, requested_state, request, availability, &
                                                     candidate_state, applied_fluxes, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost73_reallocation_state_t), intent(in) :: requested_state
    type(wofost_reallocation_request_t), intent(in) :: request
    type(wofost73_reallocation_biomass_t), intent(in) :: availability
    type(wofost73_reallocation_state_t), intent(out) :: candidate_state
    type(wofost73_reallocation_flux_t), intent(out) :: applied_fluxes
    type(wofost_reallocation_apply_diagnostics_t), intent(out) :: diagnostics
    real(real64), parameter :: eps = 1.0e-12_real64
    real(real64) :: leaf_remaining, stem_remaining

    candidate_state = requested_state
    applied_fluxes = wofost73_reallocation_flux_t()
    diagnostics = wofost_reallocation_apply_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = WOFRAP_INVALID_PARAMETERS
      return
    end if

    if (.not. valid_state(requested_state)) then
      diagnostics%status = WOFRAP_INVALID_STATE
      return
    end if

    if (.not. valid_request(request)) then
      diagnostics%status = WOFRAP_INVALID_REQUEST
      return
    end if

    if (.not. valid_biomass(availability)) then
      diagnostics%status = WOFRAP_INVALID_AVAILABILITY
      return
    end if

    leaf_remaining = max(0.0_real64, requested_state%leaf_cap - requested_state%leaf_reallocated)
    stem_remaining = max(0.0_real64, requested_state%stem_cap - requested_state%stem_reallocated)

    if (request%leaf > leaf_remaining + eps .or. request%stem > stem_remaining + eps) then
      diagnostics%status = WOFRAP_INVALID_REQUEST
      return
    end if

    applied_fluxes%leaf_out = min(request%leaf, availability%leaf)
    applied_fluxes%stem_out = min(request%stem, availability%stem)
    applied_fluxes%storage_in = (applied_fluxes%leaf_out + applied_fluxes%stem_out) * &
                                parameters%efficiency
    applied_fluxes%conversion_loss = applied_fluxes%leaf_out + applied_fluxes%stem_out - &
                                     applied_fluxes%storage_in

    candidate_state%leaf_reallocated = requested_state%leaf_reallocated + applied_fluxes%leaf_out
    candidate_state%stem_reallocated = requested_state%stem_reallocated + applied_fluxes%stem_out

    if (candidate_state%leaf_reallocated > candidate_state%leaf_cap .and. &
        candidate_state%leaf_reallocated <= candidate_state%leaf_cap + eps) then
      candidate_state%leaf_reallocated = candidate_state%leaf_cap
    end if
    if (candidate_state%stem_reallocated > candidate_state%stem_cap .and. &
        candidate_state%stem_reallocated <= candidate_state%stem_cap + eps) then
      candidate_state%stem_reallocated = candidate_state%stem_cap
    end if

    if (.not. valid_state(candidate_state)) then
      candidate_state = requested_state
      applied_fluxes = wofost73_reallocation_flux_t()
      diagnostics%status = WOFRAP_INVALID_STATE
      return
    end if

    diagnostics%leaf_availability_limited = request%leaf > applied_fluxes%leaf_out + eps
    diagnostics%stem_availability_limited = request%stem > applied_fluxes%stem_out + eps
    diagnostics%dry_matter_residual = applied_fluxes%leaf_out + applied_fluxes%stem_out - &
                                      applied_fluxes%storage_in - applied_fluxes%conversion_loss
  end subroutine apply_wofost_reallocation_request

  pure subroutine evaluate_wofost_reallocation_trial(parameters, committed_state, activation_biomass, &
                                                      availability, dvs, t0, t1, candidate_state, &
                                                      request, applied_fluxes, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost73_reallocation_state_t), intent(in) :: committed_state
    type(wofost73_reallocation_biomass_t), intent(in) :: activation_biomass
    type(wofost73_reallocation_biomass_t), intent(in) :: availability
    real(real64), intent(in) :: dvs, t0, t1
    type(wofost73_reallocation_state_t), intent(out) :: candidate_state
    type(wofost_reallocation_request_t), intent(out) :: request
    type(wofost73_reallocation_flux_t), intent(out) :: applied_fluxes
    type(wofost_reallocation_trial_diagnostics_t), intent(out) :: diagnostics
    type(wofost73_reallocation_state_t) :: requested_state, applied_state
    type(wofost_reallocation_request_diagnostics_t) :: request_diagnostics
    type(wofost_reallocation_apply_diagnostics_t) :: apply_diagnostics

    candidate_state = committed_state
    request = wofost_reallocation_request_t()
    applied_fluxes = wofost73_reallocation_flux_t()
    diagnostics = wofost_reallocation_trial_diagnostics_t()

    call evaluate_wofost_reallocation_request(parameters, committed_state, activation_biomass, &
                                               dvs, t0, t1, requested_state, request, request_diagnostics)
    diagnostics%request_status = request_diagnostics%status
    diagnostics%activated_this_trial = request_diagnostics%activated_this_trial
    if (request_diagnostics%status /= WOFRAP_OK) then
      diagnostics%status = request_diagnostics%status
      return
    end if

    call apply_wofost_reallocation_request(parameters, requested_state, request, availability, &
                                            applied_state, applied_fluxes, apply_diagnostics)
    diagnostics%apply_status = apply_diagnostics%status
    diagnostics%leaf_availability_limited = apply_diagnostics%leaf_availability_limited
    diagnostics%stem_availability_limited = apply_diagnostics%stem_availability_limited
    diagnostics%dry_matter_residual = apply_diagnostics%dry_matter_residual
    if (apply_diagnostics%status /= WOFRAP_OK) then
      diagnostics%status = apply_diagnostics%status
      request = wofost_reallocation_request_t()
      applied_fluxes = wofost73_reallocation_flux_t()
      return
    end if

    candidate_state = applied_state
  end subroutine evaluate_wofost_reallocation_trial

  pure logical function valid_parameters(parameters) result(valid)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters

    valid = parameters%leaf_fraction >= 0.0_real64 .and. parameters%leaf_fraction <= 1.0_real64 .and. &
            parameters%stem_fraction >= 0.0_real64 .and. parameters%stem_fraction <= 1.0_real64 .and. &
            parameters%leaf_rate >= 0.0_real64 .and. parameters%stem_rate >= 0.0_real64 .and. &
            parameters%efficiency >= 0.0_real64 .and. parameters%efficiency <= 1.0_real64
  end function valid_parameters

  pure logical function valid_biomass(biomass) result(valid)
    type(wofost73_reallocation_biomass_t), intent(in) :: biomass

    valid = biomass%leaf >= 0.0_real64 .and. biomass%stem >= 0.0_real64
  end function valid_biomass

  pure logical function valid_request(request) result(valid)
    type(wofost_reallocation_request_t), intent(in) :: request

    valid = request%leaf >= 0.0_real64 .and. request%stem >= 0.0_real64
  end function valid_request

  pure logical function valid_state(state) result(valid)
    type(wofost73_reallocation_state_t), intent(in) :: state
    real(real64), parameter :: eps = 1.0e-12_real64

    valid = state%leaf_cap >= 0.0_real64 .and. state%stem_cap >= 0.0_real64 .and. &
            state%leaf_reallocated >= 0.0_real64 .and. state%stem_reallocated >= 0.0_real64
    if (.not. valid) return

    if (.not. state%activated) then
      valid = abs(state%leaf_cap) <= eps .and. abs(state%stem_cap) <= eps .and. &
              abs(state%leaf_reallocated) <= eps .and. abs(state%stem_reallocated) <= eps
    else
      valid = state%leaf_reallocated <= state%leaf_cap + eps .and. &
              state%stem_reallocated <= state%stem_cap + eps
    end if
  end function valid_state

end module mod_wofost_reallocation_request_apply
