program test_soil_evaporation_pond
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_persistent_pond
 implicit none
 type(persistent_pond_state_t)::base,next
 type(persistent_pond_receipt_t)::r
 type(pond_step_t)::s,bad
 real(real64)::clock,depth,mass
 integer(int64)::revision
 integer::code,i
 call initialize_persistent_pond(0d0,0d0,.5d0,base,code)
 call check(code==POND_OK,'initialize')
 s=pond_step_t();s%t0=0d0;s%t1=1d0;s%qtop=.125d0;s%soil_evaporation_rate=.125d0
 call advance_persistent_pond(base,s,next,r)
 call check(r%status==POND_OK.and.r%soil_transfer==0d0.and.r%mass_after==.5d0,'dry evaporation retains salt')
 call check(r%water_residual==0d0.and.r%mass_residual==0d0,'dry balances')
 call base%snapshot(clock,depth,mass,revision)
 call check(clock==0d0.and.depth==0d0.and.mass==.5d0.and.revision==0,'input nonmutation')
 s%rain_rate=.25d0;s%rain_c=2d0;s%qtop=-.125d0
 call advance_persistent_pond(base,s,next,r)
 call check(r%status==POND_OK.and.r%soil_transfer==1d0.and.r%mass_after==0d0,'original net-infiltration mixing')
 call check(r%water_residual==0d0.and.r%mass_residual==0d0,'wet balances')
 do i=1,6
  bad=s
  select case(i)
  case(1);bad%soil_evaporation_rate=0d0
  case(2);bad%soil_evaporation_rate=-.125d0
  case(3);bad%soil_evaporation_rate=ieee_value(0d0,ieee_quiet_nan)
  case(4);bad%qtop=.25d0
  case(5);bad%pond_evaporation_rate=.125d0
  case(6);bad%depth_end=.125d0
  end select
  call advance_persistent_pond(base,bad,next,r)
  call check(r%status/=POND_OK,'invalid carrier rejected')
  call next%snapshot(clock,depth,mass,revision)
  call check(clock==0d0.and.depth==0d0.and.mass==.5d0.and.revision==0,'rejection preserves target')
 end do
 s=pond_step_t();s%t0=0d0;s%t1=1d0;s%qtop=.125d0
 call advance_persistent_pond(base,s,next,r)
 call check(r%status/=POND_OK,'unqualified exfiltration still rejected')
 call initialize_persistent_pond(0d0,0d0,0d0,base,code)
 s=pond_step_t();s%t0=0d0;s%t1=8.7585970322976436d-3-7.7896416041767225d-3
 s%rain_rate=.1d0;s%rain_c=.125d0;s%qtop=-.08d0;s%soil_evaporation_rate=.02d0
 call advance_persistent_pond(base,s,next,r)
 call check(r%status==POND_MASS,'retain original negative-roundoff counterexample')
 s%exact_empty_pool_chemistry=.true.
 call advance_persistent_pond(base,s,next,r)
 call check(r%status==POND_OK.and.r%mass_after==0d0,'analytical empty pool')
 call check(r%soil_transfer==s%rain_rate*s%rain_c*(s%t1-s%t0),'complete available mass transfer')
 call check(r%mass_residual==0d0,'exact empty pool balance')
 print '(A)','SOIL_EVAPORATION_POND_CONTRACT_PASS'
contains
 subroutine check(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok)then
  print *,message
  error stop 1
 endif
 end subroutine
end program
