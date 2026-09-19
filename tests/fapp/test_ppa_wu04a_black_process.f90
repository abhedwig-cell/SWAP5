program test_ppa_wu04a_black_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_restricted_surface_evaporation, only: black_evaporation_parameters_t, black_evaporation_state_t, &
       black_evaporation_forcing_t, black_evaporation_result_t, evaluate_black_evaporation_reduction, &
       BLACK_EVAP_AVAILABLE, BLACK_EVAP_INVALID_INPUT
  implicit none

  real(real64), parameter :: tol = 1.0e-14_real64
  real(real64), parameter :: cofred = 0.35_real64
  real(real64), parameter :: peva = 0.21_real64
  real(real64), parameter :: dts(5) = [0.03125_real64, 0.125_real64, 0.25_real64, 0.5_real64, 1.0_real64]
  real(real64), parameter :: ld0s(5) = [0.0_real64, 0.125_real64, 1.0_real64, 3.5_real64, 11.0_real64]

  type(black_evaporation_parameters_t) :: p
  type(black_evaporation_state_t) :: s
  type(black_evaporation_forcing_t) :: f
  type(black_evaporation_result_t) :: r, a1, b, a2
  real(real64) :: expected
  integer :: i

  p%cofred = cofred
  f%potential_bare_soil_evaporation = peva

  do i = 1, size(dts)
    s%ldwet = ld0s(i)
    f%surface_is_ponded = .false.
    f%wetting_reset_event = .false.
    call evaluate_black_evaporation_reduction(p, s, f, dts(i), r)
    expected = min(peva, cofred * (sqrt(ld0s(i) + dts(i)) - sqrt(ld0s(i))) / dts(i))
    call require(r%status == BLACK_EVAP_AVAILABLE, 'dry case status')
    call require(abs(r%empirical_bare_soil_evaporation_demand - expected) <= tol, 'dry source equation')
    call require(abs(r%candidate_state%ldwet - (ld0s(i) + dts(i))) <= tol, 'dry candidate ldwet')
  end do
  print '(a)', 'PPA_WU04A_BLACK_SOURCE_EQUATION_ORACLE=PASS'

  s%ldwet = 7.25_real64
  f%surface_is_ponded = .false.
  f%wetting_reset_event = .true.
  call evaluate_black_evaporation_reduction(p, s, f, 0.25_real64, r)
  expected = min(peva, cofred * sqrt(0.25_real64) / 0.25_real64)
  call require(r%status == BLACK_EVAP_AVAILABLE, 'wetting reset status')
  call require(r%wetting_reset_applied, 'wetting reset marker')
  call require(abs(r%candidate_state%ldwet - 0.25_real64) <= tol, 'wetting reset candidate')
  call require(abs(r%empirical_bare_soil_evaporation_demand - expected) <= tol, 'wetting reset equation')
  print '(a)', 'PPA_WU04A_EXPLICIT_WETTING_RESET_ORACLE=PASS'

  s%ldwet = 4.0_real64
  f%surface_is_ponded = .true.
  f%wetting_reset_event = .false.
  call evaluate_black_evaporation_reduction(p, s, f, 0.25_real64, r)
  call require(r%status == BLACK_EVAP_AVAILABLE, 'ponded status')
  call require(r%ponding_reset_applied, 'ponding reset marker')
  call require(r%candidate_state%ldwet == 0.0_real64, 'ponding exact zero ldwet')
  call require(r%empirical_bare_soil_evaporation_demand == peva, 'ponding no reduction demand')
  print '(a)', 'PPA_WU04A_PONDING_RESET_ORACLE=PASS'

  s%ldwet = 2.5_real64
  f%surface_is_ponded = .false.
  f%wetting_reset_event = .false.
  call evaluate_black_evaporation_reduction(p, s, f, 0.125_real64, a1)
  s%ldwet = 9.75_real64
  call evaluate_black_evaporation_reduction(p, s, f, 0.375_real64, b)
  s%ldwet = 2.5_real64
  call evaluate_black_evaporation_reduction(p, s, f, 0.125_real64, a2)
  call require(a1%status == BLACK_EVAP_AVAILABLE .and. b%status == BLACK_EVAP_AVAILABLE .and. &
       a2%status == BLACK_EVAP_AVAILABLE, 'ABA statuses')
  call require(a1%empirical_bare_soil_evaporation_demand == a2%empirical_bare_soil_evaporation_demand, &
       'ABA demand identity')
  call require(a1%candidate_state%ldwet == a2%candidate_state%ldwet, 'ABA state identity')
  print '(a)', 'PPA_WU04A_STATELESS_A_B_A_REPLAY=PASS'

  p%cofred = -1.0_real64
  call evaluate_black_evaporation_reduction(p, s, f, 0.25_real64, r)
  call require(r%status == BLACK_EVAP_INVALID_INPUT, 'negative cofred rejected')
  p%cofred = cofred
  s%ldwet = -1.0_real64
  call evaluate_black_evaporation_reduction(p, s, f, 0.25_real64, r)
  call require(r%status == BLACK_EVAP_INVALID_INPUT, 'negative ldwet rejected')
  print '(a)', 'PPA_WU04A_INVALID_INPUT_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-WU04-A BLACK PROCESS TEST PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU04A_PROCESS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu04a_black_process
