program test_mig431_tillage_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_tillage_event_owner
  implicit none
  type(tillage_owner_state_t) :: committed, candidate, replay
  type(tillage_owner_restart_t) :: record
  integer :: status, event_index
  real(real64), parameter :: days(2) = [2.0_real64, 5.0_real64]

  call initialize_tillage_owner(days,1.0_real64,committed,status)
  if (status /= TILLAGE_OWNER_OK .or. committed%next_event /= 1) error stop 1
  call advance_tillage_owner(days,1.0_real64,3.0_real64,0.2_real64,committed,candidate,event_index,status)
  if (status /= TILLAGE_OWNER_SPLIT_REQUIRED .or. event_index /= 0) error stop 2
  if (candidate%next_event /= committed%next_event .or. candidate%accepted_net_rain_since_event_cm /= 0) error stop 3
  call advance_tillage_owner(days,1.0_real64,2.0_real64,0.1_real64,committed,candidate,event_index,status)
  if (status /= TILLAGE_OWNER_OK .or. event_index /= 0) error stop 4
  committed = candidate
  call advance_tillage_owner(days,2.0_real64,3.0_real64,0.2_real64,committed,candidate,event_index,status)
  if (status /= TILLAGE_OWNER_OK .or. event_index /= 1) error stop 5
  if (abs(candidate%accepted_net_rain_since_event_cm-0.2_real64) > 1.e-14_real64) error stop 6
  call export_tillage_owner(candidate,2,record,status)
  if (status /= TILLAGE_OWNER_OK) error stop 7
  call restore_tillage_owner(record,2,replay,status)
  if (status /= TILLAGE_OWNER_OK .or. replay%next_event /= 2) error stop 8
  committed = replay
  call advance_tillage_owner(days,3.0_real64,4.0_real64,0.3_real64,committed,candidate,event_index,status)
  if (status /= TILLAGE_OWNER_OK .or. event_index /= 0) error stop 9
  if (abs(candidate%accepted_net_rain_since_event_cm-0.5_real64) > 1.e-14_real64) error stop 10
  record%schema = -1
  call restore_tillage_owner(record,2,replay,status)
  if (status /= TILLAGE_OWNER_INVALID) error stop 11
  print '(a)', 'F_MIG431_TILLAGE_OWNER_SPLIT_RESTART=PASS'
end program
