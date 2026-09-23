program test_difficulty_p0d_descriptors
 use, intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_difficulty_pretrial_descriptors
 implicit none
 type(soil_water_parameter_set_t),target::p
 type(soil_water_solve_request_t)::q
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::ch
 type(difficulty_pretrial_descriptors_t)::a,b
 real(real64)::cf(24,3),h0(3),th(3),k(3),c(3),dk(3)
 cf=0; cf(1,:)=[0.05_real64,0.05_real64,0.05_real64]; cf(2,:)=0.45; cf(3,:)=50.0
 cf(4,:)=0.02; cf(5,:)=0.5; cf(6,:)=2.0; cf(7,:)=-0.5; cf(8,:)=0.0; cf(9,:)=-1e5
 call initialize_b110_default_mvg_parameters(hp,cf); call bind_b110_default_mvg_provider(ch,hp,0.1_real64)
 p%active_nodes=3; allocate(p%z(3),p%dz(3),p%node_distance(3)); p%z=[-1.,-3.,-6.]; p%dz=[2.,2.,3.]; p%node_distance=[2.,3.,3.]
 q%parameters=>p; q%evaluation%constitutive=>ch; q%base_state%active_nodes=3
 allocate(q%base_state%pressure_head(3),q%base_state%water_content(3))
 q%base_state%pressure_head=[-10.,-100.,-20.]; h0=q%base_state%pressure_head
 call ch%evaluate(h0,th,k,c,dk); q%base_state%water_content=th; q%boundary%top_flux=-0.2
 call evaluate_difficulty_pretrial_descriptors(q,a)
 call require(a%available,'available'); call require(a%grad_h_max>0,'gradient'); call require(a%top_flux_ratio_available,'flux ratio')
 q%base_state%water_content=-999.0 ! descriptor authority is h + constitutive provider, not stale theta
 call evaluate_difficulty_pretrial_descriptors(q,b)
 call require(a%theta_min==b%theta_min.and.a%k_max==b%k_max,'constitutive authority')
 call require(all(q%base_state%pressure_head==h0),'non interference')
 write(*,'(A)') 'DIFFICULTY_P0D_PRETRIAL_ONLY=PASS'
 write(*,'(A)') 'DIFFICULTY_P0D_CONSTITUTIVE_AUTHORITY=PASS'
contains
 subroutine require(x,s); logical,intent(in)::x; character(len=*),intent(in)::s
 if(.not.x) then; write(*,*) 'FAIL ',s; error stop 1; endif
 end subroutine
end program
