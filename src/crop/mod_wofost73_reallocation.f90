module mod_wofost73_reallocation
  use iso_fortran_env, only: real64, int64
  implicit none
  private

  integer, parameter, public :: REALLOC_OK = 0
  integer, parameter, public :: REALLOC_INVALID_INTERVAL = 1
  integer, parameter, public :: REALLOC_UNADMITTED_DURATION = 2
  integer, parameter, public :: REALLOC_INVALID_PARAMETERS = 3
  integer, parameter, public :: REALLOC_INVALID_BIOMASS = 4
  integer, parameter, public :: REALLOC_INVALID_STATE = 5

  type, public :: wofost73_reallocation_parameters_t
    real(real64) :: activation_dvs = 3.0_real64
    real(real64) :: stem_fraction = 0.0_real64
    real(real64) :: leaf_fraction = 0.0_real64
    real(real64) :: stem_rate = 0.0_real64
    real(real64) :: leaf_rate = 0.0_real64
    real(real64) :: efficiency = 1.0_real64
  end type wofost73_reallocation_parameters_t

  ! This state is only required for crop templates where reallocation can
  ! actually transfer biomass. Runtime/template composition should not allocate
  ! it for disabled profiles.
  type, public :: wofost73_reallocation_state_t
    logical :: activated = .false.
    real(real64) :: leaf_cap = 0.0_real64
    real(real64) :: stem_cap = 0.0_real64
    real(real64) :: leaf_reallocated = 0.0_real64
    real(real64) :: stem_reallocated = 0.0_real64
  end type wofost73_reallocation_state_t

  type, public :: wofost73_reallocation_biomass_t
    real(real64) :: leaf = 0.0_real64
    real(real64) :: stem = 0.0_real64
  end type wofost73_reallocation_biomass_t

  ! Amounts transferred over the admitted interval. For the current one-day
  ! admission these are numerically equal to the WOFOST daily rates.
  type, public :: wofost73_reallocation_flux_t
    real(real64) :: leaf_out = 0.0_real64
    real(real64) :: stem_out = 0.0_real64
    real(real64) :: storage_in = 0.0_real64
    real(real64) :: conversion_loss = 0.0_real64
  end type wofost73_reallocation_flux_t

  type, public :: wofost73_reallocation_diagnostics_t
    integer :: status = REALLOC_OK
    logical :: activated_this_trial = .false.
    real(real64) :: dry_matter_residual = 0.0_real64
  end type wofost73_reallocation_diagnostics_t

  public :: reallocation_enabled
  public :: evaluate_wofost73_reallocation_reference_call

contains

  pure logical function reallocation_enabled(parameters, crop_end_dvs) result(enabled)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    real(real64), intent(in), optional :: crop_end_dvs
    real(real64) :: end_dvs

    end_dvs = 2.0_real64
    if (present(crop_end_dvs)) end_dvs = crop_end_dvs

    enabled = parameters%activation_dvs <= end_dvs .and. &
      ((parameters%leaf_fraction > 0.0_real64 .and. parameters%leaf_rate > 0.0_real64) .or. &
       (parameters%stem_fraction > 0.0_real64 .and. parameters%stem_rate > 0.0_real64))
  end function reallocation_enabled

  pure subroutine evaluate_wofost73_reallocation_reference_call(parameters, committed_state, biomass, dvs, t0, t1, &
                                                                 candidate_state, fluxes, diagnostics)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters
    type(wofost73_reallocation_state_t), intent(in) :: committed_state
    type(wofost73_reallocation_biomass_t), intent(in) :: biomass
    real(real64), intent(in) :: dvs, t0, t1
    type(wofost73_reallocation_state_t), intent(out) :: candidate_state
    type(wofost73_reallocation_flux_t), intent(out) :: fluxes
    type(wofost73_reallocation_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: duration, leaf_rate_amount, stem_rate_amount

    candidate_state = committed_state
    fluxes = wofost73_reallocation_flux_t()
    diagnostics = wofost73_reallocation_diagnostics_t()

    if (t1 <= t0) then
      diagnostics%status = REALLOC_INVALID_INTERVAL
      return
    end if

    duration = t1 - t0
    ! PCSE WOFOST 7.3 computes daily rates and integrates them with delt=1.
    ! Larger/subdaily intervals require a separate scientific derivation,
    ! especially because the remaining-cap limiter is expressed as a daily rate.
    if (transfer(duration, 0_int64) /= transfer(1.0_real64, 0_int64)) then
      diagnostics%status = REALLOC_UNADMITTED_DURATION
      return
    end if

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = REALLOC_INVALID_PARAMETERS
      return
    end if

    if (biomass%leaf < 0.0_real64 .or. biomass%stem < 0.0_real64) then
      diagnostics%status = REALLOC_INVALID_BIOMASS
      return
    end if

    if (.not. valid_state(committed_state)) then
      diagnostics%status = REALLOC_INVALID_STATE
      return
    end if

    if (dvs < parameters%activation_dvs) return

    if (.not. candidate_state%activated) then
      candidate_state%activated = .true.
      candidate_state%leaf_cap = biomass%leaf * parameters%leaf_fraction
      candidate_state%stem_cap = biomass%stem * parameters%stem_fraction
      diagnostics%activated_this_trial = .true.
    end if

    if (candidate_state%leaf_reallocated < candidate_state%leaf_cap) then
      leaf_rate_amount = min(candidate_state%leaf_cap * parameters%leaf_rate, &
                             candidate_state%leaf_cap - candidate_state%leaf_reallocated)
    else
      leaf_rate_amount = 0.0_real64
    end if

    if (candidate_state%stem_reallocated < candidate_state%stem_cap) then
      stem_rate_amount = min(candidate_state%stem_cap * parameters%stem_rate, &
                             candidate_state%stem_cap - candidate_state%stem_reallocated)
    else
      stem_rate_amount = 0.0_real64
    end if

    fluxes%leaf_out = leaf_rate_amount * duration
    fluxes%stem_out = stem_rate_amount * duration
    fluxes%storage_in = (leaf_rate_amount + stem_rate_amount) * parameters%efficiency * duration
    fluxes%conversion_loss = fluxes%leaf_out + fluxes%stem_out - fluxes%storage_in

    candidate_state%leaf_reallocated = candidate_state%leaf_reallocated + fluxes%leaf_out
    candidate_state%stem_reallocated = candidate_state%stem_reallocated + fluxes%stem_out

    diagnostics%dry_matter_residual = fluxes%leaf_out + fluxes%stem_out - &
      fluxes%storage_in - fluxes%conversion_loss
  end subroutine evaluate_wofost73_reallocation_reference_call

  pure logical function valid_parameters(parameters) result(valid)
    type(wofost73_reallocation_parameters_t), intent(in) :: parameters

    valid = parameters%leaf_fraction >= 0.0_real64 .and. parameters%leaf_fraction <= 1.0_real64 .and. &
            parameters%stem_fraction >= 0.0_real64 .and. parameters%stem_fraction <= 1.0_real64 .and. &
            parameters%leaf_rate >= 0.0_real64 .and. parameters%stem_rate >= 0.0_real64 .and. &
            parameters%efficiency >= 0.0_real64 .and. parameters%efficiency <= 1.0_real64
  end function valid_parameters

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

end module mod_wofost73_reallocation
