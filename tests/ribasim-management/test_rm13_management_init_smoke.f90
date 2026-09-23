program test_rm13_management_init_smoke
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use mod_rm13_management_c_bridge, only: rm13_management_initialize_c, rm13_management_state_c
  implicit none
  real(c_double) :: request_depth, requested, allocated, supplied, net, rate
  integer(c_int) :: status, revision

  status = rm13_management_initialize_c(request_depth)
  write(*,'(A,I0)') 'RM13_INIT_STATUS=',status
  if(status /= 0_c_int) error stop 1
  if(abs(request_depth-0.0036_c_double) > 1.0e-12_c_double) error stop 2

  status = rm13_management_state_c(revision,requested,allocated,supplied,net,rate)
  write(*,'(A,I0)') 'RM13_STATE_STATUS=',status
  if(status /= 0_c_int) error stop 3
  if(revision /= 0_c_int) error stop 4
  if(abs(requested-0.0036_c_double) > 1.0e-12_c_double) error stop 5

  write(*,'(A)') 'RM13_MANAGEMENT_INIT_SMOKE=PASS'
end program test_rm13_management_init_smoke
