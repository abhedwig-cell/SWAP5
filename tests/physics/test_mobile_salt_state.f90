program test_mobile_salt_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_solute_mobile_salt_state
  implicit none
  type(mobile_salt_state_t) :: committed,candidate,replay,restarted,discarded
  type(mobile_salt_fluxes_t) :: fluxes
  integer :: status
  real(real64),parameter :: tol=2.0e-13_real64

  call initialize_mobile_salt_state([10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [2.0_real64,4.0_real64],committed,status)
  call req(status==SOLUTE_OK,'initialize')
  call req(maxval(abs(committed%mass_mg_cm2-[4.0_real64,8.0_real64]))<tol,'mobile mass initialization')

  ! Closed, stationary column: CML is recovered from authoritative salt mass.
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_OK,'stationary trial')
  call req(maxval(abs(candidate%concentration_mg_cm3-[2.0_real64,4.0_real64]))<tol,'derived mobile concentration')
  call req(maxval(abs(committed%mass_mg_cm2-[4.0_real64,8.0_real64]))<tol,'trial leaves committed untouched')

  ! Upwind throughflow with top concentration 3: only boundary salt changes inventory.
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.2_real64],[0.1_real64,0.1_real64,0.1_real64],[0.0_real64,0.0_real64], &
       3.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_OK,'advective trial')
  call req(abs(fluxes%top_input_mg_cm2-0.3_real64)<tol,'top salt input')
  call req(abs(fluxes%bottom_output_mg_cm2-0.4_real64)<tol,'bottom salt output')
  call req(abs(sum(candidate%mass_mg_cm2)-11.9_real64)<tol,'advective column mass')
  call req(abs(fluxes%closure_error_mg_cm2)<tol,'advective balance')

  ! B1.11 accepts TSCF up to 10; the sink remains tied to the water trial.
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.199_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.01_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.5_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_OK,'root salt uptake trial')
  call req(abs(fluxes%root_uptake_mg_cm2-0.01_real64)<tol,'TSCF root salt uptake')
  call req(abs(candidate%mass_mg_cm2(1)-3.99_real64)<tol,'root uptake mass owner')

  ! A discarded candidate does not affect committed state; retry and restart replay.
  discarded=candidate
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.199_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.01_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.5_real64,1.0_real64,replay,fluxes,status)
  call req(status==SOLUTE_OK.and.maxval(abs(replay%mass_mg_cm2-discarded%mass_mg_cm2))<tol,'retry from committed state')
  restarted=committed
  call advance_mobile_salt_trial(restarted,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.199_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.01_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.5_real64,1.0_real64,replay,fluxes,status)
  call req(status==SOLUTE_OK.and.maxval(abs(replay%mass_mg_cm2-discarded%mass_mg_cm2))<tol,'committed restart replay')

  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.199_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.01_real64,0.0_real64], &
       0.0_real64,0.0_real64,2.0_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_OK.and.abs(fluxes%root_uptake_mg_cm2-0.04_real64)<tol, &
       'source-valid TSCF above unity retains exact root mass receipt')

  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,10.01_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_INVALID,'TSCF above admitted range')
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       ieee_value(0.0_real64,ieee_quiet_nan),0.0_real64,0.5_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_INVALID,'NaN boundary rejected')
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.21_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.5_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_WATER_CLOSURE,'water closure checked before salt transport')
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.5_real64],[3.0_real64,3.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,1.0_real64,1.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_NEGATIVE_MASS,'advective salt exhaustion rejected without clipping')
  call req(maxval(abs(committed%mass_mg_cm2-[4.0_real64,8.0_real64]))<tol,'invalid trial leaves committed state')

  print *,'PPA_WU05E_MOBILE_SALT=PASS'
contains
  subroutine req(ok,label)
    logical,intent(in) :: ok
    character(*),intent(in) :: label
    if(.not.ok) then
      print *,'FAIL ',label
      error stop 1
    end if
  end subroutine
end program
