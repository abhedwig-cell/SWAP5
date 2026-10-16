program test_crop_b110_grid_sowing_preflight
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_crop_b110_grid_sowing_preflight
 implicit none
 real(real64),parameter:: dz(3)=[10.0_real64,20.0_real64,30.0_real64]
 real(real64),parameter:: z(3)=[-5.0_real64,-20.0_real64,-45.0_real64]
 integer :: node,status
 call preflight_b110_grid_sowing_node(-25.0_real64,z,dz,node,status)
 if(status/=CROP_GRID_SOW_OK.or.node/=2) error stop 1
 call preflight_b110_grid_sowing_node(-20.0_real64,z,dz,node,status)
 if(status/=CROP_GRID_SOW_OK.or.node/=2) error stop 2
 call preflight_b110_grid_sowing_node(-60.0_real64,z,dz,node,status)
 if(status/=CROP_GRID_SOW_OK.or.node/=3) error stop 3
 call preflight_b110_grid_sowing_node(-61.0_real64,z,dz,node,status)
 if(status/=CROP_GRID_SOW_OUTSIDE.or.node/=0) error stop 4
 call preflight_b110_grid_sowing_node(-25.0_real64,z,[20.0_real64,10.0_real64,30.0_real64],node,status)
 if(status/=CROP_GRID_SOW_INVALID.or.node/=0) error stop 5
 call preflight_b110_grid_sowing_node(-25.0_real64,z+1.0_real64,dz,node,status)
 if(status/=CROP_GRID_SOW_INVALID.or.node/=0) error stop 6
 call preflight_b110_grid_sowing_node(-25.0_real64,z,dz(:2),node,status)
 if(status/=CROP_GRID_SOW_INVALID.or.node/=0) error stop 7
 call preflight_b110_grid_sowing_node(1.0_real64,z,dz,node,status)
 if(status/=CROP_GRID_SOW_OUTSIDE.or.node/=0) error stop 8
 print '(a)','SW431_CROP_B110_GRID_SOW_PREFLIGHT=PASS'
end program
