! Controlled contact topology probe, not a replay of the complete Andelst DTO.
! Pressure heads and topology pair are from ANDELST_CONTACT_CAUSE.json.
! Remaining constitutive inputs are explicit synthetic controls, not fitted data.
program andelst_contact_driver
 use iso_fortran_env,only:real64
 use mod_ppa_wu05a6_unsat_absorption_rate,only:unsat_absorption_request_t, &
  unsat_absorption_result_t,evaluate_unsat_absorption
 implicit none
 type(unsat_absorption_request_t)::r
 type(unsat_absorption_result_t)::plus,minus
 integer::width,step,power
 real(real64)::eps,dt,jump,first_jump,fd,head
 head=-0.39024879013229613d0
 r%sorptivity%num_domains=1;r%sorptivity%num_nodes=28
 r%sorptivity%top_node=1;r%sorptivity%swmbf=1
 r%sorptivity%matrix_top_saturated_node=29
 r%sorptivity%perched_active=.true.;r%sorptivity%perched_bottom_node=27
 r%sorptivity%bottom_domain=[28];r%sorptivity%top_water_node=[1]
 r%sorptivity%theta=spread(0.3d0,1,28);r%sorptivity%theta_s=spread(0.45d0,1,28)
 r%sorptivity%theta_r=spread(0.05d0,1,28);r%sorptivity%dz=spread(1d0,1,28)
 r%sorptivity%diameter=spread(0.2d0,1,28);r%sorptivity%wall_correction=spread(1d0,1,28)
 r%sorptivity%sorptivity_max=spread(0d0,1,28);r%sorptivity%sorptivity_alpha=spread(1d0,1,28)
 r%sorptivity%domain_fraction=reshape(spread(0.01d0,1,28),[1,28])
 r%sorptivity%wet_fraction=reshape(spread(1d0,1,28),[1,28])
 r%sorptivity%history_sorptivity=reshape(spread(0d0,1,28),[1,28])
 r%sorptivity%history_theta_ref=reshape(spread(0.45d0,1,28),[1,28])
 r%sorptivity%history_absorption_time=reshape(spread(0d0,1,28),[1,28])
 r%pressure_head=spread(head,1,28);r%elevation=spread(-26d0,1,28)
 r%conductivity=spread(0.1d0,1,28);r%entry_head=spread(-0.1d0,1,28)
 r%groundwater_level_domain=[-25.8d0];r%sorp_fac_parallel=spread(1d0,1,28)
 do width=0,2
  r%entry_transition_width_cm=0d0
  if(width==1)r%entry_transition_width_cm=1d-4
  if(width==2)r%entry_transition_width_cm=1d-3
  do step=3,13,5
   dt=10d0**(-step);r%sorptivity%step_duration=dt
   first_jump=-1d0
   do power=4,10,2
    eps=10d0**(-power)
    r%pressure_head(26)=head+eps;r%sorptivity%perched_top_node=26
    call evaluate_unsat_absorption(r,plus)
    r%pressure_head(26)=head-eps;r%sorptivity%perched_top_node=27
    call evaluate_unsat_absorption(r,minus)
    if(.not.plus%valid.or..not.minus%valid)error stop 'contact request invalid'
    if(plus%selected_rate_cm_per_day(1,26)/=0d0)error stop 'perched exclusion changed'
    jump=minus%selected_rate_cm_per_day(1,26)-plus%selected_rate_cm_per_day(1,26)
    if(jump<0.118d0.or.jump>0.119d0)error stop 'missing finite contact jump'
    if(first_jump<0d0)first_jump=jump
    ! Head dependence contributes O(eps); no convergence to a finite derivative.
    if(abs(jump-first_jump)>3d-5)error stop 'jump unstable'
    fd=jump/(2d0*eps)
    if(abs(plus%selected_amount_cm(1,26))>0d0)error stop 'excluded transfer nonzero'
    if(abs(minus%selected_amount_cm(1,26)-dt*jump)>1d-15)error stop 'rate/amount mismatch'
    write(*,'(a,2(a,es25.17e3),a,i0,2(a,es25.17e3))') &
      'CONTACT',',',dt,',',eps,',',width,',',jump,',',fd
   end do
  end do
 end do
 print '(a)','CONTROLLED_CONTACT_TOPOLOGY_PASS_REPAIR_OPEN'
end program
