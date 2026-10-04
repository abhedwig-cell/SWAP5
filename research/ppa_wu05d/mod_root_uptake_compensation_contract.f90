module mod_root_uptake_compensation_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ROOT_COMPENSATION_OK = 0
  integer, parameter, public :: ROOT_COMPENSATION_INVALID_INPUT = 1
  integer, parameter, public :: ROOT_COMPENSATION_INVALID_SHAPE = 2

  integer, parameter, public :: ROOT_COMPENSATION_JARVIS = 1
  integer, parameter, public :: ROOT_COMPENSATION_WALSUM = 2

  integer, parameter, public :: ROOT_COMPENSATION_ALL_STRESSORS = 1
  integer, parameter, public :: ROOT_COMPENSATION_DROUGHT = 2
  integer, parameter, public :: ROOT_COMPENSATION_OXYGEN = 3
  integer, parameter, public :: ROOT_COMPENSATION_SALINITY = 4
  integer, parameter, public :: ROOT_COMPENSATION_FROST = 5

  type, public :: root_compensation_request_t
    integer :: compensation_method = ROOT_COMPENSATION_JARVIS
    real(real64) :: potential_transpiration = 0.0_real64
    real(real64) :: alpha_critical = 1.0_real64
    integer :: selected_stressor = ROOT_COMPENSATION_ALL_STRESSORS
    real(real64) :: drought_reduction_total = 0.0_real64
    real(real64) :: oxygen_reduction_total = 0.0_real64
    real(real64) :: salinity_reduction_total = 0.0_real64
    real(real64) :: frost_reduction_total = 0.0_real64
    real(real64) :: configured_root_depth = 0.0_real64
    real(real64) :: actual_root_zone_depth = 0.0_real64
    real(real64) :: critical_root_zone_depth = 0.0_real64
  end type root_compensation_request_t

  type, public :: root_compensation_result_t
    real(real64), allocatable :: root_extraction_sink(:)
    real(real64) :: actual_uptake_total = 0.0_real64
    real(real64) :: drought_reduction_total = 0.0_real64
    real(real64) :: oxygen_reduction_total = 0.0_real64
    real(real64) :: salinity_reduction_total = 0.0_real64
    real(real64) :: frost_reduction_total = 0.0_real64
    logical :: applied = .false.
  end type root_compensation_result_t

  public :: evaluate_root_compensation_candidate

contains

  subroutine evaluate_root_compensation_candidate(base_sink, request, result, status)
    real(real64), intent(in) :: base_sink(:)
    type(root_compensation_request_t), intent(in) :: request
    type(root_compensation_result_t), intent(out) :: result
    integer, intent(out) :: status

    real(real64), parameter :: vsmall = 1.0e-14_real64
    real(real64) :: alptot, alptotcom, qred, redtot
    real(real64) :: alpdry, alpwet, alpsol, alpfrs, alpha_critical
    real(real64) :: alpdrycom, alpwetcom, alpsolcom, alpfrscom

    result = root_compensation_result_t()
    status = ROOT_COMPENSATION_OK

    if (.not. valid_request(base_sink, request)) then
      status = ROOT_COMPENSATION_INVALID_INPUT
      return
    end if

    allocate(result%root_extraction_sink(size(base_sink)))
    result%root_extraction_sink = base_sink
    result%actual_uptake_total = sum(base_sink)
    result%drought_reduction_total = request%drought_reduction_total
    result%oxygen_reduction_total = request%oxygen_reduction_total
    result%salinity_reduction_total = request%salinity_reduction_total
    result%frost_reduction_total = request%frost_reduction_total

    if (request%potential_transpiration <= vsmall) return

    alpha_critical = request%alpha_critical
    if (request%compensation_method == ROOT_COMPENSATION_WALSUM) then
      alpha_critical = min((request%critical_root_zone_depth + request%configured_root_depth - &
           request%actual_root_zone_depth) / request%configured_root_depth, 1.0_real64)
    end if

    alptot = result%actual_uptake_total / request%potential_transpiration
    qred = request%potential_transpiration - result%actual_uptake_total

    if (abs(alpha_critical - 1.0_real64) < vsmall) return
    if (qred <= vsmall .or. alptot < 0.05_real64) return

    alpdry = alptot**(request%drought_reduction_total / qred)
    alpwet = alptot**(request%oxygen_reduction_total / qred)
    alpsol = alptot**(request%salinity_reduction_total / qred)
    alpfrs = alptot**(request%frost_reduction_total / qred)

    alpdrycom = alpdry
    alpwetcom = alpwet
    alpsolcom = alpsol
    alpfrscom = alpfrs

    if (request%selected_stressor == ROOT_COMPENSATION_ALL_STRESSORS) then
      alptotcom = min(alptot / alpha_critical, 1.0_real64)
    else
      select case (request%selected_stressor)
      case (ROOT_COMPENSATION_DROUGHT)
        alpdrycom = min(alpdry / alpha_critical, 1.0_real64)
      case (ROOT_COMPENSATION_OXYGEN)
        alpwetcom = min(alpwet / alpha_critical, 1.0_real64)
      case (ROOT_COMPENSATION_SALINITY)
        alpsolcom = min(alpsol / alpha_critical, 1.0_real64)
      case (ROOT_COMPENSATION_FROST)
        alpfrscom = min(alpfrs / alpha_critical, 1.0_real64)
      end select
      alptotcom = alpwetcom * alpdrycom * alpsolcom * alpfrscom
    end if

    result%root_extraction_sink = base_sink * alptotcom / alptot
    result%actual_uptake_total = request%potential_transpiration * alptotcom
    qred = request%potential_transpiration - result%actual_uptake_total
    result%applied = .true.

    if (qred < vsmall) then
      result%drought_reduction_total = 0.0_real64
      result%oxygen_reduction_total = 0.0_real64
      result%salinity_reduction_total = 0.0_real64
      result%frost_reduction_total = 0.0_real64
    else
      redtot = (1.0_real64-alpwetcom) + (1.0_real64-alpdrycom) + &
               (1.0_real64-alpsolcom) + (1.0_real64-alpfrscom)
      result%oxygen_reduction_total = (1.0_real64-alpwetcom) / redtot * qred
      result%drought_reduction_total = (1.0_real64-alpdrycom) / redtot * qred
      result%salinity_reduction_total = (1.0_real64-alpsolcom) / redtot * qred
      result%frost_reduction_total = (1.0_real64-alpfrscom) / redtot * qred
    end if
  end subroutine evaluate_root_compensation_candidate

  pure logical function valid_request(base_sink, request) result(valid)
    real(real64), intent(in) :: base_sink(:)
    type(root_compensation_request_t), intent(in) :: request

    valid = .false.
    if (size(base_sink) <= 0) return
    if (any(.not. ieee_is_finite(base_sink)) .or. any(base_sink < 0.0_real64)) return
    if (request%compensation_method /= ROOT_COMPENSATION_JARVIS .and. request%compensation_method /= ROOT_COMPENSATION_WALSUM) return
    if (.not. ieee_is_finite(request%potential_transpiration) .or. request%potential_transpiration < 0.0_real64) return
    if (.not. ieee_is_finite(request%alpha_critical) .or. request%alpha_critical <= 0.0_real64 .or. &
        request%alpha_critical > 1.0_real64) return
    if (request%compensation_method == ROOT_COMPENSATION_WALSUM) then
      if (.not. ieee_is_finite(request%configured_root_depth) .or. request%configured_root_depth <= 0.0_real64) return
      if (.not. ieee_is_finite(request%actual_root_zone_depth) .or. request%actual_root_zone_depth < 0.0_real64) return
      if (.not. ieee_is_finite(request%critical_root_zone_depth) .or. request%critical_root_zone_depth < 0.0_real64) return
    end if
    if (request%selected_stressor < ROOT_COMPENSATION_ALL_STRESSORS .or. &
        request%selected_stressor > ROOT_COMPENSATION_FROST) return
    if (.not. ieee_is_finite(request%drought_reduction_total) .or. request%drought_reduction_total < 0.0_real64) return
    if (.not. ieee_is_finite(request%oxygen_reduction_total) .or. request%oxygen_reduction_total < 0.0_real64) return
    if (.not. ieee_is_finite(request%salinity_reduction_total) .or. request%salinity_reduction_total < 0.0_real64) return
    if (.not. ieee_is_finite(request%frost_reduction_total) .or. request%frost_reduction_total < 0.0_real64) return
    if (sum(base_sink) > request%potential_transpiration + 256.0_real64*epsilon(1.0_real64)* &
        max(1.0_real64, request%potential_transpiration)) return
    valid = .true.
  end function valid_request

end module mod_root_uptake_compensation_contract
