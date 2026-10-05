module mod_tillage_constitutive_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: TILLAGE_OK = 0
  integer, parameter, public :: TILLAGE_INVALID_EVENTS = 1
  integer, parameter, public :: TILLAGE_INVALID_PARAMETERS = 2
  real(real64), parameter :: MINERAL_PARTICLE_DENSITY = 2650.0_real64

  type, public :: tillage_vg_parameters_t
    real(real64) :: theta_residual = 0.0_real64
    real(real64) :: theta_saturated = 0.0_real64
    real(real64) :: saturated_conductivity = 0.0_real64
    real(real64) :: alpha = 0.0_real64
    real(real64) :: lambda = 0.0_real64
    real(real64) :: n = 0.0_real64
    real(real64) :: m = 0.0_real64
  end type tillage_vg_parameters_t

  public :: select_tillage_start_event, transform_tillage_vg
  public :: apply_tillage_density_event, consolidate_tillage_density

contains

  pure subroutine select_tillage_start_event(event_days, start_day, next_event, previous_event, status)
    real(real64), intent(in) :: event_days(:), start_day
    integer, intent(out) :: next_event, previous_event, status
    integer :: i

    next_event = 0
    previous_event = 0
    status = TILLAGE_INVALID_EVENTS
    if (size(event_days) < 1 .or. .not. ieee_is_finite(start_day)) return
    if (any(.not. ieee_is_finite(event_days))) return
    do i = 2, size(event_days)
      ! Equal dates cannot be executed separately by the daily legacy gate.
      if (event_days(i) <= event_days(i-1)) return
    end do
    next_event = size(event_days) + 1
    do i = 1, size(event_days)
      if (start_day <= event_days(i)) then
        next_event = i
        exit
      end if
    end do
    previous_event = next_event - 1
    status = TILLAGE_OK
  end subroutine select_tillage_start_event

  pure subroutine apply_tillage_density_event(prior_density, target_density, intensity, candidate_density, status)
    real(real64), intent(in) :: prior_density(:), target_density(:), intensity
    real(real64), allocatable, intent(out) :: candidate_density(:)
    integer, intent(out) :: status

    status = TILLAGE_INVALID_PARAMETERS
    if (size(prior_density) < 1 .or. size(target_density) /= size(prior_density)) return
    if (.not. ieee_is_finite(intensity) .or. intensity < 0.0_real64 .or. intensity > 1.0_real64) return
    if (any(.not. ieee_is_finite(prior_density)) .or. any(.not. ieee_is_finite(target_density))) return
    if (any(prior_density <= 0.0_real64) .or. any(target_density <= 0.0_real64)) return
    if (any(prior_density >= MINERAL_PARTICLE_DENSITY) .or. &
        any(target_density >= MINERAL_PARTICLE_DENSITY)) return
    allocate(candidate_density(size(prior_density)))
    candidate_density = prior_density - intensity*(prior_density-target_density)
    status = TILLAGE_OK
  end subroutine apply_tillage_density_event

  pure subroutine consolidate_tillage_density(event_density, consolidation_density, rate_per_mm, &
                                               accepted_net_rain_cm, candidate_density, status)
    real(real64), intent(in) :: event_density(:), consolidation_density(:), rate_per_mm(:)
    real(real64), intent(in) :: accepted_net_rain_cm
    real(real64), allocatable, intent(out) :: candidate_density(:)
    integer, intent(out) :: status
    integer :: n

    status = TILLAGE_INVALID_PARAMETERS
    n = size(event_density)
    if (n < 1 .or. size(consolidation_density) /= n .or. size(rate_per_mm) /= n) return
    if (.not. ieee_is_finite(accepted_net_rain_cm) .or. accepted_net_rain_cm < 0.0_real64) return
    if (any(.not. ieee_is_finite(event_density)) .or. &
        any(.not. ieee_is_finite(consolidation_density)) .or. any(.not. ieee_is_finite(rate_per_mm))) return
    if (any(event_density <= 0.0_real64) .or. any(consolidation_density <= 0.0_real64) .or. &
        any(event_density >= MINERAL_PARTICLE_DENSITY) .or. &
        any(consolidation_density >= MINERAL_PARTICLE_DENSITY) .or. any(rate_per_mm < 0.0_real64)) return
    allocate(candidate_density(n))
    candidate_density = consolidation_density - &
         (consolidation_density-event_density)*exp(-rate_per_mm*accepted_net_rain_cm*10.0_real64)
    status = TILLAGE_OK
  end subroutine consolidate_tillage_density

  pure subroutine transform_tillage_vg(prior, prior_density, new_density, n_model, silt_fraction, &
                                        clay_fraction, matching_slope, candidate, status)
    type(tillage_vg_parameters_t), intent(in) :: prior
    real(real64), intent(in) :: prior_density, new_density, silt_fraction, clay_fraction, matching_slope
    integer, intent(in) :: n_model
    type(tillage_vg_parameters_t), intent(out) :: candidate
    integer, intent(out) :: status
    real(real64) :: density_ratio, epsilon_n

    candidate = prior
    status = TILLAGE_INVALID_PARAMETERS
    if (.not. all(ieee_is_finite([prior_density,new_density,silt_fraction,clay_fraction,matching_slope, &
         prior%theta_residual,prior%theta_saturated,prior%saturated_conductivity,prior%alpha,prior%lambda,prior%n]))) return
    if (prior_density <= 0.0_real64 .or. prior_density >= MINERAL_PARTICLE_DENSITY .or. &
        new_density <= 0.0_real64 .or. new_density >= MINERAL_PARTICLE_DENSITY) return
    if (prior%theta_residual < 0.0_real64 .or. prior%theta_saturated <= prior%theta_residual .or. &
        prior%theta_saturated > 1.0_real64 .or. prior%saturated_conductivity <= 0.0_real64 .or. &
        prior%alpha <= 0.0_real64 .or. prior%n <= 1.0_real64) return
    if (silt_fraction < 0.0_real64 .or. clay_fraction < 0.0_real64) return
    if (n_model < 1 .or. n_model > 3) return
    if (n_model == 2 .and. clay_fraction <= 0.0_real64) return

    density_ratio = new_density/prior_density
    candidate%theta_residual = prior%theta_residual*density_ratio
    candidate%theta_saturated = prior%theta_saturated* &
         (MINERAL_PARTICLE_DENSITY-new_density)/(MINERAL_PARTICLE_DENSITY-prior_density)
    candidate%saturated_conductivity = prior%saturated_conductivity* &
         (candidate%theta_saturated/prior%theta_saturated)**3*density_ratio**(-3)
    candidate%alpha = prior%alpha*density_ratio**(-3.97_real64)
    select case (n_model)
    case (1)
      candidate%n = prior%n
    case (2)
      epsilon_n = -0.97_real64 + 1.28_real64*silt_fraction/clay_fraction
      candidate%n = 1.0_real64 + (prior%n-1.0_real64)*density_ratio**epsilon_n
    case (3)
      candidate%n = max(1.001_real64, prior%n + (new_density-prior_density)*matching_slope)
    end select
    candidate%m = 1.0_real64 - 1.0_real64/candidate%n
    if (.not. all(ieee_is_finite([candidate%theta_residual,candidate%theta_saturated, &
         candidate%saturated_conductivity,candidate%alpha,candidate%n,candidate%m]))) then
      candidate = prior
      return
    end if
    if (candidate%theta_saturated <= candidate%theta_residual .or. &
        candidate%theta_saturated > 1.0_real64 .or. candidate%n <= 1.0_real64) then
      candidate = prior
      return
    end if
    status = TILLAGE_OK
  end subroutine transform_tillage_vg

end module mod_tillage_constitutive_process
