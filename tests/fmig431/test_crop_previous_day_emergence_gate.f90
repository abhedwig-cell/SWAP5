program test_crop_previous_day_emergence_gate
 use iso_fortran_env, only: int64
 use mod_crop_previous_day_emergence_gate
 implicit none
 logical :: ready
 integer :: status
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(.not.ready.or.status/=CROP_EMERGENCE_OK) error stop 1
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.true., &
   6_int64,6_int64,6_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_SAME_EVENT) error stop 2
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.false., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_NOT_READY) error stop 3
 call evaluate_previous_day_crop_emergence(.false.,.false.,.false.,.true.,.true.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_INACTIVE) error stop 4
 call evaluate_previous_day_crop_emergence(.true.,.true.,.false.,.true.,.true.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_INACTIVE) error stop 5
 call evaluate_previous_day_crop_emergence(.true.,.false.,.true.,.true.,.true.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_ALREADY_ACTIVE) error stop 6
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.true., &
   6_int64,5_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_INVALID) error stop 7
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.false.,.true.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_NOT_READY) error stop 8
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.false.,.true., &
   6_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_NOT_READY) error stop 9
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.true., &
   -1_int64,6_int64,7_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_INVALID) error stop 10
 call evaluate_previous_day_crop_emergence(.true.,.false.,.false.,.true.,.true.,.true., &
   6_int64,6_int64,5_int64,ready,status)
 if(ready.or.status/=CROP_EMERGENCE_SAME_EVENT) error stop 11
 print *, 'PASS previous-day emergence gate'
end program
