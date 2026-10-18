! Exact no-inflow/no-liquid-outflow evaporation counterexample, not a Richards run.
program dry_limit
 use iso_fortran_env,only:real64,int64
 use mod_b111_surface_age_owner
 use mod_b111_surface_age_budget
 implicit none
 type(surface_age_owner_t)::s,next
 type(surface_age_request_t)::q
 type(surface_age_receipt_t)::r
 real(real64)::t,h,m,exact,delta,remaining,age,oldage
 integer(int64)::rev
 integer::status,i
 logical::ok
 call initialize_surface_age_owner(8801_int64,0d0,.5d0,3d0,s,status)
 if(status/=AGE_OWNER_OK)error stop 'initialize'
 oldage=3d0
 do i=1,6
  call snapshot_surface_age_owner(s,t,h,m,rev,ok)
  remaining=.5d0*10d0**(-i)
  delta=h-remaining
  q=surface_age_request_t();q%dt_day=delta
  q%pond_start_cm=h;q%pond_end_cm=remaining;q%evaporation_depth_cm=delta
  call advance_surface_age_owner(s,q,next,r,status)
  if(status/=AGE_OWNER_OK)error stop 'positive residual water'
  s=next
  call snapshot_surface_age_owner(s,t,h,m,rev,ok)
  ! h(t)=0.5-t, E=1: M(t)=1.5+0.5t-t^2/2, exact trapezoidal source.
  exact=1.5d0+.5d0*t-.5d0*t*t
  if(abs(m-exact)>8192*epsilon(1d0)*max(1d0,exact))error stop 'exact nonvolatile moment'
  age=m/h
  if(age<=oldage)error stop 'divergent mean as depth tends to zero'
  oldage=age
  print '(A,4ES24.15)','EVAPORATION_LIMIT ',t,h,m,age
 end do
 call snapshot_surface_age_owner(s,t,h,m,rev,ok)
 q=surface_age_request_t();q%dt_day=h;q%pond_start_cm=h;q%evaporation_depth_cm=h
 call advance_surface_age_owner(s,q,next,r,status)
 if(status==AGE_OWNER_OK)error stop 'undefined complete dry state accepted'
 block
  real(real64)::tt,hh,mm
  integer(int64)::rr
  call snapshot_surface_age_owner(next,tt,hh,mm,rr,ok)
  if(any([tt,hh,mm]/=[t,h,m]).or.rr/=rev.or..not.ok)error stop 'rejected candidate changed'
 end block
 print '(A)','COMPLETE_DRY_LIMIT_REJECTED_WITHOUT_MUTATION=PASS'
 print '(A)','ISOLATED_ANALYTIC_LIMIT_NOT_A_RICHARDS_RUN=PASS'
end program
