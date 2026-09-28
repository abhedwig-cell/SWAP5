program test_ppa_irr_dcs1_application_composition
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_dcs1_depth
  use mod_ppa_irr_fixed_input_normalization, only: normalize_fixed_irrigation_input
  use mod_ppa_irr_rate_materialization, only: materialize_irrigation_rate, IRR_RATE_MATERIALIZATION_OK
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), parameter :: tolerance_scale = 128.0_real64
  real(real64) :: knots(IRR_DCS1_MAX_KNOTS), correction(IRR_DCS1_MAX_KNOTS)
  real(real64) :: dvs, deficit, rainfall, rain_threshold, minimum_mm, maximum_mm
  real(real64) :: concentration, concentration_threshold, overirrigation_percent
  real(real64) :: depth_cm, correction_mm, depth_mm, supplied_rate_mm_hour
  real(real64) :: normalized_depth_cm, normalized_rate_cm_day, normalized_duration
  real(real64) :: effective_rate, event_duration, rate_sum, offered_amount, expected_amount
  real(real64), allocatable :: node_rates(:)
  integer(int64) :: random_state
  integer :: i, status, application_type, node_count
  logical :: limit_enabled, solute_enabled, has_rate

  knots = [0.0_real64,0.25_real64,0.50_real64,0.75_real64,1.0_real64,1.5_real64,2.0_real64]
  correction = [-20.0_real64,-10.0_real64,0.0_real64,5.0_real64,10.0_real64,20.0_real64,30.0_real64]
  random_state = 20260923_int64

  do i = 1, vector_count
    call random_unit(random_state, dvs)
    dvs = 2.0_real64*dvs
    call random_unit(random_state, deficit)
    deficit = 4.1_real64 + 4.0_real64*deficit
    call random_unit(random_state, rainfall)
    rainfall = 2.0_real64*rainfall
    rain_threshold = 0.75_real64
    limit_enabled = modulo(i,2) == 0
    minimum_mm = 2.0_real64
    maximum_mm = 500.0_real64
    call random_unit(random_state, concentration)
    concentration = 100.0_real64*concentration
    concentration_threshold = 50.0_real64
    overirrigation_percent = 25.0_real64
    solute_enabled = modulo(i,3) == 0

    call evaluate_dcs1_depth(dvs, knots, correction, IRR_DCS1_MAX_KNOTS, deficit, rainfall, &
      rain_threshold, limit_enabled, minimum_mm, maximum_mm, solute_enabled, concentration, &
      concentration_threshold, overirrigation_percent, depth_cm, correction_mm, status)
    call require(status == IRR_DCS1_OK .and. depth_cm > 0.0_real64, 1)

    application_type = 1
    if (modulo(i,2) == 1) application_type = 2 ! B1 codes: 1 surface; 2 SSDI
    node_count = 1+modulo(i,7)
    depth_mm = 10.0_real64*depth_cm
    has_rate = modulo(i,4) /= 0
    supplied_rate_mm_hour = 0.25_real64+2.25_real64*real(modulo(i,997),real64)/996.0_real64
    if (.not. has_rate) supplied_rate_mm_hour = 0.0_real64
    call normalize_fixed_irrigation_input(depth_mm, supplied_rate_mm_hour, has_rate, application_type, &
      node_count, normalized_depth_cm, normalized_rate_cm_day, normalized_duration)
    call require(normalized_duration > 0.0_real64, 6)

    call materialize_irrigation_rate(normalized_depth_cm, normalized_rate_cm_day, application_type == 2, &
      node_count, effective_rate, event_duration, node_rates, rate_sum, status)
    call require(status == IRR_RATE_MATERIALIZATION_OK, 2)
    if (application_type == 2) then
      call require(allocated(node_rates), 3)
      call require(size(node_rates) == node_count, 3)
      offered_amount = rate_sum*event_duration
      deallocate(node_rates)
    else
      call require(.not. allocated(node_rates), 4)
      offered_amount = effective_rate*event_duration
    end if
    expected_amount = depth_cm
    if (abs(offered_amount-expected_amount) > tolerance_scale*epsilon(expected_amount)* &
        max(1.0_real64,expected_amount)) then
      write(*,'(A,I0,4(1X,ES24.16))') 'DCS1_APPLICATION_AMOUNT_DIAGNOSTIC=', i, depth_cm, &
        normalized_depth_cm, effective_rate, event_duration
      write(*,'(A,3(1X,ES24.16),1X,L1,1X,I0)') 'DCS1_APPLICATION_AMOUNT_DETAIL=', &
        offered_amount, expected_amount, normalized_rate_cm_day, has_rate, node_count
    end if
    call require(abs(offered_amount-expected_amount) <= tolerance_scale*epsilon(expected_amount)* &
                 max(1.0_real64,expected_amount), 5)
  end do

  print '(A)', 'PPA_IRR_DCS1_DEPTH_TO_SURFACE_AND_SSDI_APPLICATION_100000=PASS'
  print '(A)', 'PPA_IRR_DCS1_DEPTH_TO_APPLICATION_AMOUNT_CONSERVATION=PASS'
  print '(A)', 'PPA_IRR_DCS1_APPLICATION_COMPOSITION=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'PPA_IRR_DCS1_APPLICATION_COMPOSITION_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_dcs1_application_composition
