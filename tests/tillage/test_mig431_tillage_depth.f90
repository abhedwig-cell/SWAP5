program test_mig431_tillage_depth
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_tillage_depth_binding
  implicit none
  logical, allocatable :: affected(:)
  integer :: status
  call bind_tillage_event_depth([10.0_real64,10.0_real64,20.0_real64], &
       [2,3],20.0_real64,affected,status)
  if (status /= TILLAGE_DEPTH_OK) error stop 1
  if (any(affected .neqv. [.true.,.true.,.false.])) error stop 2
  call bind_tillage_event_depth([10.0_real64,10.0_real64,20.0_real64], &
       [2,3],10.0_real64,affected,status)
  if (status /= TILLAGE_DEPTH_INVALID .or. allocated(affected)) error stop 3
  call bind_tillage_event_depth([10.0_real64,10.0_real64,20.0_real64], &
       [2,3],40.0_real64,affected,status)
  if (status /= TILLAGE_DEPTH_OK .or. .not. all(affected)) error stop 4
  print '(a)', 'F_MIG431_TILLAGE_HORIZON_DEPTH_BINDING=PASS'
end program
