module mod_research_composed_fct
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 use mod_b111_solute_sorption
 use mod_research_storage_fct
 use mod_research_corrected_reactive,only:advance_research_corrected_reactive
 implicit none
 private
 public::advance_research_composed_fct
contains
 subroutine advance_research_composed_fct(m,s,f,enabled,next,next_s,r,correction_l1,applied_correction)
  type(mobile_salt_state_t),intent(in)::m
  type(solute_compartment_state_t),intent(in)::s
  type(b111_reactive_solute_substep_forcing_t),intent(in)::f
  logical,intent(in)::enabled
  type(mobile_salt_state_t),intent(out)::next
  type(solute_compartment_state_t),intent(out)::next_s
  type(b111_reactive_solute_substep_receipt_t),intent(out)::r
  real(real64),optional,intent(out)::correction_l1
  real(real64),allocatable,optional,intent(out)::applied_correction(:)
  type(b111_reactive_solute_substep_forcing_t)::advection
  type(mobile_salt_state_t)::high,low
  type(solute_compartment_state_t)::high_s,low_s
  type(b111_sorption_result_t)::bound
  real(real64),allocatable::anti(:),mass(:),upper(:),incoming(:),outgoing(:),rp(:),rm(:),delta(:)
  real(real64)::cmax,total,factor,transfer
  integer::n,i
  next=m;next_s=s;r=b111_reactive_solute_substep_receipt_t()
  if(present(correction_l1))correction_l1=0d0
  if(.not.enabled)then
   call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r,exact_empty_pond_limit=.true.);return
  end if
  if(.not.b111_reactive_forcing_valid(f))return
  if(present(applied_correction))applied_correction=0d0*f%theta
  if(all(f%decpot==0d0).and.all(f%dispersivity_cm==0d0).and.f%molecular_diffusion_cm2_day==0d0)then
   call advance_research_storage_fct(m,s,f,.true.,next,next_s,r);return
  end if
  advection=f;advection%decpot=0d0;advection%dispersivity_cm=0d0;advection%molecular_diffusion_cm2_day=0d0
  call advance_research_storage_fct(m,s,advection,.true.,high,high_s,r)
  if(r%status/=B111_REACTIVE_OK)return
  call advance_b111_reactive_solute_substep(m,s,advection,low,low_s,r,exact_empty_pond_limit=.true.)
  if(r%status/=B111_REACTIVE_OK)return
  r%status=B111_REACTIVE_INVALID;n=size(f%theta)
  allocate(anti(n-1),upper(n),incoming(n),outgoing(n),rp(n),rm(n),delta(n))
  mass=m%mass_mg_cm2+s%sorbed_matrix_mass
  delta=high%mass_mg_cm2+high_s%sorbed_matrix_mass-low%mass_mg_cm2-low_s%sorbed_matrix_mass
  total=0d0
  do i=1,n-1
   total=total+delta(i);anti(i)=-total
  end do
  cmax=max(maxval(m%concentration_mg_cm3),f%rain_c_mg_cm3)
  do i=1,n
   call b111_sorption_storage_from_concentration(f%theta_previous(i),f%bulk_density(i),f%kf(i), &
    f%cref_mg_cm3,f%frexp,cmax,bound)
   if(bound%status/=B111_SORP_OK)return
   upper(i)=bound%total_density*f%dz_cm(i)
  end do
  incoming=0d0;outgoing=0d0
  do i=1,n-1
   outgoing(i)=outgoing(i)+max(anti(i),0d0);incoming(i+1)=incoming(i+1)+max(anti(i),0d0)
   incoming(i)=incoming(i)+max(-anti(i),0d0);outgoing(i+1)=outgoing(i+1)+max(-anti(i),0d0)
  end do
  rp=1d0;rm=1d0
  do i=1,n
   if(outgoing(i)>mass(i))rm(i)=mass(i)/outgoing(i)
   if(incoming(i)>max(0d0,upper(i)-mass(i)))rp(i)=max(0d0,upper(i)-mass(i))/incoming(i)
  end do
  delta=0d0
  do i=1,n-1
   if(anti(i)>=0d0)then
    factor=min(rm(i),rp(i+1))
   else
    factor=min(rp(i),rm(i+1))
   end if
   transfer=anti(i)*factor*(1d0-16d0*epsilon(1d0))
   delta(i)=delta(i)-transfer;delta(i+1)=delta(i+1)+transfer
  end do
  call advance_research_corrected_reactive(m,s,f,next,next_s,r,exact_empty_pond_limit=.true.,mass_correction=delta)
  if(r%status/=B111_REACTIVE_OK)then
   next=m;next_s=s;return
  end if
  if(present(correction_l1))correction_l1=sum(abs(delta))
  if(present(applied_correction))applied_correction=delta
 end subroutine
end module
