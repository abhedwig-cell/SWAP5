program test_ppa_wu05a11_rfm_unponded_activation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_unponded_activation
  implicit none

  real(real64), parameter :: tol = 5.0e-13_real64
  real(real64), parameter :: expected_b50 = 3.08724_real64
  real(real64), parameter :: expected_matrix = 3.1439554598512593_real64
  real(real64), parameter :: expected_pref = 1.6560445401487405_real64
  real(real64), parameter :: expected_fraction = 0.3450092791976543_real64
  real(real64), parameter :: rates(7) = [0.5_real64,1.0_real64,2.0_real64,4.0_real64, &
       8.0_real64,15.0_real64,30.0_real64]

  type(rfm_unponded_activation_request_t) :: req
  type(rfm_unponded_activation_result_t) :: res
  real(real64) :: previous_fraction
  integer :: i

  req%sigma_b = 0.65_real64
  req%matrix_conductivity_cm_per_day = 0.16264_real64
  req%surface_sorptivity_cm_sqrt_day = 2.92460_real64
  req%source_rate_cm_per_day = 4.8_real64
  req%event_age_day = 0.25_real64
  req%ponding_depth_cm = 0.0_real64

  call evaluate_rfm_unponded_activation(req,res)
  if (res%status /= RFM_ACTIVATION_AVAILABLE) error stop 'A11 oracle status'
  if (abs(res%b50_cm_per_day-expected_b50) > tol) error stop 'A11 oracle b50'
  if (abs(res%matrix_rate_cm_per_day-expected_matrix) > tol) error stop 'A11 oracle matrix'
  if (abs(res%preferential_rate_cm_per_day-expected_pref) > tol) error stop 'A11 oracle preferential'
  if (abs(res%preferential_fraction-expected_fraction) > tol) error stop 'A11 oracle fraction'
  call assert_partition(req,res)

  req%source_rate_cm_per_day = 0.0_real64
  call evaluate_rfm_unponded_activation(req,res)
  if (res%status /= RFM_ACTIVATION_AVAILABLE) error stop 'A11 zero source status'
  if (abs(res%matrix_rate_cm_per_day)+abs(res%preferential_rate_cm_per_day) > tol) &
       error stop 'A11 zero source identity'

  req%source_rate_cm_per_day = 4.8_real64
  req%ponding_depth_cm = 0.01_real64
  call evaluate_rfm_unponded_activation(req,res)
  if (res%status /= RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED) &
       error stop 'A11 ponding must fail closed'

  req%ponding_depth_cm = 0.0_real64
  req%sigma_b = 0.0_real64
  call evaluate_rfm_unponded_activation(req,res)
  if (res%status /= RFM_ACTIVATION_INVALID) error stop 'A11 invalid sigma accepted'

  req%sigma_b = 0.65_real64
  previous_fraction = -1.0_real64
  do i=1,size(rates)
    req%source_rate_cm_per_day = rates(i)
    call evaluate_rfm_unponded_activation(req,res)
    if (res%status /= RFM_ACTIVATION_AVAILABLE) error stop 'A11 grid status'
    call assert_partition(req,res)
    if (res%preferential_fraction+tol < previous_fraction) error stop 'A11 source monotonicity'
    previous_fraction = res%preferential_fraction
  end do

  print '(a)', 'PPA_WU05A11_RFM_UNPONDED_ACTIVATION=PASS'

contains

  subroutine assert_partition(request,result)
    type(rfm_unponded_activation_request_t), intent(in) :: request
    type(rfm_unponded_activation_result_t), intent(in) :: result
    if (result%matrix_rate_cm_per_day < -tol .or. &
        result%matrix_rate_cm_per_day > request%source_rate_cm_per_day+tol) &
         error stop 'A11 matrix bounds'
    if (result%preferential_rate_cm_per_day < -tol .or. &
        result%preferential_rate_cm_per_day > request%source_rate_cm_per_day+tol) &
         error stop 'A11 preferential bounds'
    if (abs(result%matrix_rate_cm_per_day+result%preferential_rate_cm_per_day- &
        request%source_rate_cm_per_day) > tol) error stop 'A11 partition closure'
  end subroutine assert_partition

end program test_ppa_wu05a11_rfm_unponded_activation
