module mod_reference_et_demand_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: REF_ET_DEMAND_OK = 0
  integer, parameter, public :: REF_ET_DEMAND_INVALID_REFERENCE_ET = 1
  integer, parameter, public :: REF_ET_DEMAND_INVALID_COVER = 2
  integer, parameter, public :: REF_ET_DEMAND_INVALID_POND_FACTOR = 3
  integer, parameter, public :: REF_ET_DEMAND_INVALID_CROP_FACTOR = 4
  integer, parameter, public :: REF_ET_DEMAND_INVALID_CO2_FACTOR = 5
  integer, parameter, public :: REF_ET_DEMAND_INVALID_RESULT = 6

  type, public :: reference_et_demand_parameters_t
    real(real64) :: pond_evaporation_factor = 1.0_real64
  end type reference_et_demand_parameters_t

  type, public :: reference_et_demand_forcing_t
    real(real64) :: reference_et_mm_per_day = 0.0_real64
  end type reference_et_demand_forcing_t

  type, public :: reference_et_demand_canopy_view_t
    logical :: crop_emerged = .false.
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: crop_factor = 0.0_real64
    real(real64) :: co2_transpiration_factor = 1.0_real64
  end type reference_et_demand_canopy_view_t

  type, public :: reference_et_demand_result_t
    real(real64) :: potential_transpiration_cm_per_day = 0.0_real64
    real(real64) :: potential_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
  end type reference_et_demand_result_t

  type, public :: reference_et_demand_diagnostics_t
    integer :: status = REF_ET_DEMAND_OK
    logical :: forcing_consumed = .false.
    logical :: canopy_cover_consumed = .false.
    logical :: crop_specific_factors_consumed = .false.
    logical :: result_produced = .false.
  end type reference_et_demand_diagnostics_t

  public :: evaluate_restricted_reference_et_demand

contains

  subroutine evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    type(reference_et_demand_parameters_t), intent(in) :: parameters
    type(reference_et_demand_forcing_t), intent(in) :: forcing
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(reference_et_demand_result_t), intent(out) :: result
    type(reference_et_demand_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: uncovered_reference_et_mm_per_day
    real(real64) :: transpiration_reference_et_mm_per_day

    result = reference_et_demand_result_t()
    diagnostics = reference_et_demand_diagnostics_t()

    diagnostics%forcing_consumed = .true.
    diagnostics%canopy_cover_consumed = .true.

    if (.not. ieee_is_finite(forcing%reference_et_mm_per_day)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_REFERENCE_ET
      return
    end if
    if (forcing%reference_et_mm_per_day < 0.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_REFERENCE_ET
      return
    end if

    if (.not. ieee_is_finite(canopy%vegetation_cover_fraction)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_COVER
      return
    end if
    if (canopy%vegetation_cover_fraction < 0.0_real64 .or. canopy%vegetation_cover_fraction > 1.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_COVER
      return
    end if

    if (.not. ieee_is_finite(parameters%pond_evaporation_factor)) then
      diagnostics%status = REF_ET_DEMAND_INVALID_POND_FACTOR
      return
    end if
    if (parameters%pond_evaporation_factor < 0.0_real64) then
      diagnostics%status = REF_ET_DEMAND_INVALID_POND_FACTOR
      return
    end if

    ! B1.10 MOD_meteo ETpot, restricted route:
    ! SWETR=1, SWMETDETAIL=0, SWCFBS=0, SWINTER=0.
    ! etr, es0, ep0 and et0 are in mm/day; public demands are cm/day.
    uncovered_reference_et_mm_per_day = forcing%reference_et_mm_per_day * &
                                         (1.0_real64 - canopy%vegetation_cover_fraction)
    result%potential_soil_evaporation_cm_per_day = max(uncovered_reference_et_mm_per_day * 0.1_real64, 0.0_real64)
    result%potential_pond_evaporation_cm_per_day = max(uncovered_reference_et_mm_per_day * &
                                                       parameters%pond_evaporation_factor * 0.1_real64, 0.0_real64)

    ! The legacy bare-soil and pond demands use vcover independently of the
    ! crop-emergence flag. Crop-specific CF and fco2tra are consumed only for
    ! the emerged-crop transpiration route.
    if (canopy%crop_emerged) then
      diagnostics%crop_specific_factors_consumed = .true.

      if (.not. ieee_is_finite(canopy%crop_factor)) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CROP_FACTOR
        return
      end if
      if (canopy%crop_factor < 0.0_real64) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CROP_FACTOR
        return
      end if

      if (.not. ieee_is_finite(canopy%co2_transpiration_factor)) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CO2_FACTOR
        return
      end if
      if (canopy%co2_transpiration_factor < 0.0_real64) then
        diagnostics%status = REF_ET_DEMAND_INVALID_CO2_FACTOR
        return
      end if

      transpiration_reference_et_mm_per_day = forcing%reference_et_mm_per_day * &
                                               canopy%vegetation_cover_fraction * canopy%crop_factor
      result%potential_transpiration_cm_per_day = max(transpiration_reference_et_mm_per_day * 0.1_real64, &
                                                      0.0_real64) * canopy%co2_transpiration_factor
    end if

    if (.not. result_is_valid(result)) then
      result = reference_et_demand_result_t()
      diagnostics%status = REF_ET_DEMAND_INVALID_RESULT
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine evaluate_restricted_reference_et_demand

  pure logical function result_is_valid(result) result(valid)
    type(reference_et_demand_result_t), intent(in) :: result

    valid = ieee_is_finite(result%potential_transpiration_cm_per_day) .and. &
            ieee_is_finite(result%potential_soil_evaporation_cm_per_day) .and. &
            ieee_is_finite(result%potential_pond_evaporation_cm_per_day)
    if (.not. valid) return

    valid = result%potential_transpiration_cm_per_day >= 0.0_real64 .and. &
            result%potential_soil_evaporation_cm_per_day >= 0.0_real64 .and. &
            result%potential_pond_evaporation_cm_per_day >= 0.0_real64
  end function result_is_valid

end module mod_reference_et_demand_process
