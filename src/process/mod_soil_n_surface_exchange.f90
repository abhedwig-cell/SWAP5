! Call-local composition of existing surface physics. No persistent owner.
module mod_soil_n_surface_exchange
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_persistent_pond
 implicit none
 private
 type,public::soil_n_surface_day_t
  type(pond_step_t),allocatable::steps(:)
 end type
 type,public::soil_n_surface_receipt_t
  integer::status=1
  real(real64)::before(2)=0d0,after(2)=0d0,input(2)=0d0,infiltrated(2)=0d0,runoff(2)=0d0
  real(real64)::infiltration_m=0d0,max_water_residual_m=0d0,residual(2)=0d0
 end type
 public::evaluate_soil_n_surface_day
contains
 subroutine evaluate_soil_n_surface_day(before,ctop,t0,t1,forcing,r)
  real(real64),intent(in)::before(2),ctop(2),t0,t1
  type(soil_n_surface_day_t),intent(in)::forcing
  type(soil_n_surface_receipt_t),intent(out)::r
  type(persistent_pond_state_t)::state(2),next
  type(persistent_pond_receipt_t)::one
  type(pond_step_t)::step
  real(real64)::clock,depth,amount,dt
  integer(int64)::revision
  integer::i,k,code
  r=soil_n_surface_receipt_t()
  if(.not.all(ieee_is_finite([before,ctop,t0,t1])))return
  if(minval(before)<0d0.or.maxval(before)>100d0.or.minval(ctop)<0d0.or.maxval(ctop)>1d6)return
  if(abs(t1-t0-1d0)>0d0.or..not.allocated(forcing%steps))return
  if(size(forcing%steps)<1.or.size(forcing%steps)>100000)return
  if(forcing%steps(1)%t0/=t0.or.forcing%steps(size(forcing%steps))%t1/=t1)return
  do i=1,2
   call initialize_persistent_pond(t0,forcing%steps(1)%depth_begin,before(i)*100d0,state(i),code)
   if(code/=POND_OK)return
  end do
  r%before=before
  do k=1,size(forcing%steps)
   step=forcing%steps(k)
   ! Source concentrations come only from immutable historical parameters.
   if(step%rain_c/=0d0.or.step%irrigation_c/=0d0.or.step%runon_c/=0d0.or.step%dry_deposition_rate/=0d0)return
   dt=step%t1-step%t0
   if(.not.ieee_is_finite(dt))return
   if(dt<=0d0.or.dt>1d0)return
   if(.not.ieee_is_finite(step%qtop))return
   if(step%qtop>0d0.or.step%qtop< -1d4)return
   r%infiltration_m=r%infiltration_m-step%qtop*dt*.01d0
   do i=1,2
    step%rain_c=ctop(i);step%irrigation_c=ctop(i);step%runon_c=ctop(i)
    call advance_persistent_pond(state(i),step,next,one)
    if(one%status/=POND_OK)return
    r%input(i)=r%input(i)+(one%rain_input+one%irrigation_input+one%runon_input)/100d0
    r%infiltrated(i)=r%infiltrated(i)+one%soil_transfer/100d0
    r%runoff(i)=r%runoff(i)+one%runoff_output/100d0
    r%max_water_residual_m=max(r%max_water_residual_m,abs(one%water_residual)*.01d0)
    state(i)=next
   end do
  end do
  do i=1,2
   call state(i)%snapshot(clock,depth,amount,revision)
   r%after(i)=amount/100d0
  end do
  if(maxval(r%after)>100d0.or.r%infiltration_m>100d0)return
  r%residual=r%after+r%infiltrated+r%runoff-r%before-r%input
  if(maxval(abs(r%residual))>1d-12)return
  r%status=0
 end subroutine
end module
