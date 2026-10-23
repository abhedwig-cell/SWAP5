module mod_research_fct
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 private
 public::advance_research_fct
contains
 pure real(real64) function minmod(a,b,c) result(v)
  real(real64),intent(in)::a,b,c
  v=0d0
  if(min(a,b,c)>0d0)v=min(a,b,c)
  if(max(a,b,c)<0d0)v=max(a,b,c)
 end function
 subroutine advance_research_fct(m,s,f,enabled,next,next_s,r)
  type(mobile_salt_state_t),intent(in)::m
  type(solute_compartment_state_t),intent(in)::s
  type(b111_reactive_solute_substep_forcing_t),intent(in)::f
  logical,intent(in)::enabled
  type(mobile_salt_state_t),intent(out)::next
  type(solute_compartment_state_t),intent(out)::next_s
  type(b111_reactive_solute_substep_receipt_t),intent(out)::r
  type(mobile_salt_state_t)::low
  type(solute_compartment_state_t)::low_s
  real(real64),allocatable::slope(:),anti(:),mass(:),incoming(:),outgoing(:),rp(:),rm(:),c(:)
  real(real64)::storage,h,q,cfl,upper,transfer,factor,scale,closure
  integer::i,n
  if(.not.enabled)then
   call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r);return
  end if
  next=m;next_s=s;r=b111_reactive_solute_substep_receipt_t()
  if(.not.b111_reactive_forcing_valid(f).or..not.s%valid())return
  n=size(f%theta);if(n<3)return
  if(f%transport_scheme/=B111_TRANSPORT_IMPLICIT_UPWIND.or.f%frexp/=1d0)return
  if(.not.allocated(f%theta_previous))return
  if(any(f%theta_previous/=f%theta).or.any(f%theta/=f%theta(1)))return
  if(any(f%dz_cm/=f%dz_cm(1)).or.any(f%bulk_density/=f%bulk_density(1)).or.any(f%kf/=f%kf(1)))return
  if(any(f%q_face_up_cm_day/=f%q_face_up_cm_day(1)).or.f%q_face_up_cm_day(1)>=0d0)return
  if(any(f%root_sink_cm_day/=0d0).or.any(f%qdra_cm_day/=0d0).or.any(f%decpot/=0d0))return
  if(any(f%dispersivity_cm/=0d0).or.f%molecular_diffusion_cm2_day/=0d0)return
  if(any([s%pond_mass,s%aquifer_mass,s%age_pond_previous_concentration]/=0d0).or.any(s%age_amount/=0d0))return
  q=-f%q_face_up_cm_day(1)
  if(f%rain_rate_cm_day/=q.or.f%rain_c_mg_cm3/=0d0)return
  if(any([f%irrigation_rate_cm_day,f%runon_rate_cm_day,f%macropore_area_fraction,f%pond_end_cm,f%runoff_depth_cm]/=0d0))return
  storage=f%theta(1)+f%bulk_density(1)*f%kf(1);h=f%dz_cm(1)
  cfl=q*f%dt_day/(storage*h);if(cfl>1d0)return
  call advance_b111_reactive_solute_substep(m,s,f,low,low_s,r)
  if(r%status/=B111_REACTIVE_OK)return
  allocate(slope(n),anti(n-1),mass(n),incoming(n),outgoing(n),rp(n),rm(n),c(n))
  slope=0d0
  do i=2,n-1
   slope(i)=minmod(2d0*(m%concentration_mg_cm3(i)-m%concentration_mg_cm3(i-1)), &
    .5d0*(m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i-1)), &
    2d0*(m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i)))
  end do
  anti=f%dt_day*q*(m%concentration_mg_cm3(:n-1)+.5d0*(1d0-cfl)*slope(:n-1)-low%concentration_mg_cm3(:n-1))
  mass=low%mass_mg_cm2+low_s%sorbed_matrix_mass
  incoming=0d0;outgoing=0d0
  do i=1,n-1
   outgoing(i)=outgoing(i)+max(anti(i),0d0);incoming(i+1)=incoming(i+1)+max(anti(i),0d0)
   incoming(i)=incoming(i)+max(-anti(i),0d0);outgoing(i+1)=outgoing(i+1)+max(-anti(i),0d0)
  end do
  upper=storage*h*maxval(m%concentration_mg_cm3)
  rp=1d0;rm=1d0
  do i=1,n
   ! Divide only when the result is <=1. Extremely small face corrections
   ! otherwise overflow a ratio that would immediately be truncated to one.
   if(outgoing(i)>mass(i))rm(i)=mass(i)/outgoing(i)
   if(incoming(i)>max(0d0,upper-mass(i)))rp(i)=max(0d0,upper-mass(i))/incoming(i)
  end do
  do i=1,n-1
   if(anti(i)>=0d0)then
    factor=min(rm(i),rp(i+1))
   else
    factor=min(rp(i),rm(i+1))
   end if
   ! Reserve only roundoff in the flux budget; never clip a physical stock.
   transfer=anti(i)*factor*(1d0-16d0*epsilon(1d0))
   mass(i)=mass(i)-transfer;mass(i+1)=mass(i+1)+transfer
  end do
  c=mass/(storage*h)
  scale=max(1d0,r%mass_before_mg_cm2,r%mass_after_mg_cm2)
  closure=sum(mass)-r%mass_before_mg_cm2-r%external_input_mg_cm2+r%external_output_mg_cm2
  if(any(mass<0d0).or.any(c>maxval(m%concentration_mg_cm3)+128d0*epsilon(1d0)))then
   r%status=B111_REACTIVE_NEGATIVE;return
  end if
  if(abs(closure)>8192d0*epsilon(1d0)*scale)then
   r%status=B111_REACTIVE_BALANCE;return
  end if
  next=low;next_s=low_s
  next%mass_mg_cm2=mass*(f%theta/storage);next_s%sorbed_matrix_mass=mass-next%mass_mg_cm2
  next%concentration_mg_cm3=next%mass_mg_cm2/(f%theta*h)
  r%mass_after_mg_cm2=sum(next%mass_mg_cm2)+next_s%solute_total()
  r%balance_residual_mg_cm2=r%mass_after_mg_cm2-r%mass_before_mg_cm2-r%external_input_mg_cm2+r%external_output_mg_cm2
 end subroutine
end module
