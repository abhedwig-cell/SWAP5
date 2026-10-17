program test_surface_loss_sweep
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_surface_loss_budget
 implicit none
 type(surface_loss_receipt_t)::r
 real(real64)::d,m,p,i,f,e,q,dt,c1,c2,dry,water,before
 integer::k,j,count
 count=0
 do k=0,39
  d=real(mod(k,9),real64)*0.25d0
  m=real(mod(k*13,29),real64)*0.17d0
  dt=0.1d0+real(mod(k,7),real64)*0.11d0
  p=real(mod(k*3,17),real64)*0.1d0
  i=real(mod(k*7,13),real64)*0.1d0
  water=d+(p+i)*dt
  f=water/dt*real(mod(k,5),real64)*0.10d0
  e=water/dt*real(mod(k,3),real64)*0.05d0
  q=water/dt*real(mod(k,4),real64)*0.05d0
  c1=0.05d0*real(mod(k,11),real64)
  c2=0.07d0*real(mod(k,7),real64)
  dry=0.03d0*real(mod(k,6),real64)
  call evaluate_surface_loss_budget(d,m,dt,p,i,f,e,q,c1,c2,dry,r)
  if(r%status/=SURFACE_LOSS_OK)error stop 'sweep status'
  if(abs(r%water_residual)>1d-10)error stop 'sweep water'
  if(abs(r%mass_residual)>1d-10)error stop 'sweep mass'
  if(min(r%mass_end,r%runoff_mass,r%infiltrated_mass)<0d0)error stop 'negative mass'
  before=m+r%external_mass
  if(r%mass_end>before+1d-10)error stop 'mass creation'
  count=count+1
 end do
 do j=1,3
  select case(j)
   case(1)
    call evaluate_surface_loss_budget(1d0,1d0,-1d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,r)
   case(2)
    call evaluate_surface_loss_budget(1d0,1d0,1d0,0d0,0d0,0d0,0d0,-1d0,0d0,0d0,0d0,r)
   case(3)
    call evaluate_surface_loss_budget(ieee_value(1d0,ieee_quiet_nan),1d0,1d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,r)
  end select
  if(r%status/=SURFACE_LOSS_INVALID)error stop 'invalid accepted'
 end do
 print '(a,i0)','SURFACE_LOSS_SWEEP_PASS=',count
end program
