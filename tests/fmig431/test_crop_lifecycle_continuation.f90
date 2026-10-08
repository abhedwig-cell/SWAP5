program test_crop_lifecycle_continuation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_crop_lifecycle_daily_composition
  use mod_crop_germination_preflight
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, reconstruct_wofost_crop_event_identity_from_persistence, &
       FMR_WOFOST_LINEAGE_OK
  use mod_crop_lifecycle_continuation
  implicit none
  type(crop_lifecycle_continuation_t) :: initial, accepted, candidate
  type(crop_daily_lifecycle_candidate_t) :: plan
  type(crop_germination_candidate_t) :: germination
  type(fmr_wofost_crop_event_identity_t) :: events(4)
  type(fmr_wofost_crop_event_identity_persistence_t) :: receipt
  integer :: status, i, receipt_status

  receipt%valid=.true.
  receipt%lineage_id=17_int64
  receipt%t0=0.0_real64
  receipt%t1=1.0_real64
  do i=1,4
    receipt%final_revision=int(i,int64)
    call reconstruct_wofost_crop_event_identity_from_persistence(receipt,events(i),receipt_status)
    if(receipt_status/=FMR_WOFOST_LINEAGE_OK) error stop 10
  end do
  initial%valid=.true.
  initial%crop_identity=4_int64
  plan%valid=.true.
  plan%prepared=.true.
  plan%sown=.true.
  plan%germination_evaluated=.true.
  germination%valid=.true.
  germination%next_temperature_sum=2.0_real64

  call propose_crop_lifecycle_continuation(initial,plan,germination,0_int64,events(1),candidate,status)
  if(status/=CROP_CONT_OK.or.candidate%revision/=1_int64.or.candidate%emerged) error stop 1
  if(initial%revision/=0_int64.or..not.initial%ready()) error stop 2
  accepted=candidate
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,events(1),candidate,status)
  if(status/=CROP_CONT_DUPLICATE.or.candidate%revision/=1_int64) error stop 3
  call propose_crop_lifecycle_continuation(accepted,plan,germination,0_int64,events(2),candidate,status)
  if(status/=CROP_CONT_STALE.or.candidate%revision/=1_int64) error stop 4
  plan%germinated=.true.
  plan%emergence_eligible=.true.
  germination%complete=.true.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,events(2),candidate,status)
  if(status/=CROP_CONT_OK.or..not.candidate%germinated.or.candidate%emerged) error stop 5
  ! A rejected proposal must preserve the entire accepted snapshot.
  plan%valid=.false.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,events(3),candidate,status)
  if(status/=CROP_CONT_INVALID.or.candidate%revision/=accepted%revision) error stop 6
  if(candidate%revision/=accepted%revision) error stop 7
  if(transfer(candidate%germination_temperature_sum,0_int64)/= &
       transfer(accepted%germination_temperature_sum,0_int64)) error stop 8
  plan%valid=.true.
  plan%germinated=.false.
  plan%emergence_eligible=.false.
  plan%germination_evaluated=.false.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,events(4),candidate,status)
  if(status/=CROP_CONT_INVALID.or.candidate%revision/=accepted%revision) error stop 9
  print '(A)', 'SW431_CROP_LIFECYCLE_CONTINUATION=PASS'
end program
