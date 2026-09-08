module mod_reference_et_transpiration_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_uptake_input_assembly, only: root_uptake_et_result_t
  implicit none
  private

  integer, parameter, public :: REF_ET_TRA_OK = 0
  integer, parameter, public :: REF_ET_TRA_INVALID_REFERENCE_ET = 1
  integer, parameter, public :: REF_ET_TRA_INVALID_COVER = 2
  integer, parameter, public :: REF_ET_TRA_INVALID_CROP_FACTOR = 3
  integer, parameter, public :: REF_ET_TRA_INVALID_CO2_FACTOR = 4
  integer, parameter, public :: REF_ET_TRA_INVALID_RESULT = 5

  type, public :: reference_et_forcing_t
    real(real64) :: reference_et_mm_per_day = 0.0_real64
  end type reference_et_forcing_t

  type, public :: transpiration_canopy_view_t
    logical :: crop_emerged = .false.
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: crop_factor = 0.0_real64
    real(real64) :: co2_transpiration_factor = 1.0_real64
  end type transpiration_canopy_view_t

  type, public :: reference_et_transpiration_diagnostics_t
    integer :: status = REF_ET_TRA_OK
    logical :: forcing_consumed = .false.
    logical :: canopy_consumed = .false.
    logical :: result_produced = .false.
  end type reference_et_transpiration_diagnostics_t

  public :: evaluate_reference_et_transpiration

contains

  subroutine evaluate_reference_et_transpiration(forcing, canopy, result, diagnostics)
    type(reference_et_forcing_t), intent(in) :: forcing
    type(transpiration_canopy_view_t), intent(in) :: canopy
    type(root_uptake_et_result_t), intent(out) :: result
    type(reference_et_transpiration_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: et0_mm_per_day
    real(real64) :: ptra_cm_per_day

    result = root_uptake_et_result_t()
    diagnostics = reference_et_transpiration_diagnostics_t()

    ! The non-emerged route is canonical and does not inspect potentially stale
    ! active-crop forcing/canopy values. F-WOF13 also preserves this dependency-free route.
    if (.not. canopy%crop_emerged) then
      diagnostics%result_produced = .true.
      return
    end if

    diagnostics%forcing_consumed = .true.
    diagnostics%canopy_consumed = .true.

    ! Keep finiteness checks separate from ordered comparisons. Fortran does not
    ! guarantee short-circuit evaluation of .or., so combining these guards could
    ! evaluate an ordered comparison on NaN under trapping arithmetic.
    if (.not. ieee_is_finite(forcing%reference_et_mm_per_day)) then
      diagnostics%status = REF_ET_TRA_INVALID_REFERENCE_ET
      return
    end if
    if (forcing%reference_et_mm_per_day < 0.0_real64) then
      diagnostics%status = REF_ET_TRA_INVALID_REFERENCE_ET
      return
    end if

    if (.not. ieee_is_finite(canopy%vegetation_cover_fraction)) then
      diagnostics%status = REF_ET_TRA_INVALID_COVER
      return
    end if
    if (canopy%vegetation_cover_fraction < 0.0_real64 .or. canopy%vegetation_cover_fraction > 1.0_real64) then
      diagnostics%status = REF_ET_TRA_INVALID_COVER
      return
    end if

    if (.not. ieee_is_finite(canopy%crop_factor)) then
      diagnostics%status = REF_ET_TRA_INVALID_CROP_FACTOR
      return
    end if
    if (canopy%crop_factor < 0.0_real64) then
      diagnostics%status = REF_ET_TRA_INVALID_CROP_FACTOR
      return
    end if

    if (.not. ieee_is_finite(canopy%co2_transpiration_factor)) then
      diagnostics%status = REF_ET_TRA_INVALID_CO2_FACTOR
      return
    end if
    if (canopy%co2_transpiration_factor < 0.0_real64) then
      diagnostics%status = REF_ET_TRA_INVALID_CO2_FACTOR
      return
    end if

    ! B1.10 SWETR=1, SWMETDETAIL=0, SWINTER=0:
    !   et0      = etr * vcover * cf                       [mm d-1]
    !   ptra_dry = max(et0 * 0.1, 0) * fco2tra           [cm d-1]
    !   wfrac    = 0, so ptra = ptra_dry.
    et0_mm_per_day = forcing%reference_et_mm_per_day * canopy%vegetation_cover_fraction * canopy%crop_factor
    ptra_cm_per_day = max(et0_mm_per_day * 0.1_real64, 0.0_real64) * canopy%co2_transpiration_factor

    if (.not. ieee_is_finite(ptra_cm_per_day)) then
      diagnostics%status = REF_ET_TRA_INVALID_RESULT
      return
    end if
    if (ptra_cm_per_day < 0.0_real64) then
      diagnostics%status = REF_ET_TRA_INVALID_RESULT
      return
    end if

    result%potential_transpiration = ptra_cm_per_day
    diagnostics%result_produced = .true.
  end subroutine evaluate_reference_et_transpiration

end module mod_reference_et_transpiration_process
