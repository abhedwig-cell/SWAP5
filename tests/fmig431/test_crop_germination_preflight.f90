program test_crop_germination_preflight
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_crop_germination_preflight
 implicit none
 type(crop_germination_candidate_t) :: c
 integer :: status
 call propose_crop_germination(0,0d0,10d0,0d0,25d0,15d0,0d0,-500d0,-10d0,20d0,c,status)
 if(status/=CROP_GERM_OK.or..not.c%complete) error stop 'default germ'
 call propose_crop_germination(1,0d0,10d0,5d0,30d0,10d0,0d0,-500d0,-10d0,20d0,c,status)
 if(status/=CROP_GERM_OK.or.c%complete.or.abs(c%next_temperature_sum-5d0)>1d-12) error stop 'thermal day'
 call propose_crop_germination(1,5d0,10d0,5d0,30d0,10d0,0d0,-500d0,-10d0,20d0,c,status)
 if(status/=CROP_GERM_OK.or..not.c%complete.or.abs(c%next_temperature_sum-10d0)>1d-12) error stop 'thermal emergence'
 call propose_crop_germination(2,0d0,10d0,5d0,30d0,10d0,-100d0,-500d0,-10d0,20d0,c,status)
 if(status/=CROP_GERM_OK.or.abs(c%next_temperature_sum-5d0)>1d-12) error stop 'hydraulic optimum'
 call propose_crop_germination(2,0d0,10d0,5d0,30d0,10d0,-100d0,-10d0,-500d0,20d0,c,status)
 if(status/=CROP_GERM_INVALID.or.c%valid) error stop 'invalid hydraulic ordering'
 print '(a)','SW431_CROP_GERMINATION_READONLY=PASS'
end program
