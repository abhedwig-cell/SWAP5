program test_persistent_pond
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_persistent_pond
 use historical_surface_oracle
 implicit none
 type(persistent_pond_state_t)::state,next,saved,restored
 type(pond_step_t)::s,bad
 type(persistent_pond_receipt_t)::r
 real(real64)::clock,depth,mass,c,transfer,remaining,dt,dry
 integer(int64)::revision
 integer::i,status
 do i=1,240
  dt=real(i,real64)/256d0;dry=0.125d0
  call initialize_persistent_pond(0d0,0.5d0,0.25d0,state,status)
  call require(status==POND_OK,'initialization')
  s=pond_step_t(0d0,dt,0.5d0,0.5d0+0.25d0*dt,-0.25d0,0.25d0,0.125d0,0.25d0,0.375d0,dry)
  call advance_persistent_pond(state,s,next,r)
  call require(r%status==POND_OK,'wet mixing')
  call literal_surface(0.25d0+dry*dt,s%rain_rate,s%rain_c,s%irrigation_rate,s%irrigation_c, &
    s%qtop,s%depth_end,dt,c,transfer,remaining)
  call require(r%soil_transfer==transfer.and.r%mass_after==remaining,'literal B111 mixing')
  call require(abs(r%mass_residual)<1d-14.and.abs(r%water_residual)<1d-14,'dual balance')
  call state%snapshot(clock,depth,mass,revision)
  call require(clock==0d0.and.depth==0.5d0.and.mass==0.25d0.and.revision==0,'input nonmutation')
 end do
 ! Final accepted pond evaporation removes water, not chemical mass.
 ! This pins incumbent SWAP5 / historical B1.11 denominator: 1 mg/cm2
 ! infiltrates from an initial 2 mg/cm2 for this evaporation fixture.
 call initialize_persistent_pond(0d0,1d0,2d0,state,status)
 call require(status==POND_OK,'evap initialization')
 s=pond_step_t(0d0,1d0,1d0,0.25d0,-0.25d0,0d0,0d0,0d0,0d0,0d0)
 s%pond_evaporation_rate=0.5d0
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK,'accepted evap water budget')
 call require(abs(r%soil_transfer-1d0)<1d-14.and.abs(r%mass_after-1d0)<1d-14, &
   'evap preserved historical mixing')
 call require(abs(r%mass_residual)<1d-14.and.abs(r%water_residual)<1d-14, &
   'evap coupled water and chemical balance')
 saved=next
 bad=s;bad%pond_evaporation_rate=0.25d0
 call advance_persistent_pond(state,bad,next,r)
 call require(r%status==POND_WATER,'unbalanced evaporation rejected')
 call same(state,next,'evap rejection does not mutate committed pond')
 call saved%snapshot(clock,depth,mass,revision)
 call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
 call require(status==POND_OK,'evap restart')
 call same(saved,restored,'evap restart identity')
 ! Explicit chemically loaded runon has its own provenance and mass budget.
 call initialize_persistent_pond(0d0,1d0,2d0,state,status)
 call require(status==POND_OK,'runon initialization')
 s=pond_step_t(0d0,1d0,1d0,1.25d0,-0.25d0,0d0,0d0,0d0,0d0,0d0)
 s%runon_rate=0.5d0;s%runon_c=4d0
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK,'accepted chemically loaded runon')
 call require(abs(r%runon_input-2d0)<1d-14,'runon source mass')
 call require(abs(r%soil_transfer-(4d0/1.5d0)*0.25d0)<1d-13,'runon source-aligned mixing')
 call require(abs(r%mass_after+r%soil_transfer-4d0)<1d-13,'runon conservation')
 call require(abs(r%water_residual)<1d-14.and.abs(r%mass_residual)<1d-13,'runon budgets')
 bad=s;bad%runon_c=-1d0
 call advance_persistent_pond(state,bad,next,r)
 call require(r%status/=POND_OK,'negative runon concentration rejected')
 call same(state,next,'invalid runon preserves committed state')
 bad=s;bad%runon_rate=0.25d0
 call advance_persistent_pond(state,bad,next,r)
 call require(r%status==POND_WATER,'runon water mismatch rejected')
 call same(state,next,'runon water rejection nonmutation')
 ! Runoff after accepted infiltration exports its own mass while retaining
 ! the incumbent denominator for the zero-runoff regression above.
 call initialize_persistent_pond(0d0,1d0,2d0,state,status)
 s=pond_step_t(0d0,1d0,1d0,0.5d0,-0.25d0,0d0,0d0,0d0,0d0,0d0)
 s%runoff_depth=0.25d0
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK,'runoff accepted pond budget')
 call require(abs(r%soil_transfer-(2d0/1d0)*0.25d0)<1d-13,'runoff infiltration transfer')
 call require(abs(r%runoff_output-(2d0/1d0)*0.25d0)<1d-13,'runoff solute export')
 call require(abs(r%mass_after-1d0)<1d-13,'runoff retained pond solute')
 call require(abs(r%mass_residual)<1d-13.and.abs(r%water_residual)<1d-13,'runoff closure')
 bad=s;bad%runoff_depth=0.5d0
 call advance_persistent_pond(state,bad,next,r)
 call require(r%status==POND_WATER,'runoff mismatch rejected')
 call same(state,next,'runoff rejection nonmutation')
 ! Runoff-only withdrawal is bounded by available water, not counted as
 ! infiltration or evaporation; the pond remains the sole mass owner.
 call initialize_persistent_pond(0d0,1d0,3d0,state,status)
 s=pond_step_t(0d0,1d0,1d0,0.6d0,0d0,0d0,0d0,0d0,0d0,0d0)
 s%runoff_depth=0.4d0
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK,'runoff without infiltration')
 call require(abs(r%runoff_output-1.2d0)<1d-13,'runoff-only export')
 call require(abs(r%mass_after-1.8d0)<1d-13,'runoff-only retained mass')
 call require(abs(r%mass_residual)<1d-13.and.abs(r%water_residual)<1d-13,'runoff-only balance')
 saved=next
 call saved%snapshot(clock,depth,mass,revision)
 call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
 call require(status==POND_OK,'runoff pond restart accepted')
 call same(saved,restored,'runoff pond restart identity')
 bad=s;bad%runoff_depth=-0.1d0
 call advance_persistent_pond(state,bad,next,r)
 call require(r%status/=POND_OK,'negative runoff rejected')
 call same(state,next,'negative runoff nonmutation')
 ! Dry deposition persists across a dry hiatus and restart, then remobilizes.
 call initialize_persistent_pond(0d0,0d0,0d0,state,status)
 s=pond_step_t(0d0,1d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0.25d0)
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK.and.r%mass_after==0.25d0.and.r%soil_transfer==0d0,'dry retention')
 state=next;call state%snapshot(clock,depth,mass,revision)
 call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
 call require(status==POND_OK,'restore dry mass')
 call same(state,restored,'exact dry restart')
 s=pond_step_t(1d0,2d0,0d0,0d0,-0.5d0,0.5d0,0.25d0,0d0,0d0,0d0)
 call advance_persistent_pond(restored,s,next,r)
 call require(r%status==POND_OK.and.r%mass_after==0d0.and.r%soil_transfer==0.375d0,'rewetting')
 saved=next
 call advance_persistent_pond(saved,s,next,r)
 call require(r%status/=POND_OK,'consumed forcing replay')
 call same(saved,next,'replay cannot mutate candidate')
 ! Historical cutoff explicitly retains mass; it does not erase tiny supply.
 call initialize_persistent_pond(0d0,0d0,0.25d0,state,status)
 s=pond_step_t(0d0,1d0,0d0,0d0,-1d-6,1d-6,0d0,0d0,0d0,0d0)
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK.and.r%mass_after==0.25d0.and.r%soil_transfer==0d0,'cutoff retained')
 ! Failed water, invalid forcing and overflow candidates never change state.
 call initialize_persistent_pond(0d0,0.5d0,0.25d0,state,status)
 s=pond_step_t(0d0,1d0,0.5d0,0.75d0,-0.25d0,0.25d0,0.125d0,0.25d0,0.375d0,0.125d0)
 do i=1,17
  bad=s
  select case(i)
  case(1)
   bad%depth_end=0.8d0
  case(2)
   bad%depth_begin=0.6d0
  case(3)
   bad%t0=0.5d0
  case(4)
   bad%t1=bad%t0
  case(5)
   bad%qtop=1d0
  case(6)
   bad%rain_rate=huge(0d0)
  case(7)
   bad%irrigation_rate=huge(0d0)
  case(8)
   bad%dry_deposition_rate=huge(0d0)
  case(9)
   bad%rain_c=ieee_value(0d0,ieee_quiet_nan)
  case(10)
   bad%rain_c=-1d0
  case(11)
   bad%depth_end=-1d0
  case(12)
   bad%t1=1001d0
  case(13)
   bad%t1=1d-200
  case(14)
   bad%qtop=-huge(0d0)
  case(15)
   bad%dry_deposition_rate=-1d0
  case(16)
   bad%depth_end=huge(0d0)
  case(17)
   bad%irrigation_c=huge(0d0)
  end select
  call advance_persistent_pond(state,bad,next,r)
  call require(r%status/=POND_OK,'bad receipt rejected')
  call same(state,next,'failed trial unchanged')
 end do
 ! Missing water exceeding the absolute budget cannot hide behind a rate tolerance.
 call initialize_persistent_pond(0d0,0d0,0.25d0,state,status)
 s=pond_step_t(0d0,1000d0,0d0,0d0,-1d6+1d-7,5d5,0d0,5d5,0d0,0d0)
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_WATER,'absolute integrated water gate')
 saved=state
 do i=1,6
  clock=0d0;depth=0d0;mass=0.25d0;revision=0
  select case(i)
  case(1)
   mass=-1d0
  case(2)
   mass=ieee_value(0d0,ieee_quiet_nan)
  case(3)
   depth=-1d0
  case(4)
   revision=-1
  case(5)
   clock=huge(0d0)
  case(6)
   mass=huge(0d0)
  end select
  call restore_persistent_pond(1,clock,depth,mass,revision,state,status)
  call require(status/=POND_OK,'malformed restart')
  call same(state,saved,'failed restore unchanged')
 end do
 call restore_persistent_pond(2,0d0,0d0,0.25d0,0_int64,state,status)
 call require(status/=POND_OK,'version rejected')
 call same(state,saved,'version restore unchanged')
 ! Explicit upward water must preserve the authenticated historical zero
 ! chemical flux. It is deliberately rejected without the new selector.
 do i=1,240
  dt=real(i,real64)/256d0
  call initialize_persistent_pond(0d0,0.5d0,0.25d0,state,status)
  s=pond_step_t();s%t1=dt;s%depth_begin=0.5d0;s%qtop=0.04d0
  s%rain_rate=0.1d0;s%rain_c=0.25d0;s%pond_evaporation_rate=0.05d0
  s%depth_end=0.5d0+(s%rain_rate-s%pond_evaporation_rate+s%qtop)*dt
  call advance_persistent_pond(state,s,next,r)
  call require(r%status==POND_INVALID,'default upward water still rejected')
  call same(state,next,'default upward rejection exact')
  s%historical_zero_solute_exfiltration=.true.
  call advance_persistent_pond(state,s,next,r)
  call require(r%status==POND_OK,'explicit historical upward water')
  call literal_surface(0.25d0,s%rain_rate,s%rain_c,0d0,0d0,s%qtop,s%depth_end,dt,c,transfer,remaining)
  call require(r%soil_transfer==transfer.and.transfer==0d0.and.r%mass_after==remaining, &
    'literal historical upward chemical flux')
  call require(abs(r%water_residual)<1d-14.and.abs(r%mass_residual)<1d-14,'upward hard budgets')
  saved=next
  bad=s;bad%depth_end=bad%depth_end+1d-5
  call advance_persistent_pond(state,bad,next,r)
  call require(r%status==POND_WATER,'upward water mismatch rejected')
  call same(state,next,'upward water failure exact')
  bad=s;bad%qtop=1d6+1d0
  call advance_persistent_pond(state,bad,next,r)
  call require(r%status==POND_INVALID,'upward rate domain retained')
  call same(state,next,'upward invalid input exact')
  call saved%snapshot(clock,depth,mass,revision)
  call restore_persistent_pond(1,clock,depth,mass,revision,restored,status)
  call require(status==POND_OK,'upward state restore')
  call same(saved,restored,'upward restored state exact')
  ! All retained mass, including rain, can subsequently infiltrate. No
  ! unreported loss or duplicated soil-to-pond transfer may accumulate.
  s=pond_step_t();s%t0=clock;s%t1=clock+1d0;s%depth_begin=depth
  s%qtop=-depth;s%exact_empty_pool_chemistry=.true.
  call advance_persistent_pond(restored,s,next,r)
  call require(r%status==POND_OK.and.r%mass_after==0d0.and.r%soil_transfer==mass, &
    'upward retained mass remobilizes exactly')
 end do
 ! Upward water with runoff exports only the existing runoff mass.
 call initialize_persistent_pond(0d0,1d0,3d0,state,status)
 s=pond_step_t();s%t1=1d0;s%depth_begin=1d0;s%depth_end=0.75d0
 s%qtop=0.25d0;s%runoff_depth=0.5d0;s%historical_zero_solute_exfiltration=.true.
 call advance_persistent_pond(state,s,next,r)
 call require(r%status==POND_OK.and.r%soil_transfer==0d0,'upward runoff accepted')
 call require(abs(r%runoff_output-1.2d0)<1d-14.and.abs(r%mass_after-1.8d0)<1d-14, &
   'upward runoff has one declared chemical export')
 call require(abs(r%mass_residual)<1d-14.and.abs(r%water_residual)<1d-14,'upward runoff budgets')
 print '(A)','HISTORICAL_ZERO_UPWARD_240_ORACLE_REJECTION_RESTORE_REMOBILIZE_RUNOFF=PASS'
 print '(A)','PERSISTENT_POND_LITERAL_240_DRY_REWET_BALANCE_REPLAY_RESTORE_NEGATIVES=PASS'
contains
 subroutine same(a,b,label)
  type(persistent_pond_state_t),intent(in)::a,b
  character(*),intent(in)::label
  real(real64)::ta,da,ma,tb,db,mb
  integer(int64)::ra,rb
  call a%snapshot(ta,da,ma,ra);call b%snapshot(tb,db,mb,rb)
  call require(ta==tb.and.da==db.and.ma==mb.and.ra==rb.and.(a%ready().eqv.b%ready()),label)
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print '(A)','FAIL '//label
   error stop 1
  end if
 end subroutine
end program
