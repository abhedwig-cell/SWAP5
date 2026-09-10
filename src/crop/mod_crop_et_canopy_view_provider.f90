module mod_crop_et_canopy_view_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, &
       WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: CROP_ET_CANOPY_OK = 0
  integer, parameter, public :: CROP_ET_CANOPY_INVALID_PARAMETER = 1
  integer, parameter, public :: CROP_ET_CANOPY_INVALID_TABLE = 2
  integer, parameter, public :: CROP_ET_CANOPY_INVALID_STATE = 3
  integer, parameter, public :: CROP_ET_CANOPY_INVALID_CO2_FORCING = 4
  integer, parameter, public :: CROP_ET_CANOPY_INVALID_RESULT = 5

  type, public :: crop_et_canopy_parameters_t
    private
    logical :: initialized = .false.
    logical :: co2_correction_enabled = .false.
    real(real64) :: direct_extinction_coefficient = 0.0_real64
    real(real64) :: diffuse_extinction_coefficient = 0.0_real64
    type(wofost_rate_table_t) :: crop_factor_by_development_stage
    type(wofost_rate_table_t) :: transpiration_factor_by_co2
  contains
    procedure, public :: ready => crop_et_canopy_parameters_ready
    procedure, public :: co2_enabled => crop_et_canopy_parameters_co2_enabled
  end type crop_et_canopy_parameters_t

  type, public :: crop_et_canopy_state_view_t
    logical :: crop_emerged = .false.
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: leaf_area_index = 0.0_real64
  end type crop_et_canopy_state_view_t

  type, public :: crop_et_canopy_forcing_t
    real(real64) :: atmospheric_co2_ppm = 0.0_real64
  end type crop_et_canopy_forcing_t

  type, public :: crop_et_canopy_view_t
    logical :: crop_emerged = .false.
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: crop_factor = 0.0_real64
    real(real64) :: co2_transpiration_factor = 0.0_real64
    logical :: crop_specific_factors_valid = .false.
  end type crop_et_canopy_view_t

  type, public :: crop_et_canopy_diagnostics_t
    integer :: status = CROP_ET_CANOPY_OK
    logical :: state_consumed = .false.
    logical :: crop_factor_table_consumed = .false.
    logical :: co2_forcing_consumed = .false.
    logical :: co2_table_consumed = .false.
    logical :: result_produced = .false.
  end type crop_et_canopy_diagnostics_t

  public :: construct_crop_et_canopy_parameters
  public :: evaluate_crop_et_canopy_view

contains

  subroutine construct_crop_et_canopy_parameters(kdir, kdif, cftb_dvs, cftb_factor, &
                                                  co2_enabled, parameters, status, &
                                                  co2tb_ppm, co2tb_factor)
    real(real64), intent(in) :: kdir, kdif
    real(real64), intent(in) :: cftb_dvs(:), cftb_factor(:)
    logical, intent(in) :: co2_enabled
    type(crop_et_canopy_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    real(real64), intent(in), optional :: co2tb_ppm(:), co2tb_factor(:)
    integer :: table_status

    parameters = crop_et_canopy_parameters_t()
    status = CROP_ET_CANOPY_INVALID_PARAMETER

    if (.not. valid_inclusive(kdir, 0.0_real64, 2.0_real64)) return
    if (.not. valid_inclusive(kdif, 0.0_real64, 2.0_real64)) return
    if (.not. valid_table_domain(cftb_dvs, cftb_factor, 0.0_real64, 2.0_real64, &
                                 0.0_real64, 2.0_real64)) then
      status = CROP_ET_CANOPY_INVALID_TABLE
      return
    end if

    call construct_wofost_rate_table(cftb_dvs, cftb_factor, &
                                     parameters%crop_factor_by_development_stage, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) then
      status = CROP_ET_CANOPY_INVALID_TABLE
      return
    end if

    if (co2_enabled) then
      if (.not. present(co2tb_ppm) .or. .not. present(co2tb_factor)) then
        status = CROP_ET_CANOPY_INVALID_TABLE
        return
      end if
      if (.not. valid_table_domain(co2tb_ppm, co2tb_factor, 0.0_real64, 3000.0_real64, &
                                   0.0_real64, 2.0_real64)) then
        status = CROP_ET_CANOPY_INVALID_TABLE
        return
      end if
      call construct_wofost_rate_table(co2tb_ppm, co2tb_factor, &
                                       parameters%transpiration_factor_by_co2, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK) then
        status = CROP_ET_CANOPY_INVALID_TABLE
        return
      end if
    end if

    parameters%direct_extinction_coefficient = kdir
    parameters%diffuse_extinction_coefficient = kdif
    parameters%co2_correction_enabled = co2_enabled
    parameters%initialized = .true.
    status = CROP_ET_CANOPY_OK
  end subroutine construct_crop_et_canopy_parameters

  logical function crop_et_canopy_parameters_ready(self) result(ready)
    class(crop_et_canopy_parameters_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (.not. valid_inclusive(self%direct_extinction_coefficient, 0.0_real64, 2.0_real64)) return
    if (.not. valid_inclusive(self%diffuse_extinction_coefficient, 0.0_real64, 2.0_real64)) return
    if (.not. self%crop_factor_by_development_stage%ready()) return
    if (self%co2_correction_enabled) then
      if (.not. self%transpiration_factor_by_co2%ready()) return
    end if
    ready = .true.
  end function crop_et_canopy_parameters_ready

  logical function crop_et_canopy_parameters_co2_enabled(self) result(enabled)
    class(crop_et_canopy_parameters_t), intent(in) :: self
    enabled = self%initialized .and. self%co2_correction_enabled
  end function crop_et_canopy_parameters_co2_enabled

  subroutine evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    type(crop_et_canopy_parameters_t), intent(in) :: parameters
    type(crop_et_canopy_state_view_t), intent(in) :: state
    type(crop_et_canopy_forcing_t), intent(in) :: forcing
    type(crop_et_canopy_view_t), intent(out) :: view
    type(crop_et_canopy_diagnostics_t), intent(out) :: diagnostics
    integer :: table_status
    real(real64) :: extinction_product, optical_depth

    view = crop_et_canopy_view_t()
    diagnostics = crop_et_canopy_diagnostics_t()

    if (.not. parameters%ready()) then
      diagnostics%status = CROP_ET_CANOPY_INVALID_PARAMETER
      return
    end if

    if (.not. ieee_is_finite(state%leaf_area_index) .or. state%leaf_area_index < 0.0_real64) then
      diagnostics%status = CROP_ET_CANOPY_INVALID_STATE
      return
    end if

    extinction_product = parameters%direct_extinction_coefficient * &
                         parameters%diffuse_extinction_coefficient
    if (.not. ieee_is_finite(extinction_product)) then
      diagnostics%status = CROP_ET_CANOPY_INVALID_PARAMETER
      return
    end if
    if (extinction_product > 1.0_real64) then
      if (state%leaf_area_index > huge(1.0_real64) / extinction_product) then
        diagnostics%status = CROP_ET_CANOPY_INVALID_STATE
        return
      end if
    end if

    optical_depth = extinction_product * state%leaf_area_index
    if (.not. ieee_is_finite(optical_depth)) then
      diagnostics%status = CROP_ET_CANOPY_INVALID_RESULT
      return
    end if

    view%crop_emerged = state%crop_emerged
    view%vegetation_cover_fraction = 1.0_real64 - exp(-optical_depth)
    diagnostics%state_consumed = .true.

    if (.not. valid_inclusive(view%vegetation_cover_fraction, 0.0_real64, 1.0_real64)) then
      view = crop_et_canopy_view_t()
      diagnostics%status = CROP_ET_CANOPY_INVALID_RESULT
      return
    end if

    if (.not. state%crop_emerged) then
      ! Legacy ETpot still consumes VCOVER for PEVA/EPOND, but CF and FCO2TRA
      ! are inactive dependencies when the crop is not emerged.
      view%crop_factor = 0.0_real64
      view%co2_transpiration_factor = 1.0_real64
      view%crop_specific_factors_valid = .false.
      diagnostics%result_produced = .true.
      diagnostics%status = CROP_ET_CANOPY_OK
      return
    end if

    if (.not. ieee_is_finite(state%development_stage)) then
      view = crop_et_canopy_view_t()
      diagnostics%status = CROP_ET_CANOPY_INVALID_STATE
      return
    end if

    call parameters%crop_factor_by_development_stage%evaluate(state%development_stage, &
                                                               view%crop_factor, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. &
        .not. valid_inclusive(view%crop_factor, 0.0_real64, 2.0_real64)) then
      view = crop_et_canopy_view_t()
      diagnostics%status = CROP_ET_CANOPY_INVALID_RESULT
      return
    end if
    diagnostics%crop_factor_table_consumed = .true.

    view%co2_transpiration_factor = 1.0_real64
    if (parameters%co2_correction_enabled) then
      if (.not. valid_inclusive(forcing%atmospheric_co2_ppm, 10.0_real64, 3000.0_real64)) then
        view = crop_et_canopy_view_t()
        diagnostics%status = CROP_ET_CANOPY_INVALID_CO2_FORCING
        return
      end if
      diagnostics%co2_forcing_consumed = .true.
      call parameters%transpiration_factor_by_co2%evaluate(forcing%atmospheric_co2_ppm, &
                                                            view%co2_transpiration_factor, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK .or. &
          .not. valid_inclusive(view%co2_transpiration_factor, 0.0_real64, 2.0_real64)) then
        view = crop_et_canopy_view_t()
        diagnostics%status = CROP_ET_CANOPY_INVALID_RESULT
        return
      end if
      diagnostics%co2_table_consumed = .true.
    end if

    view%crop_specific_factors_valid = .true.
    diagnostics%result_produced = .true.
    diagnostics%status = CROP_ET_CANOPY_OK
  end subroutine evaluate_crop_et_canopy_view

  logical function valid_table_domain(x, y, xmin, xmax, ymin, ymax) result(valid)
    real(real64), intent(in) :: x(:), y(:)
    real(real64), intent(in) :: xmin, xmax, ymin, ymax

    valid = .false.
    if (size(x) < 1 .or. size(y) /= size(x)) return
    if (.not. all(ieee_is_finite(x)) .or. .not. all(ieee_is_finite(y))) return
    if (any(x < xmin) .or. any(x > xmax)) return
    if (any(y < ymin) .or. any(y > ymax)) return
    valid = .true.
  end function valid_table_domain

  logical function valid_inclusive(value, lower, upper) result(valid)
    real(real64), intent(in) :: value, lower, upper

    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= lower .and. value <= upper
  end function valid_inclusive

end module mod_crop_et_canopy_view_provider
