program test_transport_spatial_positivity
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 type(mobile_salt_state_t)::m,next
 type(solute_compartment_state_t)::s,next_s
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b111_reactive_solute_substep_receipt_t)::r
 real(real64)::width,dt,before
 integer::grid,power,code
 do grid=1,2
  width=merge(10d0,1d0,grid==1)
  do power=1,4
   dt=10d0**(-power)
   call initialize_mobile_salt_state([width,width],[.2d0,.2d0],[1d0,0d0],m,code)
   if(code/=SOLUTE_OK)error stop 1
   call initialize_solute_compartment_state([0d0,0d0],0d0,0d0,[0d0,0d0],s,code)
   if(code/=SOLCOMP_OK)error stop 1
   f=b111_reactive_solute_substep_forcing_t()
   f%dt_day=dt;f%dz_cm=[width,width];f%theta_previous=[.2d0,.2d0]
   f%theta=[.2d0+.1d0*dt/width,.2d0-.1d0*dt/width]
   f%q_face_up_cm_day=[0d0,.1d0,0d0];f%root_sink_cm_day=[0d0,0d0]
   allocate(f%qdra_cm_day(0,2))
   f%temperature_c=[20d0,20d0];f%gampar=[0d0,0d0];f%rtheta=[.2d0,.2d0]
   f%bexp=[1d0,1d0];f%decpot=[0d0,0d0];f%fdepth=[1d0,1d0]
   f%bulk_density=[1.3d0,1.3d0];f%kf=[0d0,0d0];f%frexp=1d0;f%cref_mg_cm3=1d0
   f%face_distance_cm=[width];f%face_left_weight=[.5d0];f%face_right_weight=[.5d0]
   f%theta_sat_left=[.4d0];f%dispersivity_cm=[1d0];f%molecular_diffusion_cm2_day=0d0
   before=sum(m%mass_mg_cm2)+s%solute_total()
   call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
   if(any(m%concentration_mg_cm3/=[1d0,0d0]).or.any(m%mass_mg_cm2/=[.2d0*width,0d0]))error stop 2
   if(grid==1)then
    if(r%status/=B111_REACTIVE_NEGATIVE)error stop 3
    if(any(next%mass_mg_cm2/=m%mass_mg_cm2).or.next_s%solute_total()/=s%solute_total())error stop 4
   else
    if(r%status/=B111_REACTIVE_OK.or.any(next%mass_mg_cm2<0d0))error stop 5
    if(abs(sum(next%mass_mg_cm2)+next_s%solute_total()-before)>1d-13)error stop 6
   end if
   print *, 'SPATIAL',grid,dt,r%status
  end do
 end do
 print '(A)','TRANSPORT_SPATIAL_NEGATIVE_NOT_FIXED_BY_SMALL_DT_RESOLVED_MASS_PASS'
end program
