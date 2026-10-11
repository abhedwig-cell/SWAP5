program test_crop_b111_sowing_node
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_crop_b111_sowing_node
 implicit none
 real(real64),parameter:: grid(3)=[-10.0_real64,-20.0_real64,-40.0_real64]
 integer :: node,status
 call b111_sowing_temperature_node(-15.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_OK.or.node/=2) error stop 1
 call b111_sowing_temperature_node(-10.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_OK.or.node/=1) error stop 2
 call b111_sowing_temperature_node(-20.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_OK.or.node/=2) error stop 3
 call b111_sowing_temperature_node(-40.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_OK.or.node/=3) error stop 4
 call b111_sowing_temperature_node(-41.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_OUTSIDE.or.node/=0) error stop 5
 call b111_sowing_temperature_node(-15.0_real64,[-10.0_real64,-10.0_real64],node,status)
 if(status/=CROP_SOW_NODE_INVALID) error stop 6
 call b111_sowing_temperature_node(-15.0_real64,[-20.0_real64,-10.0_real64],node,status)
 if(status/=CROP_SOW_NODE_INVALID) error stop 7
 call b111_sowing_temperature_node(1.0_real64,grid,node,status)
 if(status/=CROP_SOW_NODE_INVALID) error stop 8
 call b111_sowing_temperature_node(-15.0_real64,[real(real64)::],node,status)
 if(status/=CROP_SOW_NODE_INVALID) error stop 9
 print '(a)','B111_SOWING_NODE=PASS'
end program
