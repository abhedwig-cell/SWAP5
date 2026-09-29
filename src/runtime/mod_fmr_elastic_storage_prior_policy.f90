module mod_fmr_elastic_storage_prior_policy
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_PRIOR_OK = 0
  integer, parameter, public :: FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED = 1
  integer, parameter, public :: FMR_ELAS_PRIOR_INVALID_INPUT = 2
  integer, parameter, public :: FMR_ELAS_PRIOR_OUT_OF_DOMAIN = 3

  integer, parameter, public :: FMR_ELAS_REGIME_MINERAL = 1
  integer, parameter, public :: FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT = 2
  integer, parameter, public :: FMR_ELAS_REGIME_PEAT = 3
  integer, parameter, public :: FMR_ELAS_REGIME_UNKNOWN = 4

  integer, parameter, public :: FMR_ELAS_DOMAIN_IN = 1
  integer, parameter, public :: FMR_ELAS_DOMAIN_EDGE = 2
  integer, parameter, public :: FMR_ELAS_DOMAIN_OUT = 3

  real(real64), parameter, public :: FMR_ELAS_REFERENCE_HEAD_CM = -100.0_real64
  real(real64), parameter, public :: FMR_ELAS_UNCERTAINTY_FACTOR = 2.123968031921196_real64

  real(real64), parameter :: RHO_MEAN = 1.4337873737373736_real64
  real(real64), parameter :: RHO_SD = 0.34422692442216535_real64
  real(real64), parameter :: WATER_MEAN = 191.8190909090909_real64
  real(real64), parameter :: WATER_SD = 182.02868188688447_real64
  real(real64), parameter :: INTERCEPT = -5.144312248981006_real64
  real(real64), parameter :: RHO_COEF = -0.25581251314464676_real64
  real(real64), parameter :: WATER_COEF = 0.15229775506831100_real64

  type, public :: fmr_elastic_storage_prior_t
    logical :: available = .false.
    real(real64) :: value_cm_inv = 0.0_real64
    real(real64) :: lower_cm_inv = 0.0_real64
    real(real64) :: upper_cm_inv = 0.0_real64
    real(real64) :: reference_head_cm = FMR_ELAS_REFERENCE_HEAD_CM
    real(real64) :: wet_density_g_cm3 = 0.0_real64
    real(real64) :: water_content_pct = 0.0_real64
    real(real64) :: z_rho = 0.0_real64
    real(real64) :: z_water = 0.0_real64
    integer :: regime = FMR_ELAS_REGIME_UNKNOWN
    integer :: domain_class = FMR_ELAS_DOMAIN_OUT
  end type fmr_elastic_storage_prior_t

  public :: materialize_fmr_elastic_storage_prior

contains

  subroutine materialize_fmr_elastic_storage_prior(rho_dry_g_cm3, theta_ref_cm3_cm3, regime, prior, status)
    real(real64), intent(in) :: rho_dry_g_cm3
    real(real64), intent(in) :: theta_ref_cm3_cm3
    integer, intent(in) :: regime
    type(fmr_elastic_storage_prior_t), intent(out) :: prior
    integer, intent(out) :: status

    real(real64) :: max_abs_z, log10_elas

    prior = fmr_elastic_storage_prior_t()
    prior%regime = regime
    status = FMR_ELAS_PRIOR_INVALID_INPUT

    if (.not. valid_regime(regime)) return
    if (regime /= FMR_ELAS_REGIME_MINERAL) then
      status = FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED
      return
    end if

    if (.not. ieee_is_finite(rho_dry_g_cm3) .or. .not. ieee_is_finite(theta_ref_cm3_cm3)) return
    if (rho_dry_g_cm3 <= 0.0_real64) return
    if (theta_ref_cm3_cm3 < 0.0_real64 .or. theta_ref_cm3_cm3 > 1.0_real64) return

    prior%wet_density_g_cm3 = rho_dry_g_cm3 + theta_ref_cm3_cm3
    prior%water_content_pct = 100.0_real64 * theta_ref_cm3_cm3 / rho_dry_g_cm3
    prior%z_rho = (prior%wet_density_g_cm3 - RHO_MEAN) / RHO_SD
    prior%z_water = (prior%water_content_pct - WATER_MEAN) / WATER_SD

    if (.not. ieee_is_finite(prior%wet_density_g_cm3) .or. &
        .not. ieee_is_finite(prior%water_content_pct) .or. &
        .not. ieee_is_finite(prior%z_rho) .or. .not. ieee_is_finite(prior%z_water)) return

    max_abs_z = max(abs(prior%z_rho), abs(prior%z_water))
    if (max_abs_z <= 2.0_real64) then
      prior%domain_class = FMR_ELAS_DOMAIN_IN
    else if (max_abs_z <= 3.0_real64) then
      prior%domain_class = FMR_ELAS_DOMAIN_EDGE
    else
      prior%domain_class = FMR_ELAS_DOMAIN_OUT
      status = FMR_ELAS_PRIOR_OUT_OF_DOMAIN
      return
    end if

    log10_elas = INTERCEPT + RHO_COEF * prior%z_rho + WATER_COEF * prior%z_water
    prior%value_cm_inv = 10.0_real64 ** log10_elas
    prior%lower_cm_inv = prior%value_cm_inv / FMR_ELAS_UNCERTAINTY_FACTOR
    prior%upper_cm_inv = prior%value_cm_inv * FMR_ELAS_UNCERTAINTY_FACTOR

    if (.not. ieee_is_finite(prior%value_cm_inv) .or. &
        .not. ieee_is_finite(prior%lower_cm_inv) .or. .not. ieee_is_finite(prior%upper_cm_inv)) then
      prior = fmr_elastic_storage_prior_t()
      prior%regime = regime
      status = FMR_ELAS_PRIOR_INVALID_INPUT
      return
    end if
    if (prior%value_cm_inv <= 0.0_real64 .or. prior%lower_cm_inv <= 0.0_real64 .or. &
        prior%upper_cm_inv <= prior%value_cm_inv .or. prior%lower_cm_inv >= prior%value_cm_inv) then
      prior = fmr_elastic_storage_prior_t()
      prior%regime = regime
      status = FMR_ELAS_PRIOR_INVALID_INPUT
      return
    end if

    prior%available = .true.
    status = FMR_ELAS_PRIOR_OK
  end subroutine materialize_fmr_elastic_storage_prior

  pure logical function valid_regime(regime) result(valid)
    integer, intent(in) :: regime
    valid = regime == FMR_ELAS_REGIME_MINERAL .or. &
         regime == FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT .or. &
         regime == FMR_ELAS_REGIME_PEAT .or. regime == FMR_ELAS_REGIME_UNKNOWN
  end function valid_regime

end module mod_fmr_elastic_storage_prior_policy
