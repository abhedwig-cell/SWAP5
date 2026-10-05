program test_mobile_salt_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_solute_mobile_salt_state
  implicit none
  type(mobile_salt_state_t) :: committed,candidate,replay,restarted,discarded
  type(mobile_salt_fluxes_t) :: fluxes
  type(mobile_salt_substep_t) :: source_substep(1)
  real(real64),allocatable :: qdra_test(:,:),qssdi_test(:),unallocated_rate(:)
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
  ! B1.11 drainage is signed and level-resolved: positive levels export at
  ! start CML, negative levels import at explicit Cdrain. qssdi adds water but
  ! has no salt source term.
  allocate(qdra_test(2,2),qssdi_test(2))
  qdra_test=reshape([0.01_real64,-0.005_real64,-0.01_real64,0.0_real64],[2,2])
  qssdi_test=[0.02_real64,0.0_real64]
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2015_real64,0.201_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status, &
       qdra_rate=qdra_test,qssdi_rate=qssdi_test,cdrain_mg_cm3=1.0_real64,cdrain_available=.true.)
  call req(status==SOLUTE_OK,'signed level drainage and water-only qssdi')
  call req(allocated(fluxes%qdra_signed_out_mg_cm2),'level-resolved qdra receipt')
  call req(maxval(abs(fluxes%qdra_signed_out_mg_cm2-[0.01_real64,-0.005_real64]))<tol, &
       'signed qdra donor-specific receipts')
  call req(abs(sum(candidate%mass_mg_cm2)-11.995_real64)<tol,'qssdi has no implied salt input')
  call req(abs(fluxes%closure_error_mg_cm2)<tol,'qssdi and qdra salt ledger')

  qdra_test=0.0_real64
  qdra_test(1,1)=0.01_real64
  qdra_test(2,2)=0.01_real64
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.199_real64,0.199_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status,qdra_rate=qdra_test)
  call req(status==SOLUTE_OK.and.abs(sum(fluxes%qdra_signed_out_mg_cm2)-0.06_real64)<tol, &
       'positive qdra exports without Cdrain import authority')

  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.2_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status,qssdi_rate=unallocated_rate)
  call req(status==SOLUTE_INVALID.and..not.allocated(candidate%mass_mg_cm2), &
       'explicit unallocated qssdi route rejected')

  qdra_test=reshape([0.01_real64,-0.005_real64,-0.01_real64,0.0_real64],[2,2])
  call advance_mobile_salt_trial(committed,[10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [0.21_real64,0.2_real64],[0.0_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,candidate,fluxes,status, &
       qdra_rate=qdra_test,qssdi_rate=qssdi_test,cdrain_mg_cm3=1.0_real64,cdrain_available=.false.)
  call req(status==SOLUTE_INVALID,'negative qdra without Cdrain authority rejected')
  call req(.not.allocated(candidate%mass_mg_cm2).and..not.allocated(fluxes%qdra_signed_out_mg_cm2), &
       'rejected drainage publishes no partial candidate or receipt')

  source_substep(1)%water_start=[0.2_real64,0.2_real64]
  source_substep(1)%water_trial=[0.2015_real64,0.201_real64]
  source_substep(1)%face_flux_cm_day=[0.0_real64,0.0_real64,0.0_real64]
  source_substep(1)%root_water_sink_cm_day=[0.0_real64,0.0_real64]
  source_substep(1)%qdra_rate=reshape([0.01_real64,-0.005_real64,-0.01_real64,0.0_real64],[2,2])
  source_substep(1)%qssdi_rate=[0.02_real64,0.0_real64]
  source_substep(1)%cdrain_mg_cm3=1.0_real64
  source_substep(1)%cdrain_available=.true.
  source_substep(1)%duration_day=1.0_real64
  call advance_mobile_salt_trace(committed,[10.0_real64,10.0_real64],source_substep,0.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_OK.and.maxval(abs(candidate%mass_mg_cm2-[3.985_real64,8.01_real64]))<tol, &
       'ordered salt trace carries qdra and qssdi authority')
  source_substep(1)%cdrain_available=.false.
  call advance_mobile_salt_trace(committed,[10.0_real64,10.0_real64],source_substep,0.0_real64,candidate,fluxes,status)
  call req(status==SOLUTE_INVALID.and..not.allocated(candidate%mass_mg_cm2).and. &
       .not.allocated(fluxes%qdra_signed_out_mg_cm2),'late trace rejection clears drainage candidate and receipts')

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
