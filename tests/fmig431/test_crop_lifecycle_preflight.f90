program test_crop_lifecycle_preflight
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_crop_rotation_calendar
 use mod_crop_rotation_transition
 use mod_crop_rotation_lifecycle_preflight
 implicit none
 type(crop_calendar_t) :: calendar
 type(crop_rotation_checkpoint_t) :: checkpoint
 type(crop_rotation_candidate_t) :: candidate
 type(crop_lifecycle_preflight_t) :: plan
 integer :: status
 call initialize_crop_calendar([100.0_real64,200.0_real64], &
      [150.0_real64,240.0_real64],calendar,status)
 if(status/=CROP_CAL_OK) error stop 'calendar'
 call initialize_crop_rotation_checkpoint(calendar,99.0_real64,checkpoint,status)
 if(status/=ROT_TRANS_OK) error stop 'checkpoint'
 call inspect_crop_lifecycle(calendar,checkpoint,101.0_real64,plan,status)
 if(status/=CROP_LIFE_OK.or..not.plan%valid.or.plan%action/=CROP_LIFE_ENTER) error stop 'enter'
 if(plan%previous_crop/=0.or.plan%next_crop/=1.or.plan%origin_revision/=0_int64) error stop 'enter owner'
 if(checkpoint%crop()/=0.or.checkpoint%time()/=99.0_real64) error stop 'read only enter'
 call propose_crop_rotation_transition(calendar,checkpoint,101.0_real64,candidate,status)
 if(status/=ROT_TRANS_OK) error stop 'proposal'
 call accept_crop_rotation_transition(checkpoint,candidate,status)
 if(status/=ROT_TRANS_OK) error stop 'commit'
 call inspect_crop_lifecycle(calendar,checkpoint,151.0_real64,plan,status)
 if(status/=CROP_LIFE_OK.or.plan%action/=CROP_LIFE_EXIT.or.plan%next_crop/=0) error stop 'exit'
 call propose_crop_rotation_transition(calendar,checkpoint,151.0_real64,candidate,status)
 call accept_crop_rotation_transition(checkpoint,candidate,status)
 if(status/=ROT_TRANS_OK) error stop 'fallow commit'
 call inspect_crop_lifecycle(calendar,checkpoint,201.0_real64,plan,status)
 if(status/=CROP_LIFE_OK.or.plan%action/=CROP_LIFE_ENTER.or.plan%next_crop/=2) error stop 'second crop'
 call inspect_crop_lifecycle(calendar,checkpoint,151.0_real64,plan,status)
 if(status/=CROP_LIFE_TIME.or.plan%valid) error stop 'reject time'
 if(checkpoint%crop()/=0.or.checkpoint%serial()/=2_int64) error stop 'rejected no mutation'
 print '(a)','SW431_CROP_LIFECYCLE_PREFLIGHT=PASS'
end program
