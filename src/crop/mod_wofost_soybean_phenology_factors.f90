module mod_wofost_soybean_phenology_factors
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SOY_PHENOLOGY_OK = 0
  integer, parameter, public :: SOY_PHENOLOGY_INVALID_PARAMETERS = 1
  integer, parameter, public :: SOY_PHENOLOGY_INVALID_FORCING = 2
  integer, parameter, public :: SOY_PHENOLOGY_INVALID_RESULT = 3

  real(real64), parameter :: PI = 3.141592653589793238462643383279502884197_real64
  real(real64), parameter :: RADIAL = PI / 180.0_real64

  type, public :: soybean_phenology_parameters_t
    real(real64) :: maturity_group = 0.0_real64                  ! MG
    real(real64) :: maximum_vegetative_development_rate = 0.0_real64 ! DVRMAX1
    real(real64) :: maximum_generative_development_rate = 0.0_real64 ! DVRMAX2
    real(real64) :: minimum_development_temperature_c = 0.0_real64 ! TMINDVR
    real(real64) :: optimum_development_temperature_c = 0.0_real64 ! TOPTDVR
    real(real64) :: maximum_development_temperature_c = 0.0_real64 ! TMAXDVR
    logical :: apply_photoperiod_in_vegetative_phase = .true.      ! SWRFPHOTOVEG=1
    logical :: derive_photoperiod_from_maturity_group = .true.    ! SWPHENODAYL=0
    real(real64) :: optimum_photoperiod_hours = 0.0_real64        ! POPT
    real(real64) :: critical_photoperiod_hours = 0.0_real64       ! PCRT
  contains
    procedure, public :: ready => soybean_phenology_parameters_ready
    procedure, public :: resolved_photoperiod_bounds
  end type soybean_phenology_parameters_t

  public :: soybean_temperature_reduction_factor
  public :: soybean_photoperiod_reduction_factor
  public :: soybean_astronomic_daylength_hours
  public :: soybean_daily_development_rate

contains

  logical function soybean_phenology_parameters_ready(self) result(ready)
    class(soybean_phenology_parameters_t), intent(in) :: self
    real(real64) :: popt, pcrt

    ready = .false.
    if (.not. ieee_is_finite(self%maturity_group) .or. self%maturity_group < 0.1_real64 .or. &
        self%maturity_group > 9.0_real64) return
    if (.not. ieee_is_finite(self%maximum_vegetative_development_rate) .or. &
        self%maximum_vegetative_development_rate < 0.0_real64 .or. &
        self%maximum_vegetative_development_rate > 1.0_real64) return
    if (.not. ieee_is_finite(self%maximum_generative_development_rate) .or. &
        self%maximum_generative_development_rate < 0.0_real64 .or. &
        self%maximum_generative_development_rate > 1.0_real64) return
    if (.not. ieee_is_finite(self%minimum_development_temperature_c) .or. &
        .not. ieee_is_finite(self%optimum_development_temperature_c) .or. &
        .not. ieee_is_finite(self%maximum_development_temperature_c)) return
    if (self%minimum_development_temperature_c < 0.0_real64) return
    if (self%maximum_development_temperature_c > 45.0_real64) return
    if (self%optimum_development_temperature_c <= self%minimum_development_temperature_c .or. &
        self%optimum_development_temperature_c >= self%maximum_development_temperature_c) return
    call self%resolved_photoperiod_bounds(popt, pcrt)
    if (.not. ieee_is_finite(popt) .or. .not. ieee_is_finite(pcrt)) return
    ! PCRT may legitimately exceed 24 h when derived from maturity group; it
    ! is a response threshold, not an astronomical daylength observation.
    if (popt < 0.0_real64 .or. pcrt <= popt) return
    ready = .true.
  end function soybean_phenology_parameters_ready

  subroutine resolved_photoperiod_bounds(self, popt, pcrt)
    class(soybean_phenology_parameters_t), intent(in) :: self
    real(real64), intent(out) :: popt, pcrt

    if (self%derive_photoperiod_from_maturity_group) then
      ! B1.11 rfmgphotop(), SWPHENODAYL=0.
      popt = 12.759_real64 - 0.388_real64*self%maturity_group - 0.058_real64*self%maturity_group**2
      pcrt = 27.275_real64 - 0.493_real64*self%maturity_group - 0.066_real64*self%maturity_group**2
    else
      popt = self%optimum_photoperiod_hours
      pcrt = self%critical_photoperiod_hours
    end if
  end subroutine resolved_photoperiod_bounds

  subroutine soybean_temperature_reduction_factor(parameters, average_temperature_c, factor, status)
    type(soybean_phenology_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: average_temperature_c
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    real(real64) :: alpha, p1, p2, p3, p4
    real(real64) :: tmin, topt, tmax

    factor = 0.0_real64
    status = SOY_PHENOLOGY_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    status = SOY_PHENOLOGY_INVALID_FORCING
    if (.not. ieee_is_finite(average_temperature_c)) return

    tmin = parameters%minimum_development_temperature_c
    topt = parameters%optimum_development_temperature_c
    tmax = parameters%maximum_development_temperature_c

    ! Literal B1.11 rfmgtemp().
    if (average_temperature_c < tmin .or. average_temperature_c > tmax) then
      factor = 0.0_real64
    else
      alpha = log(2.0_real64) / log((tmax - tmin) / (topt - tmin))
      p1 = 2.0_real64 * (average_temperature_c - tmin)**alpha
      p2 = (topt - tmin)**alpha
      p3 = (average_temperature_c - tmin)**(2.0_real64*alpha)
      p4 = (topt - tmin)**(2.0_real64*alpha)
      factor = (p1*p2 - p3) / p4
    end if

    if (.not. ieee_is_finite(factor)) then
      factor = 0.0_real64
      status = SOY_PHENOLOGY_INVALID_RESULT
      return
    end if
    status = SOY_PHENOLOGY_OK
  end subroutine soybean_temperature_reduction_factor

  subroutine soybean_astronomic_daylength_hours(latitude_degrees, day_of_year, daylength_hours, status)
    real(real64), intent(in) :: latitude_degrees
    integer, intent(in) :: day_of_year
    real(real64), intent(out) :: daylength_hours
    integer, intent(out) :: status

    real(real64) :: dec, sinld, cosld, aob

    daylength_hours = 0.0_real64
    status = SOY_PHENOLOGY_INVALID_FORCING
    if (.not. ieee_is_finite(latitude_degrees) .or. abs(latitude_degrees) > 90.0_real64) return
    if (day_of_year < 1 .or. day_of_year > 366) return

    ! Literal B1.11 rfmgphotop astronomical daylength.
    dec = -asin(sin(23.45_real64*RADIAL) * cos(2.0_real64*PI*real(day_of_year+10,real64)/365.0_real64))
    sinld = sin(RADIAL*latitude_degrees) * sin(dec)
    cosld = cos(RADIAL*latitude_degrees) * cos(dec)
    if (abs(cosld) <= tiny(1.0_real64)) then
      aob = sign(huge(1.0_real64), sinld)
    else
      aob = sinld / cosld
    end if
    if (abs(aob) <= 1.0_real64) then
      daylength_hours = 12.0_real64 * (1.0_real64 + 2.0_real64*asin(aob)/PI)
    else if (aob > 1.0_real64) then
      daylength_hours = 24.0_real64
    else
      daylength_hours = 0.0_real64
    end if
    if (.not. ieee_is_finite(daylength_hours)) then
      daylength_hours = 0.0_real64
      status = SOY_PHENOLOGY_INVALID_RESULT
      return
    end if
    status = SOY_PHENOLOGY_OK
  end subroutine soybean_astronomic_daylength_hours

  subroutine soybean_photoperiod_reduction_factor(parameters, latitude_degrees, day_of_year, factor, &
                                                   daylength_hours, status)
    type(soybean_phenology_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: latitude_degrees
    integer, intent(in) :: day_of_year
    real(real64), intent(out) :: factor
    real(real64), intent(out) :: daylength_hours
    integer, intent(out) :: status

    real(real64) :: alpha, p0, p1, p2, popt, pcrt
    integer :: local_status

    factor = 0.0_real64
    daylength_hours = 0.0_real64
    status = SOY_PHENOLOGY_INVALID_PARAMETERS
    if (.not. parameters%ready()) return

    call soybean_astronomic_daylength_hours(latitude_degrees, day_of_year, daylength_hours, local_status)
    if (local_status /= SOY_PHENOLOGY_OK) then
      status = local_status
      return
    end if
    call parameters%resolved_photoperiod_bounds(popt, pcrt)

    ! Literal B1.11 rfmgphotop().
    if (daylength_hours < popt) then
      factor = 1.0_real64
    else if (daylength_hours > pcrt) then
      factor = 0.0_real64
    else
      alpha = log(2.0_real64) / log(((pcrt-popt)/3.0_real64)+1.0_real64)
      p0 = (pcrt-popt)/3.0_real64
      p1 = (daylength_hours-popt)/3.0_real64 + 1.0_real64
      p2 = (pcrt-daylength_hours)/(pcrt-popt)
      factor = (p1*(p2**p0))**alpha
    end if

    if (.not. ieee_is_finite(factor)) then
      factor = 0.0_real64
      status = SOY_PHENOLOGY_INVALID_RESULT
      return
    end if
    status = SOY_PHENOLOGY_OK
  end subroutine soybean_photoperiod_reduction_factor

  subroutine soybean_daily_development_rate(parameters, development_stage, average_temperature_c, &
                                             latitude_degrees, day_of_year, anthesis_reached, &
                                             temperature_sum_increment, development_rate, &
                                             candidate_anthesis_reached, anthesis_triggered, status)
    type(soybean_phenology_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: development_stage, average_temperature_c, latitude_degrees
    integer, intent(in) :: day_of_year
    logical, intent(in) :: anthesis_reached
    real(real64), intent(out) :: temperature_sum_increment, development_rate
    logical, intent(out) :: candidate_anthesis_reached, anthesis_triggered
    integer, intent(out) :: status

    real(real64) :: ftemp, fphoto, daylength_hours
    integer :: local_status

    temperature_sum_increment = 0.0_real64
    development_rate = 0.0_real64
    candidate_anthesis_reached = anthesis_reached
    anthesis_triggered = .false.
    status = SOY_PHENOLOGY_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    status = SOY_PHENOLOGY_INVALID_FORCING
    if (.not. ieee_is_finite(development_stage) .or. development_stage < 0.0_real64) return
    if (.not. ieee_is_finite(average_temperature_c)) return

    ! B1.11 update_dvs_rate, SWWOFOST=2.
    temperature_sum_increment = max(0.0_real64, average_temperature_c)

    call soybean_temperature_reduction_factor(parameters, average_temperature_c, ftemp, local_status)
    if (local_status /= SOY_PHENOLOGY_OK) then
      status = local_status
      return
    end if
    call soybean_photoperiod_reduction_factor(parameters, latitude_degrees, day_of_year, &
         fphoto, daylength_hours, local_status)
    if (local_status /= SOY_PHENOLOGY_OK) then
      status = local_status
      return
    end if

    if (development_stage < 1.0_real64) then
      development_rate = parameters%maximum_vegetative_development_rate * ftemp
      if (parameters%apply_photoperiod_in_vegetative_phase) development_rate = development_rate * fphoto
    else
      development_rate = parameters%maximum_generative_development_rate * fphoto * ftemp
    end if

    ! Exact B1.11 anthesis crossing rule shared by SWWOFOST=1/2.
    if (development_stage + development_rate >= 1.0_real64 .and. .not. anthesis_reached) then
      candidate_anthesis_reached = .true.
      anthesis_triggered = .true.
      development_rate = 1.0_real64 - development_stage
    end if

    if (.not. ieee_is_finite(development_rate) .or. development_rate < 0.0_real64) then
      development_rate = 0.0_real64
      status = SOY_PHENOLOGY_INVALID_RESULT
      return
    end if
    status = SOY_PHENOLOGY_OK
  end subroutine soybean_daily_development_rate

end module mod_wofost_soybean_phenology_factors
