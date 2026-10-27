program test_candidate_groundwater_view
 use iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:soil_water_physical_state_t
 use mod_macropore_standard_rate_adapter
 implicit none
 type(soil_water_physical_state_t)::matrix
 type(matrix_saturated_zone_view_t)::a,b
 real(real64)::z(3)=[-0.5_real64,-1.5_real64,-2.5_real64],dz(3)=1.0_real64
 matrix%active_nodes=3;matrix%pressure_head=[-0.2_real64,0.2_real64,0.4_real64]
 matrix%water_content=[0.4_real64,0.5_real64,0.5_real64]
 matrix%groundwater_level=-100
 call derive_candidate_matrix_saturated_zone_view(matrix,z,dz,a)
 call check(a%valid.and.a%active.and.a%top_node==2,'candidate crossing')
 call check(abs(a%groundwater_level_cm+1.0_real64)<1e-15_real64,'source interpolation')
 call check(matrix%groundwater_level==-100,'immutable source origin')
 matrix%groundwater_level=100
 call derive_candidate_matrix_saturated_zone_view(matrix,z,dz,b)
 call check(a%groundwater_level_cm==b%groundwater_level_cm.and.a%top_node==b%top_node,'accepted carrier independent')
 call derive_matrix_saturated_zone_view(matrix,z,dz,b)
 call check(b%active.and.b%top_node==1,'legacy accepted carrier retained')
 matrix%pressure_head=-1
 call derive_candidate_matrix_saturated_zone_view(matrix,z,dz,a)
 call check(a%valid.and..not.a%active,'typed below-profile absence')
 matrix%pressure_head=1
 call derive_candidate_matrix_saturated_zone_view(matrix,z,dz,a)
 call check(a%valid.and.a%active.and.a%top_node==1,'whole profile saturation')
 matrix%pressure_head=[-0.4_real64,0.2_real64,0.4_real64]
 call derive_candidate_matrix_saturated_zone_view(matrix,z,dz,a)
 call check(abs(a%groundwater_level_cm-(-1.5_real64+1.0_real64/3))<1e-15_real64,'current head change updates view')
 print *,'CANDIDATE_GROUNDWATER_VIEW_PASS'
contains
 subroutine check(ok,msg)
 logical,intent(in)::ok
 character(*),intent(in)::msg
 if(.not.ok)then
 print *,msg
 error stop 1
 end if
 end subroutine
end program
