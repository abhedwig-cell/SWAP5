program test_ppa_wu05a3_interval_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_interval_candidate
  use mod_ppa_wu05a3_conservative_flux
  implicit none
  type(ppa_wu05a2_macropore_committed_t) :: state,restored
  type(ppa_wu05a2_macropore_checkpoint_t) :: cp,cp2
  type(ppa_wu05a2_macropore_candidate_t) :: trial,replay
  type(ppa_wu05a2_macropore_restart_t) :: restart
  real(real64) :: volume(1,3),exchange(1,3),drain(3)
  real(real64),allocatable :: faces(:,:),residual(:)
  integer :: status
  logical :: ok
  call ppa_wu05a2_initialize_payload(1,3,state%payload,ok)
  call require(ok,1)
  state%lineage_id=17_int64; state%revision=0_int64
  state%payload%bottom_domain=3; state%payload%pore_volume=0.5_real64
  state%payload%pore_water(1,:)=[0.0_real64,0.25_real64,0.5_real64]
  state%payload%domain_water_storage=0.75_real64
  volume=0.5_real64; exchange=0.0_real64; exchange(1,2)=0.0625_real64
  drain=[0.0_real64,0.0_real64,2.0_real64]
  call ppa_wu05a2_capture_checkpoint(state,cp,ok)
  call require(ok,2)
  call prepare(cp,trial)
  call require(status==FLUX_BOUNDARY_MISMATCH .and. .not.trial%valid,3)
  call ppa_wu05a2_commit_candidate(trial,state,ok)
  call require(.not.ok .and. state%revision==0_int64,4)
  call require(abs(state%payload%domain_water_storage(1)-0.75_real64)<tiny(1.0_real64),5)
  drain(3)=0.0625_real64
  call prepare(cp,trial)
  call require(status==FLUX_OK .and. trial%valid,6)
  call require(maxval(abs(trial%payload%pore_water_previous-cp%payload%pore_water))<tiny(1.0_real64),7)
  call ppa_wu05a2_commit_candidate(trial,state,ok)
  call require(ok .and. state%revision==1_int64,8)
  call require(abs(state%payload%domain_water_storage(1)-0.875_real64)<tiny(1.0_real64),9)
  call ppa_wu05a2_export_restart(state,restart,ok)
  call require(ok,10)
  call ppa_wu05a2_restore_restart(restart,restored,ok)
  call require(ok,11)
  call ppa_wu05a2_capture_checkpoint(state,cp,ok)
  call require(ok,12)
  call ppa_wu05a2_capture_checkpoint(restored,cp2,ok)
  call require(ok,13)
  volume=0.375_real64
  call prepare(cp,trial)
  call require(status==FLUX_OK,14)
  call prepare(cp2,replay)
  call require(status==FLUX_OK,15)
  call require(maxval(abs(trial%payload%pore_water-replay%payload%pore_water))+ &
      maxval(abs(trial%payload%domain_water_storage-replay%payload%domain_water_storage))<tiny(1.0_real64),16)
  call require(maxval(abs(trial%payload%pore_volume_previous-0.5_real64))<tiny(1.0_real64),17)
  call ppa_wu05a2_commit_candidate(trial,state,ok)
  call require(ok .and. state%revision==2_int64,18)
  call ppa_wu05a2_commit_candidate(replay,state,ok)
  call require(.not.ok .and. state%revision==2_int64,19)
  call prepare_macropore_interval_candidate(cp,ieee_value(0.0_real64,ieee_quiet_nan),volume, &
      [0.25_real64],[0.0_real64],exchange,drain,[1.0_real64,1.0_real64,1.0_real64],[-3.0_real64], &
      1.e-14_real64,trial,faces,residual,status)
  call require(status==FLUX_INVALID .and. .not.trial%valid,20)
  call require(.not.allocated(faces) .and. .not.allocated(residual),21)
  call check_sorptivity_transaction()
  print '(A)','PPA_WU05A3_INTERVAL_REJECT_CANNOT_COMMIT=PASS'
  print '(A)','PPA_WU05A3_INTERVAL_RETRY_COMMIT=PASS'
  print '(A)','PPA_WU05A3_INTERVAL_HISTORY_RESTART=PASS'
  print '(A)','PPA_WU05A3_INTERVAL_STALE_AND_INVALID_GUARDS=PASS'
  print '(A)','PPA_WU05A3_INTERVAL_SORPTIVITY_ATOMIC_RESTART=PASS'
contains
  subroutine check_sorptivity_transaction()
    type(interval_sorptivity_drivers) :: drivers
    real(real64),allocatable :: wall_after(:)
    allocate(drivers%ended(1,3),drivers%proportion(1,3),drivers%diameter(3),drivers%wall_previous(3))
    drivers%saturated_top=4; drivers%ended=.false.; drivers%ended(1,2)=.true.
    drivers%proportion=0.5_real64; drivers%diameter=0.0_real64; drivers%wall_previous=0.8_real64
    state%payload%absorption_time=4.0_real64
    state%payload%sorptivity=2.0_real64; state%payload%sorptivity_reference=1.0_real64
    call ppa_wu05a2_capture_checkpoint(state,cp,ok)
    call require(ok,22)
    call prepare_events(cp,trial,drivers,wall_after)
    call require(status==FLUX_INVALID .and. .not.trial%valid .and. allocated(faces),23)
    call ppa_wu05a2_commit_candidate(trial,state,ok)
    call require(.not.ok .and. state%revision==2_int64,24)
    drivers%diameter=2.0_real64; drivers%proportion=0.25_real64
    call prepare_events(cp,trial,drivers,wall_after)
    call require(status==FLUX_INVALID .and. .not.trial%valid .and. .not.allocated(wall_after),25)
    call require(maxval(abs(state%payload%absorption_time-4.0_real64))<tiny(1.0_real64),26)
    drivers%proportion=0.5_real64
    call prepare_events(cp,trial,drivers,wall_after)
    call require(status==FLUX_OK .and. trial%valid,27)
    call require(abs(trial%payload%absorption_time(1,2))+abs(trial%payload%sorptivity(1,2))+ &
        abs(trial%payload%sorptivity_reference(1,2))<tiny(1.0_real64),28)
    call require(abs(trial%payload%absorption_time(1,3)-5.0_real64)<tiny(1.0_real64),29)
    call require(maxval(abs(wall_after-0.5_real64))<tiny(1.0_real64),30)
    call ppa_wu05a2_commit_candidate(trial,state,ok)
    call require(ok .and. state%revision==3_int64,31)
    drivers%wall_previous=wall_after
    call ppa_wu05a2_export_restart(state,restart,ok)
    call require(ok,32)
    call ppa_wu05a2_restore_restart(restart,restored,ok)
    call require(ok,33)
    call ppa_wu05a2_capture_checkpoint(state,cp,ok)
    call require(ok,34)
    call ppa_wu05a2_capture_checkpoint(restored,cp2,ok)
    call require(ok,35)
    call prepare_events(cp,trial,drivers,wall_after)
    call require(status==FLUX_OK,36)
    call prepare_events(cp2,replay,drivers,wall_after)
    call require(status==FLUX_OK,37)
    call require(maxval(abs(trial%payload%absorption_time-replay%payload%absorption_time))+ &
        maxval(abs(trial%payload%sorptivity_reference-replay%payload%sorptivity_reference))+ &
        maxval(abs(trial%payload%pore_water-replay%payload%pore_water))<tiny(1.0_real64),38)
    call require(all(trial%payload%sorptivity_event_ended .eqv. drivers%ended),39)
  end subroutine
  subroutine prepare_events(checkpoint,candidate,drivers,wall_after)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in) :: checkpoint
    type(ppa_wu05a2_macropore_candidate_t),intent(out) :: candidate
    type(interval_sorptivity_drivers),intent(in) :: drivers
    real(real64),allocatable,intent(out) :: wall_after(:)
    call prepare_macropore_interval_candidate(checkpoint,1.0_real64,volume,[0.125_real64],[0.0_real64], &
        exchange,drain,[1.0_real64,1.0_real64,1.0_real64],[-3.0_real64],1.e-14_real64, &
        candidate,faces,residual,status,drivers,wall_after)
  end subroutine

  subroutine prepare(checkpoint,candidate)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in) :: checkpoint
    type(ppa_wu05a2_macropore_candidate_t),intent(out) :: candidate
    call prepare_macropore_interval_candidate(checkpoint,1.0_real64,volume,[0.25_real64],[0.0_real64], &
        exchange,drain,[1.0_real64,1.0_real64,1.0_real64],[-3.0_real64],1.e-14_real64, &
        candidate,faces,residual,status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'INTERVAL_CANDIDATE_FAIL',code
      error stop 1
    end if
  end subroutine
end program
