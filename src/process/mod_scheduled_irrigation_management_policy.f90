module mod_scheduled_irrigation_management_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_MGMT_OK = 0
  integer, parameter, public :: IRR_MGMT_INVALID_PARAMETERS = 1
  integer, parameter, public :: IRR_MGMT_INVALID_REQUEST = 2
  integer, parameter, public :: IRR_MGMT_MAX_KNOTS = 7

  type, public :: irrigation_management_policy_parameters_t
    integer :: timing_criterion = 2
    integer :: depth_criterion = 1
    integer :: tcs2_knot_count = 0
    real(real64) :: tcs2_dvs(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: tcs2_fraction(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    integer :: tcs3_knot_count = 0
    real(real64) :: tcs3_dvs(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: tcs3_fraction(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    integer :: tcs4_knot_count = 0
    real(real64) :: tcs4_dvs(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: tcs4_depletion_mm(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: tcs6_threshold_mm = 0.0_real64
    integer :: dcs1_knot_count = 0
    real(real64) :: dcs1_dvs(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: dcs1_adjustment_mm(IRR_MGMT_MAX_KNOTS) = 0.0_real64
    real(real64) :: rainfall_threshold_cm = 0.0_real64
    logical :: depth_limit_enabled = .false.
    real(real64) :: minimum_depth_cm = 0.0_real64
    real(real64) :: maximum_depth_cm = huge(0.0_real64)
    logical :: salinity_excess_enabled = .false.
    real(real64) :: salinity_threshold = 0.0_real64
    real(real64) :: salinity_excess_percent = 0.0_real64
  end type irrigation_management_policy_parameters_t

  type, public :: irrigation_management_policy_state_t
    integer :: weekly_day_counter = 366
  end type irrigation_management_policy_state_t

  type, public :: irrigation_management_policy_request_t
    real(real64) :: dvs = 0.0_real64
    real(real64) :: total_available_water_cm = 0.0_real64
    real(real64) :: stress_to_wilting_available_cm = 0.0_real64
    real(real64) :: actual_available_water_cm = 0.0_real64
    real(real64) :: field_capacity_deficit_cm = 0.0_real64
    real(real64) :: rainfall_cm = 0.0_real64
    logical :: solute_enabled = .false.
    real(real64) :: sensor_concentration = 0.0_real64
  end type irrigation_management_policy_request_t

  type, public :: irrigation_management_policy_result_t
    logical :: trigger = .false.
    real(real64) :: timing_threshold = 0.0_real64
    real(real64) :: selected_depth_cm = 0.0_real64
    logical :: weekly_opportunity = .false.
    logical :: rainfall_deducted = .false.
    logical :: depth_limited = .false.
    logical :: salinity_excess_applied = .false.
  end type irrigation_management_policy_result_t

  public :: evaluate_irrigation_management_policy

contains

  pure subroutine evaluate_irrigation_management_policy(parameters, committed_state, request, &
                                                          candidate_state, result, status)
    type(irrigation_management_policy_parameters_t), intent(in) :: parameters
    type(irrigation_management_policy_state_t), intent(in) :: committed_state
    type(irrigation_management_policy_request_t), intent(in) :: request
    type(irrigation_management_policy_state_t), intent(out) :: candidate_state
    type(irrigation_management_policy_result_t), intent(out) :: result
    integer, intent(out) :: status
    real(real64) :: threshold, depletion, adjustment, rain_reduction
    logical :: ok

    candidate_state = committed_state
    result = irrigation_management_policy_result_t()
    status = IRR_MGMT_OK
    if (.not. valid_request(request) .or. committed_state%weekly_day_counter < 0) then
      status = IRR_MGMT_INVALID_REQUEST
      return
    end if
    if (.not. valid_parameters(parameters)) then
      status = IRR_MGMT_INVALID_PARAMETERS
      return
    end if

    select case (parameters%timing_criterion)
    case (2)
      call afgen(parameters%tcs2_dvs, parameters%tcs2_fraction, parameters%tcs2_knot_count, request%dvs, threshold, ok)
      if (.not. ok) then; status=IRR_MGMT_INVALID_PARAMETERS; return; end if
      result%timing_threshold = threshold
      depletion = threshold * (request%total_available_water_cm-request%stress_to_wilting_available_cm)
      if (depletion > request%total_available_water_cm) depletion = request%total_available_water_cm
      result%trigger = request%actual_available_water_cm <= request%total_available_water_cm-depletion
    case (3)
      call afgen(parameters%tcs3_dvs, parameters%tcs3_fraction, parameters%tcs3_knot_count, request%dvs, threshold, ok)
      if (.not. ok) then; status=IRR_MGMT_INVALID_PARAMETERS; return; end if
      result%timing_threshold = threshold
      depletion = threshold * request%total_available_water_cm
      result%trigger = request%actual_available_water_cm <= request%total_available_water_cm-depletion
    case (4)
      call afgen(parameters%tcs4_dvs, parameters%tcs4_depletion_mm, parameters%tcs4_knot_count, request%dvs, threshold, ok)
      if (.not. ok) then; status=IRR_MGMT_INVALID_PARAMETERS; return; end if
      result%timing_threshold = threshold
      result%trigger = request%total_available_water_cm-request%actual_available_water_cm >= 0.1_real64*threshold
    case (6)
      candidate_state%weekly_day_counter = committed_state%weekly_day_counter + 1
      if (candidate_state%weekly_day_counter >= 7) then
        candidate_state%weekly_day_counter = 0
        result%weekly_opportunity = .true.
        result%timing_threshold = parameters%tcs6_threshold_mm
        result%trigger = 10.0_real64*request%field_capacity_deficit_cm > parameters%tcs6_threshold_mm
      end if
    case default
      status = IRR_MGMT_INVALID_PARAMETERS
      return
    end select

    if (.not. result%trigger) return

    select case (parameters%depth_criterion)
    case (1)
      call afgen(parameters%dcs1_dvs, parameters%dcs1_adjustment_mm, parameters%dcs1_knot_count, request%dvs, adjustment, ok)
      if (.not. ok) then; status=IRR_MGMT_INVALID_PARAMETERS; return; end if
      rain_reduction = 0.0_real64
      if (request%rainfall_cm > parameters%rainfall_threshold_cm) then
        rain_reduction = request%rainfall_cm
        result%rainfall_deducted = .true.
      end if
      result%selected_depth_cm = max(0.0_real64, request%field_capacity_deficit_cm + 0.1_real64*adjustment-rain_reduction)
    case default
      status = IRR_MGMT_INVALID_PARAMETERS
      return
    end select

    if (parameters%depth_limit_enabled) then
      if (result%selected_depth_cm < parameters%minimum_depth_cm .or. result%selected_depth_cm > parameters%maximum_depth_cm) &
        result%depth_limited = .true.
      result%selected_depth_cm = max(result%selected_depth_cm, parameters%minimum_depth_cm)
      result%selected_depth_cm = min(result%selected_depth_cm, parameters%maximum_depth_cm)
    end if

    if (parameters%salinity_excess_enabled .and. request%solute_enabled .and. &
        request%sensor_concentration > parameters%salinity_threshold) then
      result%selected_depth_cm = result%selected_depth_cm*(1.0_real64+0.01_real64*parameters%salinity_excess_percent)
      result%salinity_excess_applied = .true.
    end if
  end subroutine evaluate_irrigation_management_policy

  pure logical function valid_request(request)
    type(irrigation_management_policy_request_t), intent(in) :: request
    valid_request = ieee_is_finite(request%dvs) .and. ieee_is_finite(request%total_available_water_cm) .and. &
      ieee_is_finite(request%stress_to_wilting_available_cm) .and. ieee_is_finite(request%actual_available_water_cm) .and. &
      ieee_is_finite(request%field_capacity_deficit_cm) .and. ieee_is_finite(request%rainfall_cm) .and. &
      ieee_is_finite(request%sensor_concentration) .and. request%total_available_water_cm >= 0.0_real64 .and. &
      request%stress_to_wilting_available_cm >= 0.0_real64 .and. request%rainfall_cm >= 0.0_real64
  end function valid_request

  pure logical function valid_parameters(parameters)
    type(irrigation_management_policy_parameters_t), intent(in) :: parameters
    valid_parameters = .false.
    select case(parameters%timing_criterion)
    case(2)
      if (.not. valid_table(parameters%tcs2_dvs,parameters%tcs2_fraction,parameters%tcs2_knot_count)) return
      if (any(parameters%tcs2_fraction(1:parameters%tcs2_knot_count)<0.0_real64) .or. &
          any(parameters%tcs2_fraction(1:parameters%tcs2_knot_count)>1.0_real64)) return
    case(3)
      if (.not. valid_table(parameters%tcs3_dvs,parameters%tcs3_fraction,parameters%tcs3_knot_count)) return
      if (any(parameters%tcs3_fraction(1:parameters%tcs3_knot_count)<0.0_real64) .or. &
          any(parameters%tcs3_fraction(1:parameters%tcs3_knot_count)>1.0_real64)) return
    case(4)
      if (.not. valid_table(parameters%tcs4_dvs,parameters%tcs4_depletion_mm,parameters%tcs4_knot_count)) return
      if (any(parameters%tcs4_depletion_mm(1:parameters%tcs4_knot_count)<0.0_real64) .or. &
          any(parameters%tcs4_depletion_mm(1:parameters%tcs4_knot_count)>500.0_real64)) return
    case(6)
      if (.not. ieee_is_finite(parameters%tcs6_threshold_mm) .or. parameters%tcs6_threshold_mm<0.0_real64 .or. &
          parameters%tcs6_threshold_mm>20.0_real64) return
    case default
      return
    end select
    if (parameters%depth_criterion /= 1) return
    if (.not. valid_table(parameters%dcs1_dvs,parameters%dcs1_adjustment_mm,parameters%dcs1_knot_count)) return
    if (any(parameters%dcs1_adjustment_mm(1:parameters%dcs1_knot_count)<-100.0_real64) .or. &
        any(parameters%dcs1_adjustment_mm(1:parameters%dcs1_knot_count)>100.0_real64)) return
    if (.not. ieee_is_finite(parameters%rainfall_threshold_cm) .or. parameters%rainfall_threshold_cm<0.0_real64 .or. &
        parameters%rainfall_threshold_cm>1000.0_real64) return
    if (parameters%depth_limit_enabled) then
      if (.not. ieee_is_finite(parameters%minimum_depth_cm) .or. .not. ieee_is_finite(parameters%maximum_depth_cm)) return
      if (parameters%minimum_depth_cm<0.0_real64 .or. parameters%minimum_depth_cm>10.0_real64 .or. &
          parameters%maximum_depth_cm<parameters%minimum_depth_cm .or. parameters%maximum_depth_cm>1.0e6_real64) return
    end if
    if (parameters%salinity_excess_enabled) then
      if (.not. ieee_is_finite(parameters%salinity_threshold) .or. parameters%salinity_threshold<0.0_real64 .or. &
          parameters%salinity_threshold>100.0_real64) return
      if (.not. ieee_is_finite(parameters%salinity_excess_percent) .or. parameters%salinity_excess_percent<0.0_real64 .or. &
          parameters%salinity_excess_percent>100.0_real64) return
    end if
    valid_parameters=.true.
  end function valid_parameters

  pure logical function valid_table(knots,values,n)
    real(real64), intent(in) :: knots(IRR_MGMT_MAX_KNOTS),values(IRR_MGMT_MAX_KNOTS)
    integer,intent(in)::n
    integer::i
    valid_table=.false.
    if(n<2 .or. n>IRR_MGMT_MAX_KNOTS)return
    do i=1,n
      if(.not.ieee_is_finite(knots(i)) .or. .not.ieee_is_finite(values(i)))return
      if(knots(i)<0.0_real64 .or. knots(i)>2.0_real64)return
    end do
    do i=2,n
      if(knots(i)<=knots(i-1))return
    end do
    valid_table=.true.
  end function valid_table

  pure subroutine afgen(knots,values,n,x,value,ok)
    real(real64),intent(in)::knots(IRR_MGMT_MAX_KNOTS),values(IRR_MGMT_MAX_KNOTS),x
    integer,intent(in)::n
    real(real64),intent(out)::value
    logical,intent(out)::ok
    integer::i
    real(real64)::f
    value=0.0_real64; ok=.false.
    if(.not.ieee_is_finite(x) .or. .not.valid_table(knots,values,n))return
    if(x<=knots(1))then; value=values(1); ok=.true.; return; end if
    if(x>=knots(n))then; value=values(n); ok=.true.; return; end if
    do i=2,n
      if(x<=knots(i))then
        f=(x-knots(i-1))/(knots(i)-knots(i-1)); value=values(i-1)+f*(values(i)-values(i-1)); ok=.true.; return
      end if
    end do
  end subroutine afgen
end module mod_scheduled_irrigation_management_policy
