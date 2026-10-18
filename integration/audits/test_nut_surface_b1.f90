program surface_n_b1
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use mod_soil_n_surface_exchange
 implicit none
 type(mineral_parameters_t)::p
 type(mineral_state_t)::state,before,restored
 type(mineral_restart_t)::restart
 type(soil_n_pool_state_t)::pools,snap
 type(mineral_receipt_t)::r
 type(soil_n_surface_day_t)::f,bad
 type(soil_n_surface_receipt_t)::mix
 real(real64)::time,water,initial_n,expected,theta,old_surface(2)
 integer(int64)::revision
 integer::code,i
 p%dz_cm=[30d0];p%inventory%depth_m=.3d0;p%inventory%nfrac_fom=[.01d0]
 p%inventory%nfrac_biomass=.03d0;p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0;p%sorption=.0002d0;p%c_top=[.005d0,.015d0];p%surface_n_enabled=.true.
 call initialize_soil_n_pool_state(p%inventory,[1d0],5d0,40d0,.02d0,.03d0,pools,code)
 call check(code==0,'pool initialize')
 call initialize_mineral(p,1_int64,0d0,.3d0,pools,state,code);call check(code==0,'owner initialize')
 call state%snapshot(time,water,snap,revision);call check(allocated(snap%surface_n_kg_m2),'single inventory surface allocation')
 initial_n=snap%nitrogen_total(p%inventory)
 allocate(f%steps(1));f%steps(1)%t0=0d0;f%steps(1)%t1=1d0
 f%steps(1)%rain_rate=.4d0;f%steps(1)%pond_evaporation_rate=.4d0
 call advance_mineral_day(state,0d0,1d0,.3d0,0d0,0d0,0d0,0d0,r,surface_water=0d0,surface_n=f)
 call check(r%status==0,'rain evaporation accepted')
 call state%snapshot(time,water,snap,revision)
 call near(snap%ammonium_n_kg_m2,.02d0,'dry surface source has not entered soil')
 call near(snap%nitrate_n_kg_m2,.03d0,'dry surface nitrate retained')
 call near(sum(snap%surface_n_kg_m2),.00008d0,'gross source retained on dry surface')
 call near(snap%nitrogen_total(p%inventory),initial_n+.00008d0,'whole inventory includes surface')
 old_surface=snap%surface_n_kg_m2
 ! Rewet with4mm water:2mm infiltrates,1mm runoff,1mm remains.
 f%steps(1)%t0=1d0;f%steps(1)%t1=2d0;f%steps(1)%rain_rate=.4d0
 f%steps(1)%pond_evaporation_rate=0d0;f%steps(1)%qtop=-.2d0
 f%steps(1)%runoff_depth=.1d0;f%steps(1)%depth_end=.1d0
 theta=.3d0+.002d0/.3d0
 before=state
 call export_mineral_restart(state,restart,code);call check(code==0,'opaque export dry N')
 call restore_mineral_restart(restart,1_int64,restored,code);call check(code==0,'opaque restore dry N')
 do i=1,2
  if(i==1)then
   call advance_mineral_day(state,1d0,2d0,theta,0d0,0d0,0d0,0d0,r,surface_water=.002d0,surface_n=f)
  else
   call advance_mineral_day(restored,1d0,2d0,theta,0d0,0d0,0d0,0d0,r,surface_water=.002d0,surface_n=f)
  end if
  call check(r%status==0,'rewetting infiltration runoff accepted')
  call near(sum(r%surface%infiltrated),.00008d0,'half available N infiltrates')
  call near(sum(r%surface%runoff),.00004d0,'quarter available N runoff')
  call near(sum(r%surface%after),.00004d0,'quarter available N retained')
  call near(r%residual,0d0,'whole N conservation')
 end do
 call state%snapshot(time,water,snap,revision)
 call near(snap%nitrogen_total(p%inventory),initial_n+.00012d0,'two-day whole N budget')
 ! Final bad surface substep cannot publish a prefix.
 bad=f;bad%steps(1)%depth_end=.2d0
 call advance_mineral_day(before,1d0,2d0,theta,0d0,0d0,0d0,0d0,r,surface_water=.002d0,surface_n=bad)
 call check(r%status/=0,'water ledger mismatch rejection')
 call before%snapshot(time,water,snap,revision)
 call check(time==1d0.and.revision==1_int64,'rejected owner clock revision unchanged')
 call check(all(snap%surface_n_kg_m2==old_surface),'rejected surface stock unchanged')
 bad=f;bad%steps(1)%rain_rate=ieee_value(0d0,ieee_quiet_nan)
 call advance_mineral_day(before,1d0,2d0,theta,0d0,0d0,0d0,0d0,r,surface_water=.002d0,surface_n=bad)
 call check(r%status/=0,'NaN forcing rejected')
 call advance_mineral_day(before,1d0,2d0,theta,0d0,0d0,0d0,0d0,r,surface_water=.002d0)
 call check(r%status/=0,'enabled owner cannot silently use net-only route')
 print '(A)','SURFACE_N_B1_REAL_OWNER_DRY_REWET_RUNOFF_BALANCE_OPAQUE_ROLLBACK=PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  end if
 end subroutine
 subroutine near(a,b,label)
  real(real64),intent(in)::a,b
  character(*),intent(in)::label
  call check(abs(a-b)<1d-12,label)
 end subroutine
end program
