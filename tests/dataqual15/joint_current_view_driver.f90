program joint_current_view_driver
 use iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:soil_water_physical_state_t
 use mod_macropore_standard_rate_adapter,only:matrix_saturated_zone_view_t,derive_matrix_saturated_zone_view
 implicit none
 type(soil_water_physical_state_t)::matrix
 type(matrix_saturated_zone_view_t)::view
 real(real64)::z(4)=[-.5d0,-1.5d0,-2.5d0,-3.5d0],dz(4)=1d0
 matrix%active_nodes=4;matrix%pressure_head=[-1d0,1d0,-.2d0,1d0]
 matrix%water_content=[.3d0,.4d0,.3d0,.4d0];matrix%ponding_depth=0d0
 matrix%groundwater_level=777d0
 call derive_matrix_saturated_zone_view(matrix,z,dz,view)
 if(.not.view%valid.or..not.view%active.or.view%top_node/=3)error stop 'lagged groundwater view'
 if(abs(view%groundwater_level_cm-(-3.5d0+1d0/1.2d0))>1d-14)error stop 'current CALCGWL projection'
 if(matrix%groundwater_level/=777d0)error stop 'derived view mutated physical state'
 matrix%pressure_head=-1d0
 call derive_matrix_saturated_zone_view(matrix,z,dz,view)
 if(.not.view%valid.or.view%active.or.view%bottom_node/=0)error stop 'typed absent groundwater'
 matrix%pressure_head=1d0;matrix%ponding_depth=.2d0
 call derive_matrix_saturated_zone_view(matrix,z,dz,view)
 if(.not.view%valid.or..not.view%active.or.view%top_node/=1.or.view%groundwater_level_cm/=.2d0) &
   error stop 'fully saturated current projection'
 print '(a)','CURRENT_PROFILE_GROUNDWATER_VIEW_AND_ABSENCE_PASS'
end program
