program test_swap431_root_anaerobic_gate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_anaerobic_extension_gate
  implicit none
  logical :: allowed
  integer :: status

  call root_extension_allowed_by_daily_oxygen(.false.,0.0_real64,0.7_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or..not.allowed) error stop 1

  call root_extension_allowed_by_daily_oxygen(.true.,0.69_real64,0.7_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or.allowed) error stop 2

  ! Source uses strict '<'; equality does not stop extension.
  call root_extension_allowed_by_daily_oxygen(.true.,0.7_real64,0.7_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or..not.allowed) error stop 3

  call root_extension_allowed_by_daily_oxygen(.true.,1.0_real64,0.7_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or..not.allowed) error stop 4

  print '(a)','SW431_ROOT_ANAE_GROW_GATE=PASS'
end program
