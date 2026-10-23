 call require(.not.r%numerical%abort_failed_line_search,'typed option defaults OFF')
 r%numerical%reuse_trial_head=.false.
 input_head=r%base_state%pressure_head;input_pond=r%base_state%ponding_depth
 do i=0,4
  call prepare(.0078125d0/2d0**i)
  input_theta=r%base_state%water_content
  r%numerical%abort_failed_line_search=.false.
  call solver%solve(r,cold,c)
  r%numerical%abort_failed_line_search=.true.
  call solver%solve(r,warm,v)
  call require(v%status==c%status,'ON/OFF failure/success class')
  if(i==0)then
   call require(v%status==SW_SOLVE_RETRY_ADVISED,'failed phase never accepted')
   call require(v%diagnostics%jacobian_builds<c%diagnostics%jacobian_builds,'actual cheaper failed phase')
   print *, 'FAILED_PHASE_WORK',c%diagnostics%jacobian_builds,v%diagnostics%jacobian_builds
  else
   call require(v%status==SW_SOLVE_CONVERGED,'smaller physical step converges')
   call require(abs(v%unrounded_mass_balance_residual)<1d-12,'original hard equation gate')
   call require(maxval(abs(v%candidate_state%pressure_head-c%candidate_state%pressure_head))<1d-5,'bounded head difference')
  end if
  call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta).and. &
    r%base_state%ponding_depth==input_pond,'ON/OFF immutable request')
 end do
 ! Same inherited physical evaluator with an unrecognized dynamic type must
 ! retain the old route, rather than silently widening numerical admission.
 other_root%b110_root_sink_provider_t=root
 r%evaluation%root_sink=>other_root
 call prepare(.0078125d0)
 r%numerical%abort_failed_line_search=.false.;call solver%solve(r,cold,c)
 r%numerical%abort_failed_line_search=.true.;call solver%solve(r,warm,v)
 call require(v%status==c%status.and.v%diagnostics%jacobian_builds==c%diagnostics%jacobian_builds.and. &
    v%diagnostics%backtracking_attempts==c%diagnostics%backtracking_attempts,'unsupported provider exact fallback')
 r%evaluation%root_sink=>root
 r%request_interface_sensitivity=.true.
 r%numerical%abort_failed_line_search=.false.;call solver%solve(r,cold,c)
 r%numerical%abort_failed_line_search=.true.;call solver%solve(r,warm,v)
 call require(v%status==c%status.and.v%diagnostics%jacobian_builds==c%diagnostics%jacobian_builds.and. &
    v%diagnostics%backtracking_attempts==c%diagnostics%backtracking_attempts,'sensitivity exact fallback')
 call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta),'fallback immutable base')
 print *, 'WEATHER_LINE_SEARCH_RETRY_TYPED_CONTRACT_PASS'
