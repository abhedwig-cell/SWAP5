module mod_fmr_elastic_storage_horizon_descriptor_materializer
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, &
       FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_HORIZON_OK = 0
  integer, parameter, public :: FMR_ELAS_HORIZON_INVALID_GEOMETRY = 1
  integer, parameter, public :: FMR_ELAS_HORIZON_INVALID_DESCRIPTOR = 2
  integer, parameter, public :: FMR_ELAS_HORIZON_INVALID_RETENTION = 3
  integer, parameter, public :: FMR_ELAS_HORIZON_INVALID_THETA = 4

  real(real64), parameter, public :: FMR_ELAS_HORIZON_REFERENCE_HEAD_CM = -100.0_real64

  type, public :: fmr_elastic_storage_source_horizon_t
    real(real64) :: top_depth_m = 0.0_real64
    real(real64) :: bottom_depth_m = 0.0_real64
    real(real64) :: rho_dry_g_cm3 = 0.0_real64
    logical :: organic_matter_available = .false.
    real(real64) :: organic_matter_pct = 0.0_real64
    logical :: peat_type_present = .false.
    real(real64) :: wcr = 0.0_real64
    real(real64) :: wcs = 0.0_real64
    real(real64) :: alpha_cm_inv = 0.0_real64
    real(real64) :: npar = 0.0_real64
  end type fmr_elastic_storage_source_horizon_t

  type, public :: fmr_elastic_storage_horizon_materialization_diagnostics_t
    integer :: status = FMR_ELAS_HORIZON_INVALID_DESCRIPTOR
    integer :: regime = FMR_ELAS_REGIME_UNKNOWN
    logical :: theta_materialized = .false.
  end type fmr_elastic_storage_horizon_materialization_diagnostics_t

  public :: fmr_materialize_elastic_storage_horizon_descriptor

contains

  subroutine fmr_materialize_elastic_storage_horizon_descriptor(source, horizon, diagnostics)
    type(fmr_elastic_storage_source_horizon_t), intent(in) :: source
    type(fmr_elastic_storage_horizon_t), intent(out) :: horizon
    type(fmr_elastic_storage_horizon_materialization_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: mpar, scaled, theta_ref
    integer :: regime

    horizon = fmr_elastic_storage_horizon_t()
    diagnostics = fmr_elastic_storage_horizon_materialization_diagnostics_t()

    if (.not. ieee_is_finite(source%top_depth_m) .or. .not. ieee_is_finite(source%bottom_depth_m)) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_GEOMETRY
      return
    end if
    if (source%top_depth_m < 0.0_real64 .or. source%bottom_depth_m <= source%top_depth_m) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_GEOMETRY
      return
    end if

    if (.not. ieee_is_finite(source%rho_dry_g_cm3) .or. source%rho_dry_g_cm3 <= 0.0_real64) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_DESCRIPTOR
      return
    end if
    if (source%organic_matter_available) then
      if (.not. ieee_is_finite(source%organic_matter_pct)) then
        diagnostics%status = FMR_ELAS_HORIZON_INVALID_DESCRIPTOR
        return
      end if
      if (source%organic_matter_pct < 0.0_real64 .or. source%organic_matter_pct > 100.0_real64) then
        diagnostics%status = FMR_ELAS_HORIZON_INVALID_DESCRIPTOR
        return
      end if
    end if

    if (source%peat_type_present) then
      regime = FMR_ELAS_REGIME_PEAT
    else if (.not. source%organic_matter_available) then
      regime = FMR_ELAS_REGIME_UNKNOWN
    else if (source%organic_matter_pct > 15.0_real64) then
      regime = FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT
    else
      regime = FMR_ELAS_REGIME_MINERAL
    end if
    diagnostics%regime = regime

    if (.not. ieee_is_finite(source%wcr) .or. .not. ieee_is_finite(source%wcs) .or. &
        .not. ieee_is_finite(source%alpha_cm_inv) .or. .not. ieee_is_finite(source%npar)) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_RETENTION
      return
    end if
    if (source%wcr < 0.0_real64 .or. source%wcs <= source%wcr .or. source%wcs > 1.0_real64) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_RETENTION
      return
    end if
    if (source%alpha_cm_inv <= 0.0_real64 .or. source%npar <= 1.0_real64) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_RETENTION
      return
    end if

    mpar = 1.0_real64 - 1.0_real64 / source%npar
    scaled = source%alpha_cm_inv * abs(FMR_ELAS_HORIZON_REFERENCE_HEAD_CM)
    theta_ref = source%wcr + (source%wcs - source%wcr) / &
         (1.0_real64 + scaled ** source%npar) ** mpar

    if (.not. ieee_is_finite(theta_ref)) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_THETA
      return
    end if
    if (theta_ref < source%wcr .or. theta_ref > source%wcs) then
      diagnostics%status = FMR_ELAS_HORIZON_INVALID_THETA
      return
    end if

    horizon%top_depth_m = source%top_depth_m
    horizon%bottom_depth_m = source%bottom_depth_m
    horizon%rho_dry_g_cm3 = source%rho_dry_g_cm3
    horizon%theta_ref_cm3_cm3 = theta_ref
    horizon%regime = regime

    diagnostics%theta_materialized = .true.
    diagnostics%status = FMR_ELAS_HORIZON_OK
  end subroutine fmr_materialize_elastic_storage_horizon_descriptor

end module mod_fmr_elastic_storage_horizon_descriptor_materializer
