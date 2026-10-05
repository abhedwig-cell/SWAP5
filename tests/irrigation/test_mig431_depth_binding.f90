program test_mig431_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_irrigation_depth_binding
  implicit none
  integer :: first,last,status
  real(real64), parameter :: bottom(3) = [-10.0_real64,-20.0_real64,-30.0_real64]
  call bind_irrigation_depth_to_nodes(bottom,-15.0_real64,-15.0_real64,first,last,status)
  if (status /= IRRIGATION_DEPTH_BIND_OK .or. first /= 2 .or. last /= 2) error stop 1
  call bind_irrigation_depth_to_nodes(bottom,-5.0_real64,-25.0_real64,first,last,status)
  if (status /= IRRIGATION_DEPTH_BIND_OK .or. first /= 1 .or. last /= 3) error stop 2
  call bind_irrigation_depth_to_nodes(bottom,-25.0_real64,-5.0_real64,first,last,status)
  if (status /= IRRIGATION_DEPTH_BIND_INVALID .or. first /= 0 .or. last /= 0) error stop 3
  call bind_irrigation_depth_to_nodes(bottom,-5.0_real64,-35.0_real64,first,last,status)
  if (status /= IRRIGATION_DEPTH_BIND_INVALID) error stop 4
  print '(a)', 'F_MIG431_SSDI_DEPTH_NODE_BINDING=PASS'
end program
