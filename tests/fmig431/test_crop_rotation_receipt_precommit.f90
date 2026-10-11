program test_crop_rotation_receipt_precommit
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_crop_rotation_calendar
  use mod_crop_rotation_transition
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t
  use mod_fmr_crop_rotation_receipt_binding
  implicit none
  type(crop_calendar_t) :: cal,invalid_cal
  type(crop_rotation_checkpoint_t) :: state
  type(fmr_wofost_accepted_window_t) :: window
  type(kernel_committed_state_t) :: unready_kernel
  logical :: accepted
  integer :: status,idx
  integer(int64) :: rev
  real(real64) :: at
  call initialize_crop_calendar([100.0_real64,200.0_real64], &
       [150.0_real64,240.0_real64],cal,status)
  if(status/=CROP_CAL_OK) error stop 'calendar init'
  call initialize_crop_rotation_checkpoint(cal,100.0_real64,state,status)
  if(status/=ROT_TRANS_OK) error stop 'calendar checkpoint'
  idx=state%crop()
  rev=state%serial()
  at=state%time()
  call reconcile_committed_crop_rotation_transition(cal,state,window,unready_kernel,accepted,status)
  if(accepted.or.status/=CROP_ROT_RECEIPT_INVALID) error stop 'unready physical accept'
  if(state%crop()/=idx.or.state%serial()/=rev) error stop 'trial touched checkpoint'
  if(state%time()/=at) error stop 'trial touched clock'
  if(window%ready().or.window%delivery_committed()) error stop 'window changed by invalid receipt'
  call reconcile_committed_crop_rotation_transition(invalid_cal,state,window,unready_kernel,accepted,status)
  if(accepted.or.status/=CROP_ROT_RECEIPT_INVALID) error stop 'invalid calendar accepted'
  if(state%crop()/=idx.or.state%serial()/=rev.or.state%time()/=at) error stop 'invalid calendar mutated'
  call reconcile_committed_crop_rotation_transition(cal,state,window,unready_kernel,accepted,status)
  if(accepted.or.status/=CROP_ROT_RECEIPT_INVALID) error stop 'replayed precommit receipt accepted'
  if(state%crop()/=idx.or.state%serial()/=rev.or.state%time()/=at) error stop 'replay mutated'
  if(window%ready().or.window%delivery_committed()) error stop 'replay changed window'
  print '(a)','SW431_CROP_ROTATION_INVALID_CALENDAR_REPLAY_NO_MUTATION=PASS'
  print '(a)','SW431_CROP_ROTATION_PRECOMMIT_NO_MUTATION=PASS'
end program
