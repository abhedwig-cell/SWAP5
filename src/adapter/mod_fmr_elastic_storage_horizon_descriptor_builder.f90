module mod_fmr_elastic_storage_horizon_descriptor_builder
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, &
       FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none
  private

  real(real64), parameter, public :: FMR_ELAS_DESCRIPTOR_REFERENCE_HEAD_CM = -100.0_real64

  integer, parameter, public :: FMR_ELAS_DESCRIPTOR_OK = 0
  integer, parameter, public :: FMR_ELAS_DESCRIPTOR_INVALID_GEOMETRY = 1
  integer, parameter, public :: FMR_ELAS_DESCRIPTOR_INVALID_SOURCE = 2
  integer, parameter, public :: FMR_ELAS_DESCRIPTOR_INVALID_RETENTION = 3

  type, public :: fmr_elastic_storage_retention_t
    real(real64) :: wcr = 0.0_real64
    real(real64) :: wcs = 0.0_real64
    real(real64) :: alpha_cm_inv = 0.0_real64
    real(real64) :: npar = 0.0_real64
  end type fmr_elastic_storage_retention_t

  public :: fmr_build_elastic_storage_horizon_descriptor

contains

  subroutine fmr_build_elastic_storage_horizon_descriptor(top_depth_m, bottom_depth_m, rho_dry_g_cm3, &
       organic_matter_available, organic_matter_pct, peat_type_present, retention, horizon, status)
    real(real64), intent(in) :: top_depth_m, bottom_depth_m, rho_dry_g_cm3
    logical, intent(in) :: organic_matter_available, peat_type_present
    real(real64), intent(in) :: organic_matter_pct
    type(fmr_elastic_storage_retention_t), intent(in) :: retention
    type(fmr_elastic_storage_horizon_t), intent(out) :: horizon
    integer, intent(out) :: status

    real(real64) :: mpar, theta_ref, scaled_head

    horizon = fmr_elastic_storage_horizon_t()
    status = FMR_ELAS_DESCRIPTOR_INVALID_GEOMETRY

    if (.not. ieee_is_finite(top_depth_m) .or. .not. ieee_is_finite(bottom_depth_m)) return
    if (top_depth_m < 0.0_real64 .or. bottom_depth_m <= top_depth_m) return

    status = FMR_ELAS_DESCRIPTOR_INVALID_SOURCE
    if (.not. ieee_is_finite(rho_dry_g_cm3) .or. rho_dry_g_cm3 <= 0.0_real64) return
    if (organic_matter_available) then
      if (.not. ieee_is_finite(organic_matter_pct)) return
      if (organic_matter_pct < 0.0_real64 .or. organic_matter_pct > 100.0_real64) return
    end if

    status = FMR_ELAS_DESCRIPTOR_INVALID_RETENTION
    if (.not. ieee_is_finite(retention%wcr) .or. .not. ieee_is_finite(retention%wcs) .or. &
        .not. ieee_is_finite(retention%alpha_cm_inv) .or. .not. ieee_is_finite(retention%npar)) return
    if (retention%wcr < 0.0_real64) return
    if (retention%wcs <= retention%wcr .or. retention%wcs > 1.0_real64) return
    if (retention%alpha_cm_inv <= 0.0_real64 .or. retention%npar <= 1.0_real64) return

    mpar = 1.0_real64 - 1.0_real64 / retention%npar
    scaled_head = retention%alpha_cm_inv * abs(FMR_ELAS_DESCRIPTOR_REFERENCE_HEAD_CM)
    theta_ref = retention%wcr + (retention%wcs - retention%wcr) / &
         (1.0_real64 + scaled_head**retention%npar)**mpar

    if (.not. ieee_is_finite(mpar) .or. .not. ieee_is_finite(theta_ref)) return
    if (theta_ref < retention%wcr .or. theta_ref > retention%wcs) return

    horizon%top_depth_m = top_depth_m
    horizon%bottom_depth_m = bottom_depth_m
    horizon%rho_dry_g_cm3 = rho_dry_g_cm3
    horizon%theta_ref_cm3_cm3 = theta_ref

    if (peat_type_present) then
      horizon%regime = FMR_ELAS_REGIME_PEAT
    else if (.not. organic_matter_available) then
      horizon%regime = FMR_ELAS_REGIME_UNKNOWN
    else if (organic_matter_pct > 15.0_real64) then
      horizon%regime = FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT
    else
      horizon%regime = FMR_ELAS_REGIME_MINERAL
    end if

    status = FMR_ELAS_DESCRIPTOR_OK
  end subroutine fmr_build_elastic_storage_horizon_descriptor

end module mod_fmr_elastic_storage_horizon_descriptor_builder
