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

  ! Root salt removal uses the same node water sink and bounded TSCF.
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
       [0.2_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,1.01_real64,1.0_real64,candidate,fluxes,status)
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


  ! Within-interval reversal cannot be reconstructed from a net mean flux.
  ! Ordered substeps use the updated lower-node donor concentration on reversal.
  block
    type(mobile_salt_state_t) :: reversal_start,reversal_result,trace_candidate
    type(mobile_salt_substep_t) :: trace(2),bad_trace(2)
    type(mobile_salt_fluxes_t) :: trace_fluxes
    call initialize_mobile_salt_state([10.0_real64,10.0_real64],[0.4_real64,0.4_real64], &
         [10.0_real64,0.0_real64],reversal_start,status)
    call req(status==SOLUTE_OK,'reversal initialize')
    trace(1)%water_start=[0.4_real64,0.4_real64]
    trace(1)%water_trial=[0.35_real64,0.45_real64]
    trace(1)%face_flux_cm_day=[0.0_real64,1.0_real64,0.0_real64]
    trace(1)%root_water_sink_cm_day=[0.0_real64,0.0_real64]
    trace(1)%duration_day=0.5_real64
    trace(2)%water_start=[0.35_real64,0.45_real64]
    trace(2)%water_trial=[0.4_real64,0.4_real64]
    trace(2)%face_flux_cm_day=[0.0_real64,-1.0_real64,0.0_real64]
    trace(2)%root_water_sink_cm_day=[0.0_real64,0.0_real64]
    trace(2)%duration_day=0.5_real64
    call advance_mobile_salt_trace(reversal_start,[10.0_real64,10.0_real64],trace,0.0_real64, &
         reversal_result,trace_fluxes,status)
    call req(status==SOLUTE_OK,'ordered reversal trace')
    call req(abs(sum(reversal_result%mass_mg_cm2)-40.0_real64)<tol,'reversal salt conservation')
    call req(abs(reversal_result%mass_mg_cm2(1)-35.0_real64-5.0_real64/9.0_real64)<tol, &
         'reversal uses updated donor concentration')
    call req(abs(trace_fluxes%closure_error_mg_cm2)<tol,'trace closure receipt')

    ! The first step is valid but the second has inconsistent water closure.
    ! The API must not publish a partial candidate or accumulated receipt.
    bad_trace=trace
    bad_trace(2)%water_trial=[0.41_real64,0.4_real64]
    call advance_mobile_salt_trace(reversal_start,[10.0_real64,10.0_real64],bad_trace,0.0_real64, &
         trace_candidate,trace_fluxes,status)
    call req(status==SOLUTE_WATER_CLOSURE,'later trace step rejected')
    call req(.not.allocated(trace_candidate%mass_mg_cm2),'failed trace candidate discarded')
    call req(abs(trace_fluxes%top_input_mg_cm2)+abs(trace_fluxes%top_output_mg_cm2)+ &
         abs(trace_fluxes%bottom_input_mg_cm2)+abs(trace_fluxes%bottom_output_mg_cm2)+ &
         abs(trace_fluxes%root_uptake_mg_cm2)+abs(trace_fluxes%closure_error_mg_cm2)<tol, &
         'failed trace receipt discarded')
    call req(maxval(abs(reversal_start%mass_mg_cm2-[40.0_real64,0.0_real64]))<tol, &
         'trace rejection leaves committed state unchanged')
  end block

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
