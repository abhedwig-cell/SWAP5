program test_ppa_wu04b_boesten_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_restricted_surface_evaporation, only: boesten_evaporation_parameters_t, boesten_evaporation_state_t, &
       boesten_evaporation_forcing_t, boesten_evaporation_result_t, evaluate_boesten_evaporation_reduction, &
       BOESTEN_EVAP_AVAILABLE, BOESTEN_EVAP_INVALID_INPUT
  implicit none

  real(real64), parameter :: tol = 1.0e-14_real64
  type(boesten_evaporation_parameters_t) :: p
  type(boesten_evaporation_state_t) :: s
  type(boesten_evaporation_forcing_t) :: f
  type(boesten_evaporation_result_t) :: r, a1, b, a2
  real(real64) :: expected_spev, expected_saev, expected_demand, dt

  p%cofred = 0.35_real64
  dt = 0.25_real64
  s%spev = 0.04_real64
  s%saev = 0.04_real64
  f%potential_bare_soil_evaporation = 0.30_real64
  f%wetting_rate = 0.05_real64
  f%surface_is_ponded = .false.
  call evaluate_boesten_evaporation_reduction(p, s, f, dt, r)
  expected_spev = s%spev + (f%potential_bare_soil_evaporation-f%wetting_rate)*dt
  if (expected_spev < p%cofred**2) then
    expected_saev = expected_spev
  else
    expected_saev = p%cofred*sqrt(expected_spev)
  end if
  expected_demand = f%wetting_rate + (expected_saev-s%saev)/dt
  call require(r%status == BOESTEN_EVAP_AVAILABLE, 'drying status')
  call require(abs(r%candidate_state%spev-expected_spev) <= tol, 'drying SPEV equation')
  call require(abs(r%candidate_state%saev-expected_saev) <= tol, 'drying SAEV equation')
  call require(abs(r%empirical_bare_soil_evaporation_demand-expected_demand) <= tol, 'drying demand equation')
  print '(a)', 'PPA_WU04B_DRYING_SOURCE_EQUATION_ORACLE=PASS'

  s%spev = 0.50_real64
  s%saev = 0.20_real64
  f%potential_bare_soil_evaporation = 0.08_real64
  f%wetting_rate = 0.30_real64
  call evaluate_boesten_evaporation_reduction(p, s, f, dt, r)
  expected_saev = max(0.0_real64, s%saev-(f%wetting_rate-f%potential_bare_soil_evaporation)*dt)
  if (expected_saev < p%cofred**2) then
    expected_spev = expected_saev
  else
    expected_spev = (expected_saev/p%cofred)**2
  end if
  call require(r%status == BOESTEN_EVAP_AVAILABLE, 'rewetting status')
  call require(r%empirical_bare_soil_evaporation_demand == f%potential_bare_soil_evaporation, &
       'rewetting demand equals PEVA')
  call require(abs(r%candidate_state%spev-expected_spev) <= tol, 'rewetting SPEV inverse')
  call require(abs(r%candidate_state%saev-expected_saev) <= tol, 'rewetting SAEV equation')
  print '(a)', 'PPA_WU04B_REWETTING_SOURCE_EQUATION_ORACLE=PASS'

  s%spev = 2.0_real64
  s%saev = 0.35_real64
  f%surface_is_ponded = .true.
  f%potential_bare_soil_evaporation = 0.22_real64
  f%wetting_rate = 0.0_real64
  call evaluate_boesten_evaporation_reduction(p, s, f, dt, r)
  call require(r%status == BOESTEN_EVAP_AVAILABLE .and. r%ponding_reset_applied, 'ponding status/reset')
  call require(r%candidate_state%spev == 0.0_real64 .and. r%candidate_state%saev == 0.0_real64, &
       'ponding pair exact zero')
  call require(r%empirical_bare_soil_evaporation_demand == f%potential_bare_soil_evaporation, &
       'ponding demand')
  print '(a)', 'PPA_WU04B_PONDING_ATOMIC_PAIR_RESET=PASS'

  f%surface_is_ponded = .false.
  f%potential_bare_soil_evaporation = 0.25_real64
  f%wetting_rate = 0.02_real64
  s%spev = 0.15_real64
  s%saev = p%cofred*sqrt(s%spev)
  call evaluate_boesten_evaporation_reduction(p, s, f, 0.125_real64, a1)
  s%spev = 1.2_real64
  s%saev = p%cofred*sqrt(s%spev)
  call evaluate_boesten_evaporation_reduction(p, s, f, 0.375_real64, b)
  s%spev = 0.15_real64
  s%saev = p%cofred*sqrt(s%spev)
  call evaluate_boesten_evaporation_reduction(p, s, f, 0.125_real64, a2)
  call require(a1%status == BOESTEN_EVAP_AVAILABLE .and. b%status == BOESTEN_EVAP_AVAILABLE .and. &
       a2%status == BOESTEN_EVAP_AVAILABLE, 'ABA status')
  call require(a1%candidate_state%spev == a2%candidate_state%spev .and. &
       a1%candidate_state%saev == a2%candidate_state%saev .and. &
       a1%empirical_bare_soil_evaporation_demand == a2%empirical_bare_soil_evaporation_demand, 'ABA exact')
  print '(a)', 'PPA_WU04B_STATELESS_A_B_A_REPLAY=PASS'

  p%cofred = 0.0_real64
  call evaluate_boesten_evaporation_reduction(p, s, f, dt, r)
  call require(r%status == BOESTEN_EVAP_INVALID_INPUT, 'cofred zero bounded out')
  p%cofred = 1.01_real64
  call evaluate_boesten_evaporation_reduction(p, s, f, dt, r)
  call require(r%status == BOESTEN_EVAP_INVALID_INPUT, 'cofred above one bounded out')
  print '(a)', 'PPA_WU04B_COFRED_ZERO_SINGULARITY_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-WU04-B BOESTEN PROCESS TEST PASS'

contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU04B_PROCESS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu04b_boesten_process
