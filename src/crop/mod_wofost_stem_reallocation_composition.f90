module mod_wofost_stem_reallocation_composition
  use iso_fortran_env, only: real64
  use mod_wofost73_reallocation, only: &
    REALLOC_OK, &
    wofost73_reallocation_parameters_t, &
    wofost73_reallocation_state_t, &
    wofost73_reallocation_biomass_t, &
    wofost73_reallocation_flux_t, &
    wofost73_reallocation_diagnostics_t, &
    evaluate_wofost73_reallocation_reference_call
  implicit none
  private

  integer, parameter, public :: WOFOST_COMPOSE_OK = 0
  integer, parameter, public :: WOFOST_COMPOSE_LEAF_REALLOCATION_UNADMITTED = 1
  integer, parameter, public :: WOFOST_COMPOSE_INVALID_BIOMASS = 2
  integer, parameter, public :: WOFOST_COMPOSE_CHILD_ERROR = 3
  integer, parameter, public :: WOFOST_COMPOSE_NEGATIVE_ENDPOINT = 4
  integer, parameter, public :: WOFOST_COMPOSE_UNEXPECTED_LEAF_FLUX = 5

  type, public :: wofost_reallocation_track_state_t
    real(real64) :: leaf = 0.0_real64
    real(real64) :: stem = 0.0_real64
    real(real64) :: storage = 0.0_real64
    type(wofost73_reallocation_state_t) :: reallocation
  end type wofost_reallocation_track_state_t

  type, public :: wofost_reallocation_pair_state_t
    type(wofost_reallocation_track_state_t) :: potential
    type(wofost_reallocation_track_state_t) :: actual
  end type wofost_reallocation_pair_state_t

  type, public :: wofost_reallocation_track_flux_t
    type(wofost73_reallocation_flux_t) :: reallocation
  end type wofost_reallocation_track_flux_t

  type, public :: wofost_reallocation_pair_flux_t
    type(wofost_reallocation_track_flux_t) :: potential
    type(wofost_reallocation_track_flux_t) :: actual
  end type wofost_reallocation_pair_flux_t

  type, public :: wofost_reallocation_track_diagnostics_t
    integer :: status = WOFOST_COMPOSE_OK
    integer :: child_status = REALLOC_OK
    real(real64) :: dry_matter_residual = 0.0_real64
  end type wofost_reallocation_track_diagnostics_t

  type, public :: wofost_reallocation_pair_diagnostics_t
    integer :: status = WOFOST_COMPOSE_OK
    type(wofost_reallocation_track_diagnostics_t) :: potential
    type(wofost_reallocation_track_diagnostics_t) :: actual
  end type wofost_reallocation_pair_diagnostics_t

  public :: evaluate_wofost_stem_reallocation_pair

contains

  pure subroutine evaluate_wofost_stem_reallocation_pair(parameters, committed_state, dvs, t0, t1, &
                                                          candidate_state, fluxes, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost_reallocation_pair_state_t), intent(in) :: committed_state
    real(real64), intent(in) :: dvs, t0, t1
    type(wofost_reallocation_pair_state_t), intent(out) :: candidate_state
    type(wofost_reallocation_pair_flux_t), intent(out) :: fluxes
    type(wofost_reallocation_pair_diagnostics_t), intent(out) :: diagnostics
    type(wofost_reallocation_track_state_t) :: potential_candidate, actual_candidate
    type(wofost_reallocation_track_flux_t) :: potential_flux, actual_flux
    type(wofost_reallocation_track_diagnostics_t) :: potential_diagnostics, actual_diagnostics

    candidate_state = committed_state
    fluxes = wofost_reallocation_pair_flux_t()
    diagnostics = wofost_reallocation_pair_diagnostics_t()

    if (parameters%leaf_fraction > 0.0_real64 .or. parameters%leaf_rate > 0.0_real64) then
      diagnostics%status = WOFOST_COMPOSE_LEAF_REALLOCATION_UNADMITTED
      return
    end if

    if (.not. valid_pair_biomass(committed_state)) then
      diagnostics%status = WOFOST_COMPOSE_INVALID_BIOMASS
      return
    end if

    call evaluate_track(parameters, committed_state%potential, dvs, t0, t1, &
                        potential_candidate, potential_flux, potential_diagnostics)
    diagnostics%potential = potential_diagnostics
    if (potential_diagnostics%status /= WOFOST_COMPOSE_OK) then
      diagnostics%status = potential_diagnostics%status
      return
    end if

    call evaluate_track(parameters, committed_state%actual, dvs, t0, t1, &
                        actual_candidate, actual_flux, actual_diagnostics)
    diagnostics%actual = actual_diagnostics
    if (actual_diagnostics%status /= WOFOST_COMPOSE_OK) then
      diagnostics%status = actual_diagnostics%status
      return
    end if

    candidate_state%potential = potential_candidate
    candidate_state%actual = actual_candidate
    fluxes%potential = potential_flux
    fluxes%actual = actual_flux
  end subroutine evaluate_wofost_stem_reallocation_pair

  pure subroutine evaluate_track(parameters, committed_state, dvs, t0, t1, &
                                 candidate_state, fluxes, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost_reallocation_track_state_t), intent(in) :: committed_state
    real(real64), intent(in) :: dvs, t0, t1
    type(wofost_reallocation_track_state_t), intent(out) :: candidate_state
    type(wofost_reallocation_track_flux_t), intent(out) :: fluxes
    type(wofost_reallocation_track_diagnostics_t), intent(out) :: diagnostics
    type(wofost73_reallocation_biomass_t) :: biomass
    type(wofost73_reallocation_state_t) :: reallocation_candidate
    type(wofost73_reallocation_flux_t) :: reallocation_flux
    type(wofost73_reallocation_diagnostics_t) :: reallocation_diagnostics
    real(real64), parameter :: endpoint_eps = 1.0e-12_real64

    candidate_state = committed_state
    fluxes = wofost_reallocation_track_flux_t()
    diagnostics = wofost_reallocation_track_diagnostics_t()

    biomass%leaf = committed_state%leaf
    biomass%stem = committed_state%stem

    call evaluate_wofost73_reallocation_reference_call(parameters, committed_state%reallocation, biomass, &
                                                        dvs, t0, t1, reallocation_candidate, &
                                                        reallocation_flux, reallocation_diagnostics)
    diagnostics%child_status = reallocation_diagnostics%status
    if (reallocation_diagnostics%status /= REALLOC_OK) then
      diagnostics%status = WOFOST_COMPOSE_CHILD_ERROR
      return
    end if

    if (abs(reallocation_flux%leaf_out) > endpoint_eps) then
      diagnostics%status = WOFOST_COMPOSE_UNEXPECTED_LEAF_FLUX
      return
    end if

    if (reallocation_flux%stem_out > committed_state%stem + endpoint_eps) then
      diagnostics%status = WOFOST_COMPOSE_NEGATIVE_ENDPOINT
      return
    end if

    candidate_state%stem = committed_state%stem - reallocation_flux%stem_out
    if (candidate_state%stem < 0.0_real64) then
      if (candidate_state%stem >= -endpoint_eps) then
        candidate_state%stem = 0.0_real64
      else
        candidate_state = committed_state
        diagnostics%status = WOFOST_COMPOSE_NEGATIVE_ENDPOINT
        return
      end if
    end if

    candidate_state%storage = committed_state%storage + reallocation_flux%storage_in
    candidate_state%reallocation = reallocation_candidate
    fluxes%reallocation = reallocation_flux

    diagnostics%dry_matter_residual = &
      (candidate_state%stem - committed_state%stem) + &
      (candidate_state%storage - committed_state%storage) + &
      reallocation_flux%conversion_loss
  end subroutine evaluate_track

  pure logical function valid_pair_biomass(state) result(valid)
    type(wofost_reallocation_pair_state_t), intent(in) :: state

    valid = valid_track_biomass(state%potential) .and. valid_track_biomass(state%actual)
  end function valid_pair_biomass

  pure logical function valid_track_biomass(state) result(valid)
    type(wofost_reallocation_track_state_t), intent(in) :: state

    valid = state%leaf >= 0.0_real64 .and. state%stem >= 0.0_real64 .and. &
            state%storage >= 0.0_real64
  end function valid_track_biomass

end module mod_wofost_stem_reallocation_composition
