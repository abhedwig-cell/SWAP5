program test_crop_preparation_sowing_preflight
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_preparation_sowing_preflight
  implicit none
  type(crop_preparation_sowing_candidate_t) :: a
  integer :: status
  call propose_preparation_sowing(0,0,.false.,0d0,0d0,0d0,0d0,0d0,0d0,0,0,3,3,a,status)
  if(status/=CROP_PREP_SOW_OK.or..not.a%preparation_complete.or..not.a%sowing_complete) error stop 'default'
  call propose_preparation_sowing(1,1,.true.,-100d0,-120d0,-40d0,-100d0,4d0,8d0,0,0,2,3,a,status)
  if(status/=CROP_PREP_SOW_OK.or..not.a%blocked_preparation.or.a%next_preparation_delay/=1) error stop 'prep block'
  if(a%sowing_complete) error stop 'premature sow'
  call propose_preparation_sowing(1,1,.true.,-100d0,-120d0,-40d0,-100d0,4d0,8d0,2,0,2,3,a,status)
  if(status/=CROP_PREP_SOW_OK.or..not.a%preparation_complete.or..not.a%blocked_sowing) error stop 'sow block'
  if(a%next_sowing_delay/=3) error stop 'prep inherited delay'
  call propose_preparation_sowing(1,1,.true.,-100d0,-120d0,-40d0,-100d0,4d0,8d0,2,0,2,3,a,status)
  if(a%next_sowing_delay/=3) error stop 'determinism'
  call propose_preparation_sowing(0,1,.false.,0d0,0d0,0d0,0d0,0d0,0d0,0,0,2,3,a,status)
  if(status/=CROP_PREP_SOW_INVALID.or.a%valid) error stop 'missing heat'
  print '(a)','SW431_CROP_PREP_SOW_READONLY=PASS'
end program
