module mod_crop_co2_response_resolver
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: CROP_CO2_RESPONSE_OK = 0
  integer, parameter, public :: CROP_CO2_RESPONSE_INVALID_TABLE = 1
  integer, parameter, public :: CROP_CO2_RESPONSE_INVALID_FORCING = 2
  integer, parameter, public :: CROP_CO2_RESPONSE_INVALID_RESULT = 3

  type, public :: crop_co2_response_parameters_t
    private
    logical :: initialized = .false.
    type(wofost_rate_table_t) :: efficiency_by_co2
    type(wofost_rate_table_t) :: amax_by_co2
    type(wofost_rate_table_t) :: transpiration_by_co2
  contains
    procedure, public :: ready => crop_co2_response_parameters_ready
  end type crop_co2_response_parameters_t

  type, public :: crop_co2_response_t
    real(real64) :: atmospheric_co2_ppm = 0.0_real64
    real(real64) :: efficiency_factor = 1.0_real64
    real(real64) :: amax_factor = 1.0_real64
    real(real64) :: transpiration_factor = 1.0_real64
  end type crop_co2_response_t

  public :: construct_crop_co2_response_parameters
  public :: evaluate_crop_co2_response

contains

  subroutine construct_crop_co2_response_parameters(co2_ppm, efficiency_factor, amax_factor, transpiration_factor, &
                                                     parameters, status)
    real(real64), intent(in) :: co2_ppm(:), efficiency_factor(:), amax_factor(:), transpiration_factor(:)
    type(crop_co2_response_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    integer :: table_status

    parameters = crop_co2_response_parameters_t()
    status = CROP_CO2_RESPONSE_INVALID_TABLE
    if (size(co2_ppm) < 1) return
    if (size(efficiency_factor) /= size(co2_ppm) .or. size(amax_factor) /= size(co2_ppm) .or. &
        size(transpiration_factor) /= size(co2_ppm)) return
    if (.not. all(ieee_is_finite(co2_ppm)) .or. any(co2_ppm <= 0.0_real64)) return
    if (.not. all(ieee_is_finite(efficiency_factor)) .or. any(efficiency_factor < 0.0_real64)) return
    if (.not. all(ieee_is_finite(amax_factor)) .or. any(amax_factor < 0.0_real64)) return
    if (.not. all(ieee_is_finite(transpiration_factor)) .or. any(transpiration_factor < 0.0_real64)) return

    call construct_wofost_rate_table(co2_ppm, efficiency_factor, parameters%efficiency_by_co2, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) return
    call construct_wofost_rate_table(co2_ppm, amax_factor, parameters%amax_by_co2, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) return
    call construct_wofost_rate_table(co2_ppm, transpiration_factor, parameters%transpiration_by_co2, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) return

    parameters%initialized = .true.
    status = CROP_CO2_RESPONSE_OK
  end subroutine construct_crop_co2_response_parameters

  logical function crop_co2_response_parameters_ready(self) result(ready)
    class(crop_co2_response_parameters_t), intent(in) :: self
    ready = self%initialized .and. self%efficiency_by_co2%ready() .and. self%amax_by_co2%ready() .and. &
            self%transpiration_by_co2%ready()
  end function crop_co2_response_parameters_ready

  subroutine evaluate_crop_co2_response(parameters, atmospheric_co2_ppm, response, status)
    type(crop_co2_response_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: atmospheric_co2_ppm
    type(crop_co2_response_t), intent(out) :: response
    integer, intent(out) :: status
    integer :: table_status

    response = crop_co2_response_t()
    status = CROP_CO2_RESPONSE_INVALID_TABLE
    if (.not. parameters%ready()) return
    status = CROP_CO2_RESPONSE_INVALID_FORCING
    if (.not. ieee_is_finite(atmospheric_co2_ppm) .or. atmospheric_co2_ppm <= 0.0_real64) return

    response%atmospheric_co2_ppm = atmospheric_co2_ppm
    call parameters%efficiency_by_co2%evaluate(atmospheric_co2_ppm, response%efficiency_factor, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) then
      status = CROP_CO2_RESPONSE_INVALID_RESULT
      return
    end if
    call parameters%amax_by_co2%evaluate(atmospheric_co2_ppm, response%amax_factor, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) then
      status = CROP_CO2_RESPONSE_INVALID_RESULT
      return
    end if
    call parameters%transpiration_by_co2%evaluate(atmospheric_co2_ppm, response%transpiration_factor, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) then
      status = CROP_CO2_RESPONSE_INVALID_RESULT
      return
    end if
    if (.not. ieee_is_finite(response%efficiency_factor) .or. response%efficiency_factor < 0.0_real64 .or. &
        .not. ieee_is_finite(response%amax_factor) .or. response%amax_factor < 0.0_real64 .or. &
        .not. ieee_is_finite(response%transpiration_factor) .or. response%transpiration_factor < 0.0_real64) then
      response = crop_co2_response_t()
      status = CROP_CO2_RESPONSE_INVALID_RESULT
      return
    end if
    status = CROP_CO2_RESPONSE_OK
  end subroutine evaluate_crop_co2_response

end module mod_crop_co2_response_resolver
