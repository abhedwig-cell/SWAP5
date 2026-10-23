module mod_research_storage_fct
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 use mod_b111_solute_sorption
 implicit none
 private
 public::advance_research_storage_fct
contains
 pure real(real64) function mc(a,b,c) result(v)
  real(real64),intent(in)::a,b,c
  v=0d0
  if(min(a,b,c)>0d0)v=min(a,b,c)
  if(max(a,b,c)<0d0)v=max(a,b,c)
 end function
 subroutine advance_research_storage_fct(m,s,f,enabled,next,next_s,r)
  type(mobile_salt_state_t),intent(in)::m
  type(solute_compartment_state_t),intent(in)::s
  type(b111_reactive_solute_substep_forcing_t),intent(in)::f
  logical,intent(in)::enabled
  type(mobile_salt_state_t),intent(out)::next
  type(solute_compartment_state_t),intent(out)::next_s
  type(b111_reactive_solute_substep_receipt_t),intent(out)::r
  type(mobile_salt_state_t)::low,work
  type(solute_compartment_state_t)::low_s,work_s
  type(b111_sorption_result_t)::p
  real(real64),allocatable::q(:),slope(:),face(:),half(:),anti(:),mass(:),upper(:),incoming(:),outgoing(:),rp(:),rm(:)
  real(real64)::h,dt,cmax,amount,frac,transfer,factor,scale,closure,physical
  integer::n,i
  next=m;next_s=s;r=b111_reactive_solute_substep_receipt_t()
  if(.not.enabled)then
   call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r);return
  end if
  if(.not.b111_reactive_forcing_valid(f).or..not.s%valid())return
  n=size(f%theta);if(n<3)return
  if(f%transport_scheme/=B111_TRANSPORT_IMPLICIT_UPWIND.or.f%frexp<.5d0.or.f%frexp>2d0)return
  if(.not.allocated(f%theta_previous))return
  if(any(f%dz_cm/=f%dz_cm(1)).or.any(f%bulk_density/=f%bulk_density(1)).or.any(f%kf/=f%kf(1)))return
  if(any(f%q_face_up_cm_day>0d0))return
  if(any(f%root_sink_cm_day/=0d0).or.any(f%qdra_cm_day/=0d0).or.any(f%decpot/=0d0))return
  if(any(f%dispersivity_cm/=0d0).or.f%molecular_diffusion_cm2_day/=0d0)return
  if(any([s%pond_mass,s%aquifer_mass,s%age_pond_previous_concentration]/=0d0).or.any(s%age_amount/=0d0))return
  if(any([f%irrigation_rate_cm_day,f%runon_rate_cm_day,f%macropore_area_fraction,f%pond_end_cm,f%runoff_depth_cm]/=0d0))return
  q=-f%q_face_up_cm_day;dt=f%dt_day;h=f%dz_cm(1)
  if(f%rain_rate_cm_day/=q(1))return
  if(any(abs((f%theta-f%theta_previous)*h-dt*(q(:n)-q(2:)))> &
   2048d0*epsilon(1d0)*max(1d0,h,maxval(dt*q))))return
  if(any(dt*q(2:)>min(f%theta,f%theta_previous)*h))return
  call advance_b111_reactive_solute_substep(m,s,f,low,low_s,r)
  if(r%status/=B111_REACTIVE_OK)return
  ! All subsequent work is private: a late failure cannot publish the low state.
  r%status=B111_REACTIVE_INVALID
  allocate(slope(n),face(n+1),half(n),anti(n-1),mass(n),upper(n),incoming(n),outgoing(n),rp(n),rm(n))
  slope=0d0
  do i=2,n-1
   slope(i)=mc(2d0*(m%concentration_mg_cm3(i)-m%concentration_mg_cm3(i-1)), &
    .5d0*(m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i-1)), &
    2d0*(m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i)))
  end do
  face(1)=q(1)*f%rain_c_mg_cm3
  face(2:)=q(2:)*(m%concentration_mg_cm3+.5d0*slope)
  do i=1,n
   amount=m%mass_mg_cm2(i)+s%sorbed_matrix_mass(i)+.5d0*dt*(face(i)-face(i+1))
   if(amount<0d0)return
   call b111_sorption_partition_total(.5d0*(f%theta(i)+f%theta_previous(i)),f%bulk_density(i),f%kf(i), &
    f%cref_mg_cm3,f%frexp,amount/h,m%concentration_mg_cm3(i),p)
   if(p%status/=B111_SORP_OK)then
    r%status=B111_REACTIVE_PARTITION;return
   end if
   half(i)=p%concentration
  end do
  anti=dt*q(2:n)*(half(:n-1)+.5d0*slope(:n-1)-low%concentration_mg_cm3(:n-1))
  mass=low%mass_mg_cm2+low_s%sorbed_matrix_mass
  cmax=max(maxval(m%concentration_mg_cm3),f%rain_c_mg_cm3)
  do i=1,n
   call b111_sorption_storage_from_concentration(f%theta(i),f%bulk_density(i),f%kf(i), &
    f%cref_mg_cm3,f%frexp,cmax,p)
   if(p%status/=B111_SORP_OK)return
   upper(i)=h*p%total_density
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
  do i=1,n-1
   if(anti(i)>=0d0)then
    factor=min(rm(i),rp(i+1))
   else
    factor=min(rp(i),rm(i+1))
   end if
   transfer=anti(i)*factor*(1d0-16d0*epsilon(1d0))
   mass(i)=mass(i)-transfer;mass(i+1)=mass(i+1)+transfer
  end do
  work=low;work_s=low_s
  do i=1,n
   if(mass(i)<0d0)then
    r%status=B111_REACTIVE_NEGATIVE;return
   end if
   call b111_sorption_partition_total(f%theta(i),f%bulk_density(i),f%kf(i),f%cref_mg_cm3, &
    f%frexp,mass(i)/h,low%concentration_mg_cm3(i),p)
   if(p%status/=B111_SORP_OK)then
    r%status=B111_REACTIVE_PARTITION;return
   end if
   frac=0d0
   if(p%total_density>0d0)frac=p%dissolved_density/p%total_density
   if(f%bulk_density(i)*f%kf(i)==0d0)frac=1d0
   work%mass_mg_cm2(i)=mass(i)*frac
   work_s%sorbed_matrix_mass(i)=mass(i)-work%mass_mg_cm2(i)
   work%concentration_mg_cm3(i)=work%mass_mg_cm2(i)/(f%theta(i)*h)
   call b111_sorption_storage_from_concentration(f%theta(i),f%bulk_density(i),f%kf(i),f%cref_mg_cm3, &
    f%frexp,work%concentration_mg_cm3(i),p)
   if(p%status/=B111_SORP_OK)return
   physical=p%sorbed_density*h
   if(abs(physical-work_s%sorbed_matrix_mass(i))>2048d0*epsilon(1d0)*max(1d0,physical,work_s%sorbed_matrix_mass(i)))then
    r%status=B111_REACTIVE_STATE_MISMATCH;return
   end if
   if(work%concentration_mg_cm3(i)>cmax+2048d0*epsilon(1d0)*max(1d0,cmax))then
    r%status=B111_REACTIVE_NEGATIVE;return
   end if
  end do
  scale=max(1d0,r%mass_before_mg_cm2,r%mass_after_mg_cm2)
  closure=sum(mass)-r%mass_before_mg_cm2-r%external_input_mg_cm2+r%external_output_mg_cm2
  if(abs(closure)>8192d0*epsilon(1d0)*scale)then
   r%status=B111_REACTIVE_BALANCE;return
  end if
  next=work;next_s=work_s
  r%mass_after_mg_cm2=sum(next%mass_mg_cm2)+next_s%solute_total()
  r%balance_residual_mg_cm2=r%mass_after_mg_cm2-r%mass_before_mg_cm2-r%external_input_mg_cm2+r%external_output_mg_cm2
  r%status=B111_REACTIVE_OK
 end subroutine
end module
