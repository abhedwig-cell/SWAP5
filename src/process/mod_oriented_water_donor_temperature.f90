module mod_oriented_water_donor_temperature
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: OWDT_OK = 0
  integer, parameter, public :: OWDT_INVALID_TRANSFER = 1
  integer, parameter, public :: OWDT_DONOR_UNAVAILABLE = 2
  integer, parameter, public :: OWDT_INVALID_DONOR_TEMPERATURE = 3

  integer, parameter, public :: OWDT_NO_DONOR = 0
  integer, parameter, public :: OWDT_ENDPOINT_A = 1
  integer, parameter, public :: OWDT_ENDPOINT_B = 2

  type, public :: oriented_water_donor_temperature_result_t
    integer :: status = OWDT_INVALID_TRANSFER
    logical :: transport_present = .false.
    logical :: donor_temperature_available = .false.
    integer :: donor_endpoint = OWDT_NO_DONOR
    real(real64) :: oriented_water_amount_cm = 0.0_real64
    real(real64) :: donor_temperature_c = 0.0_real64
  end type oriented_water_donor_temperature_result_t

  public :: select_oriented_water_donor_temperature

contains

  subroutine select_oriented_water_donor_temperature(oriented_water_amount_cm, &
       endpoint_a_temperature_c, endpoint_a_available, endpoint_b_temperature_c, endpoint_b_available, result)
    real(real64), intent(in) :: oriented_water_amount_cm
    real(real64), intent(in) :: endpoint_a_temperature_c, endpoint_b_temperature_c
    logical, intent(in) :: endpoint_a_available, endpoint_b_available
    type(oriented_water_donor_temperature_result_t), intent(out) :: result

    result = oriented_water_donor_temperature_result_t()
    if (.not. ieee_is_finite(oriented_water_amount_cm)) return

    result%oriented_water_amount_cm = oriented_water_amount_cm

    ! Orientation contract:
    !   positive amount: endpoint A -> endpoint B, donor is A
    !   negative amount: endpoint B -> endpoint A, donor is B
    !   exact zero: no transported water and therefore no donor requirement
    if (oriented_water_amount_cm > 0.0_real64) then
      result%transport_present = .true.
      result%donor_endpoint = OWDT_ENDPOINT_A
      if (.not. endpoint_a_available) then
        result%status = OWDT_DONOR_UNAVAILABLE
        return
      end if
      if (.not. ieee_is_finite(endpoint_a_temperature_c)) then
        result%status = OWDT_INVALID_DONOR_TEMPERATURE
        return
      end if
      result%donor_temperature_c = endpoint_a_temperature_c
      result%donor_temperature_available = .true.
    else if (oriented_water_amount_cm < 0.0_real64) then
      result%transport_present = .true.
      result%donor_endpoint = OWDT_ENDPOINT_B
      if (.not. endpoint_b_available) then
        result%status = OWDT_DONOR_UNAVAILABLE
        return
      end if
      if (.not. ieee_is_finite(endpoint_b_temperature_c)) then
        result%status = OWDT_INVALID_DONOR_TEMPERATURE
        return
      end if
      result%donor_temperature_c = endpoint_b_temperature_c
      result%donor_temperature_available = .true.
    else
      result%status = OWDT_OK
      return
    end if

    result%status = OWDT_OK
  end subroutine select_oriented_water_donor_temperature

end module mod_oriented_water_donor_temperature
