program test_weather_surface_warm_start
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_source_sink_provider
 use mod_b110_root_sink_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_DYNAMIC_PROVIDER
 use mod_reference_richards_legacy_binding
 implicit none
 type(soil_water_parameter_set_t),target::p
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(b110_root_sink_provider_t),target::root
 type(b110_dynamic_top_boundary_solver_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::warm,cold
 type(soil_water_solve_request_t)::r
 type(soil_water_solve_result_t)::v,c
 real(real64)::cof(24,4),kk(4),cc(4),dd(4),input_head(4),input_theta(4),input_pond
 real(real64),target::drain(1,4),irrigation(4),qroot(4)
 integer::i,hits,invalidations,fallbacks
 p%parameter_set_id=380038_int64;p%active_nodes=numnod
 allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
 p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
 cof=0d0
 do i=1,numnod
  cof(1,i)=.032d0;cof(2,i)=.423d0;cof(3,i)=4.75d0;cof(4,i)=.0135d0
  cof(5,i)=.365d0;cof(6,i)=1.455d0;cof(7,i)=1d0-1d0/cof(6,i);cof(8,i)=cof(4,i)
  cof(10,i)=cof(3,i);cof(11,i)=.999d0;cof(12,i)=.99d0*cof(3,i)
  cof(22,i)=-1d6;cof(23,i)=1d-12
 end do
 call initialize_b110_default_mvg_parameters(hp,cof)
 hp%continuous_saturation_conductivity=.true.
 drain=0d0;irrigation=0d0;qroot=[.012646582580739821d0,.012646582580739821d0,.025293165161479642d0,.025293165161479645d0]
 call bind_b110_source_sink_provider(source,drain,irrigation,irrigation)
 call bind_b110_root_sink_provider(root,qroot)
 r%parameters=>p;r%base_state%active_nodes=4
 allocate(r%base_state%pressure_head(4),r%base_state%water_content(4))
 r%base_state%pressure_head=[.22883381555844240d0,.16227285460717916d0,.082399701465663375d0,.029150932704653389d0]
 r%base_state%ponding_depth=.26877039212919984d0;r%base_state%groundwater_level=-2d0
 r%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;r%boundary%bottom_mode=7
 r%numerical%consistent_provider_conductivity=.true.;r%numerical%reuse_trial_head=.true.
 r%numerical%max_iterations=20;r%numerical%max_backtracking=8
 r%numerical%conductivity_mean_method=1;r%numerical%min_step_duration=1d-10
 r%numerical%compartment_balance_tolerance=1d-12;r%numerical%total_balance_tolerance=1d-12
 r%numerical%head_abs_tolerance=1d-9;r%numerical%head_rel_tolerance=1d-9;r%numerical%ponding_tolerance=1d-12
 r%evaluation%constitutive=>hyd;r%evaluation%source_sink=>source;r%evaluation%root_sink=>root
 r%evaluation%dynamic_top_boundary=>top
 call prepare(.001d0)
 input_head=r%base_state%pressure_head;input_theta=r%base_state%water_content;input_pond=r%base_state%ponding_depth
 call solver%solve(r,warm,v);call require(v%status==SW_SOLVE_CONVERGED,'seed real solver')
 call prepare(.0005d0)
 call solver%solve(r,warm,v);call require(v%status==SW_SOLVE_CONVERGED,'warm shorter solve')
 call require(warm%warm_start_attempts==1,'actual warm attempt')
 r%numerical%reuse_trial_head=.false.
 call solver%solve(r,cold,c);call require(c%status==SW_SOLVE_CONVERGED,'independent cold solve')
 call require(maxval(abs(v%candidate_state%pressure_head-c%candidate_state%pressure_head))<1d-7,'head equivalence')
 call require(abs(v%top_flux-c%top_flux)<1d-7,'surface flux equivalence')
 call require(abs(v%unrounded_mass_balance_residual)<1d-12,'unchanged equation gate')
 call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta).and. &
   r%base_state%ponding_depth==input_pond,'immutable physical request')
 r%numerical%reuse_trial_head=.true.
 r%base_state=v%candidate_state
 call prepare(.0005d0)
 hits=warm%warm_start_continuations
 call solver%solve(r,warm,v)
 call require(v%status==SW_SOLVE_CONVERGED.and.warm%warm_start_continuations==hits+1,'exact endpoint continuation')
 r%base_state%pressure_head=input_head;r%base_state%water_content=input_theta;r%base_state%ponding_depth=input_pond
 call prepare(.0005d0);call clear_reference_trial_guess(warm);call solver%solve(r,warm,v)
 hits=warm%warm_start_attempts
 warm%trial_guess_head=ieee_value(0d0,ieee_quiet_nan)
 call solver%solve(r,warm,v)
 call require(v%status==SW_SOLVE_CONVERGED.and.warm%warm_start_attempts==hits,'nonfinite guess excluded before arithmetic')
 hits=warm%warm_start_attempts;invalidations=warm%warm_start_invalidations
 top%precipitation_rate=top%precipitation_rate+.01d0
 call solver%solve(r,warm,v)
 call require(warm%warm_start_attempts==hits.and.warm%warm_start_invalidations==invalidations+1,'forcing invalidation')
 hits=warm%warm_start_attempts;invalidations=warm%warm_start_invalidations
 p%parameter_set_id=p%parameter_set_id+1_int64
 call solver%solve(r,warm,v)
 call require(warm%warm_start_attempts==hits.and.warm%warm_start_invalidations==invalidations+1,'parameter identity invalidation')
 hits=warm%warm_start_attempts;invalidations=warm%warm_start_invalidations
 r%base_state%pressure_head(1)=r%base_state%pressure_head(1)+.00001d0
 call prepare(.0005d0)
 top%precipitation_rate=.73d0
 call solver%solve(r,warm,v)
 call require(warm%warm_start_attempts==hits.and.warm%warm_start_invalidations==invalidations+1,'physical origin invalidation')
 hits=warm%warm_start_attempts;call clear_reference_trial_guess(warm)
 call solver%solve(r,warm,v)
 call require(warm%warm_start_attempts==hits,'clear cache cold reconstruction')
 call require(v%status==SW_SOLVE_CONVERGED,'reseed after clear')
 input_head=r%base_state%pressure_head;input_theta=r%base_state%water_content
 warm%trial_guess_head=-500d0;r%numerical%max_iterations=1
 fallbacks=warm%warm_start_fallbacks
 call solver%solve(r,warm,v)
 call require(warm%warm_start_fallbacks==fallbacks+1,'failed warm attempt executes cold fallback')
 call require(v%status==SW_SOLVE_RETRY_ADVISED,'both bounded attempts remain rejected')
 call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta).and. &
   r%base_state%ponding_depth==input_pond,'failed warm/cold request nonmutation')
 call require(v%diagnostics%nonlinear_iterations>=1,'actual Newton work counted after predictor screening')
 call require(v%diagnostics%headcalc_calls==2,'both HeadCalc calls counted')
 r%numerical%reuse_trial_head=.false.;r%numerical%max_iterations=20
 hits=warm%warm_start_attempts;call solver%solve(r,warm,v)
 call require(warm%warm_start_attempts==hits.and..not.warm%trial_guess_available,'default-off clears numerical cache')
 print *, 'WEATHER_WARM_START_PRODUCTION_CONTRACT_PASS'
 print *, 'WARM_COUNTERS',warm%warm_start_attempts,warm%warm_start_fallbacks,warm%warm_start_invalidations
contains
 subroutine prepare(step)
  real(real64),intent(in)::step
  call bind_b110_default_mvg_provider(hyd,hp,step)
  call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,kk,cc,dd)
  call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,r%base_state%ponding_depth,step, &
   .72d0,0d0,0d0,0d0,.0040205045155610863d0,.0040205045155610863d0,0d0,1d0,1d0,implicit_conductivity=.true.)
  r%step_duration=step
 end subroutine
 subroutine require(condition,label)
  logical,intent(in)::condition
  character(*),intent(in)::label
  if(.not.condition)then
   print *, 'WARM_CONTRACT_FAIL ',label
   error stop 1
  end if
 end subroutine
end program
