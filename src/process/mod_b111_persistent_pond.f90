! Persistent surface mass; hydraulic depth is an accepted-water mirror only.
module mod_b111_persistent_pond
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_pond_solute_exchange,only:b111_pond_solute_result_t,evaluate_b111_pond_solute_exchange,B111_POND_SOL_OK
 implicit none
 private
 integer,parameter,public::POND_OK=0,POND_INVALID=1,POND_WATER=2,POND_MASS=3
 type,public::persistent_pond_state_t
  private
  real(real64)::clock=0d0,depth=0d0,mass=0d0
  integer(int64)::revision=0
  logical::initialized=.false.
 contains
  procedure::snapshot=>pond_snapshot
  procedure::ready=>pond_ready
 end type
 type,public::pond_step_t
  real(real64)::t0=0d0,t1=0d0,depth_begin=0d0,depth_end=0d0,qtop=0d0
  real(real64)::rain_rate=0d0,rain_c=0d0,irrigation_rate=0d0,irrigation_c=0d0,dry_deposition_rate=0d0
  ! Accepted gross pond evaporation removes water, never dissolved solute.
  real(real64)::pond_evaporation_rate=0d0
  real(real64)::runon_rate=0d0,runon_c=0d0,runoff_depth=0d0
 end type
 type,public::persistent_pond_receipt_t
  integer::status=POND_INVALID
  real(real64)::mass_before=0d0,mass_after=0d0,rain_input=0d0,irrigation_input=0d0,dry_input=0d0
  real(real64)::runon_input=0d0,runoff_output=0d0,soil_transfer=0d0,water_residual=0d0,mass_residual=0d0
 end type
 public::initialize_persistent_pond,advance_persistent_pond,restore_persistent_pond
contains
 pure logical function bounded_values(clock,depth,mass,revision) result(ok)
  real(real64),intent(in)::clock,depth,mass
  integer(int64),intent(in)::revision
  ok=.false.
  if(.not.all(ieee_is_finite([clock,depth,mass])))return
  if(abs(clock)>1d8.or.depth<0d0.or.depth>1d6.or.mass<0d0.or.mass>1d12)return
  if(revision<0.or.revision>100000000_int64)return
  ok=.true.
 end function
 pure logical function pond_ready(self) result(ok)
  class(persistent_pond_state_t),intent(in)::self
  ok=self%initialized.and.bounded_values(self%clock,self%depth,self%mass,self%revision)
 end function
 pure subroutine pond_snapshot(self,clock,depth,mass,revision)
  class(persistent_pond_state_t),intent(in)::self
  real(real64),intent(out)::clock,depth,mass
  integer(int64),intent(out)::revision
  clock=self%clock;depth=self%depth;mass=self%mass;revision=self%revision
 end subroutine
 pure subroutine initialize_persistent_pond(clock,depth,mass,state,status)
  real(real64),intent(in)::clock,depth,mass
  type(persistent_pond_state_t),intent(out)::state
  integer,intent(out)::status
  state=persistent_pond_state_t();status=POND_INVALID
  if(.not.bounded_values(clock,depth,mass,0_int64))return
  state%clock=clock;state%depth=depth;state%mass=mass;state%initialized=.true.;status=POND_OK
 end subroutine
 ! Trusted, validated adapter boundary. Rejection preserves an existing target.
 pure subroutine restore_persistent_pond(schema,clock,depth,mass,revision,state,status)
  integer,intent(in)::schema
  real(real64),intent(in)::clock,depth,mass
  integer(int64),intent(in)::revision
  type(persistent_pond_state_t),intent(inout)::state
  integer,intent(out)::status
  type(persistent_pond_state_t)::trial
  status=POND_INVALID
  if(schema/=1.or..not.bounded_values(clock,depth,mass,revision))return
  call initialize_persistent_pond(clock,depth,mass,trial,status)
  if(status/=POND_OK)return
  trial%revision=revision;state=trial
 end subroutine
 pure subroutine advance_persistent_pond(committed,s,candidate,r)
  type(persistent_pond_state_t),intent(in)::committed
  type(pond_step_t),intent(in)::s
  type(persistent_pond_state_t),intent(out)::candidate
  type(persistent_pond_receipt_t),intent(out)::r
  type(b111_pond_solute_result_t)::mix
  real(real64)::dt,available,scale
  candidate=committed;r=persistent_pond_receipt_t()
  if(.not.committed%ready())return
  if(committed%revision>=100000000_int64)return
  if(.not.all(ieee_is_finite([s%t0,s%t1,s%depth_begin,s%depth_end,s%qtop, &
    s%rain_rate,s%rain_c,s%irrigation_rate,s%irrigation_c,s%dry_deposition_rate, &
    s%pond_evaporation_rate,s%runon_rate,s%runon_c,s%runoff_depth])))return
  if(abs(s%t0)>1d8.or.abs(s%t1)>1d8.or.s%t1<=s%t0)return
  if(s%t0/=committed%clock.or.s%depth_begin/=committed%depth)return
  dt=s%t1-s%t0
  if(dt<1d-100.or.dt>1d3)return
  if(min(s%depth_begin,s%depth_end,s%rain_rate,s%rain_c,s%irrigation_rate, &
    s%irrigation_c,s%dry_deposition_rate,s%pond_evaporation_rate,s%runon_rate,s%runon_c,s%runoff_depth)<0d0)return
  if(max(s%depth_begin,s%depth_end,s%rain_c,s%irrigation_c,s%runon_c,s%dry_deposition_rate)>1d6)return
  if(max(s%rain_rate,s%irrigation_rate,s%runon_rate,s%pond_evaporation_rate)>5d5.or.s%qtop>0d0.or.s%qtop< -1d6)return
  r%status=POND_WATER
  r%water_residual=s%depth_end-s%depth_begin- &
    (s%rain_rate+s%irrigation_rate+s%runon_rate-s%pond_evaporation_rate+s%qtop)*dt+s%runoff_depth
  if(abs(r%water_residual)>1d-10)return
  r%status=POND_MASS
  r%mass_before=committed%mass;r%dry_input=s%dry_deposition_rate*dt
  available=committed%mass+r%dry_input
  call evaluate_b111_pond_solute_exchange(available,s%rain_rate,s%rain_c,s%irrigation_rate,s%irrigation_c, &
    s%qtop,0d0,s%depth_end,dt,mix,s%runon_rate,s%runon_c,s%runoff_depth)
  if(mix%status/=B111_POND_SOL_OK)return
  if(mix%mass_after>1d12.or.mix%soil_transfer>1d12)return
  if(.not.bounded_values(s%t1,s%depth_end,mix%mass_after,committed%revision+1))return
  r%rain_input=mix%rain_input;r%irrigation_input=mix%irrigation_input;r%runon_input=mix%runon_input
  r%soil_transfer=mix%soil_transfer;r%runoff_output=mix%runoff_output;r%mass_after=mix%mass_after
  r%mass_residual=r%mass_after+r%soil_transfer+r%runoff_output-r%mass_before-r%dry_input- &
    r%rain_input-r%irrigation_input-r%runon_input
  scale=max(1d0,r%mass_before,r%mass_after,r%dry_input,r%rain_input,r%irrigation_input,r%runon_input,r%runoff_output)
  if(abs(r%mass_residual)>8192d0*epsilon(1d0)*scale)return
  candidate=committed;candidate%clock=s%t1;candidate%depth=s%depth_end;candidate%mass=mix%mass_after
  candidate%revision=committed%revision+1;r%status=POND_OK
 end subroutine
end module
