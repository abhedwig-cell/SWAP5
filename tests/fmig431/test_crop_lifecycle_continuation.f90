program test_crop_lifecycle_continuation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_crop_lifecycle_daily_composition
  use mod_crop_germination_preflight
  use mod_crop_lifecycle_continuation
  implicit none
  type(crop_lifecycle_continuation_t) :: initial, accepted, candidate
  type(crop_daily_lifecycle_candidate_t) :: plan
  type(crop_germination_candidate_t) :: germination
  integer :: status

  initial%valid=.true.
  initial%crop_identity=4_int64
  plan%valid=.true.
  plan%prepared=.true.
  plan%sown=.true.
  plan%germination_evaluated=.true.
  germination%valid=.true.
  germination%next_temperature_sum=2.0_real64

  call propose_crop_lifecycle_continuation(initial,plan,germination,0_int64,9_int64,candidate,status)
  if(status/=CROP_CONT_OK.or.candidate%revision/=1_int64.or.candidate%emerged) error stop 1
  if(initial%revision/=0_int64.or.initial%last_event_identity/=0_int64) error stop 2
  accepted=candidate
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,9_int64,candidate,status)
  if(status/=CROP_CONT_DUPLICATE.or.candidate%revision/=1_int64) error stop 3
  call propose_crop_lifecycle_continuation(accepted,plan,germination,0_int64,10_int64,candidate,status)
  if(status/=CROP_CONT_STALE.or.candidate%revision/=1_int64) error stop 4
  plan%germinated=.true.
  plan%emergence_eligible=.true.
  germination%complete=.true.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,10_int64,candidate,status)
  if(status/=CROP_CONT_OK.or..not.candidate%germinated.or.candidate%emerged) error stop 5
  ! A rejected proposal must preserve the entire accepted snapshot.
  plan%valid=.false.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,11_int64,candidate,status)
  if(status/=CROP_CONT_INVALID.or.candidate%revision/=accepted%revision) error stop 6
  if(candidate%last_event_identity/=accepted%last_event_identity) error stop 7
  if(candidate%germination_temperature_sum/=accepted%germination_temperature_sum) error stop 8
  plan%valid=.true.
  plan%germinated=.false.
  plan%emergence_eligible=.false.
  plan%germination_evaluated=.false.
  call propose_crop_lifecycle_continuation(accepted,plan,germination,1_int64,12_int64,candidate,status)
  if(status/=CROP_CONT_INVALID.or.candidate%revision/=accepted%revision) error stop 9
  print '(A)', 'SW431_CROP_LIFECYCLE_CONTINUATION=PASS'
end program
