program test_crop_rotation_transition
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_crop_rotation_calendar
 use mod_crop_rotation_transition
 implicit none
 type(crop_calendar_t) :: cal
 type(crop_rotation_checkpoint_t) :: committed, snapshot, restored
 type(crop_rotation_candidate_t) :: trial, replay
 integer :: s
 call initialize_crop_calendar([100.0_real64,200.0_real64], &
   [150.0_real64,240.0_real64],cal,s)
 call require(s==CROP_CAL_OK,'calendar')
 call initialize_crop_rotation_checkpoint(cal,100.0_real64,committed,s)
 call require(s==ROT_TRANS_OK,'initial')
 snapshot=committed
 call propose_crop_rotation_transition(cal,committed,160.0_real64,trial,s)
 call require(s==ROT_TRANS_OK,'candidate fallow')
 call require(committed%crop()==1.and.committed%serial()==0_int64,'trial immutable')
 replay=trial
 call accept_crop_rotation_transition(committed,trial,s)
 call require(s==ROT_TRANS_OK.and.committed%crop()==0,'fallow accepted')
 call accept_crop_rotation_transition(committed,replay,s)
 call require(s==ROT_TRANS_STALE.and.committed%serial()==1_int64,'stale retry')
 restored=committed
 call propose_crop_rotation_transition(cal,restored,200.0_real64,trial,s)
 call require(s==ROT_TRANS_OK,'next crop proposed after checkpoint restore')
 call accept_crop_rotation_transition(restored,trial,s)
 call require(s==ROT_TRANS_OK.and.restored%crop()==2.and.restored%serial()==2_int64,'second crop')
 call require(snapshot%crop()==1.and.snapshot%serial()==0_int64,'original checkpoint preserved')
 call propose_crop_rotation_transition(cal,restored,199.0_real64,trial,s)
 call require(s==ROT_TRANS_TIME,'time reversal')
 print '(a)','SW431_CROP_ROTATION_TRANSITION=PASS'
 contains
 subroutine require(ok,label)
 logical,intent(in) :: ok
 character(*),intent(in) :: label
 if (.not.ok) then
   print *, 'FAIL:',label
   error stop 1
 end if
 end subroutine
end program
