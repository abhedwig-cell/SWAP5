program test_low03_typed_solver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding
  use mod_reference_richards_state_binding
  use mod_reference_richards_workspace
  use mod_a23bu_worker_execution_context
  use mod_b110_default_mvg_provider
  use mod_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider
  implicit none
  integer, parameter :: n=8
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hydraulic
  type(b110_source_sink_provider_t), target :: sources
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(reference_richards_state_binding_t), target :: state
  type(reference_richards_workspace_t), target :: rawws
  type(a23bu_worker_context_t) :: worker
  type(a23bu_solver_history_t) :: history
  real(real64) :: cof(24,n), k(n), cap(n), dkdh(n)
  real(real64), target :: drainage(1,n), irrigation(n), roots(n)
  integer :: i,j,flag,ir,ie,count
  real(real64) :: aq,resistance,extra,expected,storage_residual,heads_saved(n),theta_saved(n),conductance
  real(real64), parameter :: resistances(3)=[0._real64,10._real64,100._real64]
  type(soil_water_solve_result_t) :: replay,head5,failed
  type(reference_richards_legacy_workspace_t) :: clean,ws5
  type(soil_water_boundary_conditions_t) :: boundary_saved
  p%active_nodes=n
  allocate(p%z(n),p%dz(n),p%node_distance(n))
  do i=1,n
    p%z(i)=5.0_real64-10.0_real64*i
  end do
  p%dz=10.0_real64
  p%node_distance=10.0_real64
  p%node_distance(1)=5.0_real64
  cof=0.0_real64
  cof(1,:)=0.032_real64;cof(2,:)=0.423_real64;cof(3,:)=4.75_real64
  cof(4,:)=0.0135_real64;cof(5,:)=0.365_real64;cof(6,:)=1.455_real64
  cof(7,:)=1.0_real64-1.0_real64/cof(6,:);cof(8,:)=cof(4,:)
  cof(10,:)=cof(3,:);cof(11,:)=0.999_real64;cof(12,:)=0.99_real64*cof(3,:)
  cof(22,:)=-1.0e6_real64;cof(23,:)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(hydraulic,hp,0.125_real64)
  drainage=0.0_real64;irrigation=0.0_real64;roots=0.0_real64
  call bind_b110_source_sink_provider(sources,drainage,irrigation,roots)
  request%parameters=>p
  request%base_state%active_nodes=n
  allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
  request%base_state%pressure_head=-100.0_real64-p%z
  call hydraulic%evaluate(request%base_state%pressure_head,request%base_state%water_content,k,cap,dkdh)
  request%base_state%groundwater_level=-100.0_real64
  request%boundary%bottom_mode=3
  request%boundary%bottom_head=-100.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%step_duration=0.125_real64
  request%numerical%max_iterations=100
  request%numerical%max_backtracking=100
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%head_abs_tolerance=1.0e-12_real64
  request%numerical%head_rel_tolerance=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=1.0e-12_real64
  request%numerical%total_balance_tolerance=1.0e-12_real64
  request%evaluation%constitutive=>hydraulic
  request%evaluation%source_sink=>sources
  request%evaluation%top_boundary=>top
  heads_saved=request%base_state%pressure_head;theta_saved=request%base_state%water_content
  count=0
  do j=-1,1
  do flag=0,1
  do ir=1,3
  do ie=-1,1
    resistance=resistances(ir)
    if(flag==1.and.resistance==0._real64)cycle
    aq=-100._real64+10._real64*j;extra=.01_real64*ie
    request%boundary%bottom_mode=3
    request%boundary%bottom_head=aq
    request%boundary%bottom_flux=extra
    request%boundary%bottom_external_resistance_days=resistance
    request%boundary%bottom_include_half_cell=flag==0
    call solver%solve(request,ws,result)
    if(result%status/=SW_SOLVE_CONVERGED)then
      print *, 'FAILED CASE',j,flag,ir,ie,result%status,trim(result%diagnostics%route)
      print *, 'ITER/RESIDUAL',result%diagnostics%nonlinear_iterations,maxval(abs(ws%richards%residual)), &
            sum(ws%richards%residual),ws%state_binding%kmean(n+1)
      print *, 'RESIDUAL VECTOR',ws%richards%residual
      boundary_saved=request%boundary
      request%boundary%bottom_mode=5
      request%boundary%bottom_external_resistance_days=0._real64
      request%boundary%bottom_include_half_cell=.true.
      request%boundary%bottom_flux=0._real64
      request%boundary%bottom_head=aq-(p%z(n)-.5_real64*p%dz(n))
      call solver%solve(request,ws5,head5)
      print *, 'SAME-FIXTURE MODE5',head5%status,head5%diagnostics%nonlinear_iterations, &
            maxval(abs(ws5%richards%residual)),sum(ws5%richards%residual)
      request%boundary=boundary_saved
      error stop 'typed3 did not converge'
    end if
    if(flag==0)then
      conductance=1._real64/(.5_real64*p%dz(n)/ws%state_binding%kmean(n+1)+resistance)
    else
      conductance=1._real64/resistance
    end if
    expected=(aq-(result%candidate_state%pressure_head(n)+p%z(n)))*conductance+extra
    if(abs(result%bottom_flux-expected)>1.e-12_real64)error stop 'physical bottom flux law mismatch'
    if(.not.result%integrated_mass_balance_residual_available)error stop 'missing mass certificate'
    storage_residual=sum((result%candidate_state%water_content-theta_saved)*p%dz) &
          -request%step_duration*(result%bottom_flux-result%top_flux)
    if(abs(storage_residual)>1.e-12_real64)then
      print *,storage_residual,result%integrated_mass_balance_residual_cm
      error stop 'independent whole-column mass identity'
    end if
    if(any(request%base_state%pressure_head/=heads_saved).or. &
       any(request%base_state%water_content/=theta_saved))error stop 'base state mutated'
    call solver%solve(request,clean,replay)
    if(replay%status/=SW_SOLVE_CONVERGED)error stop 'fresh replay failed'
    if(any(result%candidate_state%pressure_head/=replay%candidate_state%pressure_head))error stop 'A/B/A scratch ownership'
    if(result%bottom_flux/=replay%bottom_flux)error stop 'fresh replay qbot changed'
    if(flag==0.and.resistance==0._real64.and.ie==0)then
      boundary_saved=request%boundary
      request%boundary%bottom_mode=5
      request%boundary%bottom_head=aq-(p%z(n)-.5_real64*p%dz(n))
      request%boundary%bottom_flux=0._real64
      call solver%solve(request,ws5,head5)
      if(head5%status/=SW_SOLVE_CONVERGED)error stop 'zero-R mode5 failed'
      if(maxval(abs(result%candidate_state%pressure_head-head5%candidate_state%pressure_head))>1.e-9_real64) &
           error stop 'zero-R full-solver head limit'
      if(abs(result%bottom_flux-head5%bottom_flux)>1.e-10_real64)error stop 'zero-R full-solver flux limit'
      request%boundary=boundary_saved
    end if
    count=count+1
  end do
  end do
  end do
  end do
  print '(a,i0)', 'LOW03_TYPED_PHYSICAL_MASS_REPLAY_ZERO_R=PASS cases=',count
  request%boundary%bottom_mode=3
  request%boundary%bottom_head=-90._real64
  request%boundary%bottom_flux=0._real64
  request%boundary%bottom_include_half_cell=.true.
  request%boundary%bottom_external_resistance_days=10._real64
  request%numerical%max_iterations=1
  call solver%solve(request,ws,failed)
  if(failed%status/=SW_SOLVE_RETRY_ADVISED)error stop 'forced rejection missing'
  if(any(request%base_state%pressure_head/=heads_saved))error stop 'rejection mutated base'
  request%numerical%max_iterations=100
  call solver%solve(request,ws,result)
  call solver%solve(request,clean,replay)
  if(result%status/=SW_SOLVE_CONVERGED.or.replay%status/=SW_SOLVE_CONVERGED)error stop 'reject replay failed'
  if(any(result%candidate_state%pressure_head/=replay%candidate_state%pressure_head))error stop 'rejected scratch leaked'
  print '(a)', 'LOW03_TYPED_REJECT_REPLAY=PASS'
  request%boundary%bottom_include_half_cell=.false.
  request%boundary%bottom_external_resistance_days=0._real64
  call solver%solve(request,ws,failed)
  if(failed%status/=SW_SOLVE_FAILED.or.allocated(failed%candidate_state%pressure_head))error stop 'singular domain not closed'
  request%boundary%bottom_external_resistance_days=10._real64
  request%numerical%conductivity_implicit_mode=1
  call solver%solve(request,ws,failed)
  if(failed%status/=SW_SOLVE_FAILED)error stop 'SWKIMPL1 unexpectedly admitted'
  request%numerical%conductivity_implicit_mode=0
  request%boundary%bottom_mode=5
  call solver%solve(request,ws,failed)
  if(failed%status/=SW_SOLVE_FAILED)error stop 'mode5 acquired resistance silently'
  print '(a)', 'LOW03_TYPED_SINGULAR_SWKIMPL1_MODE5_AUTHORITY_FAIL_CLOSED=PASS'
end program
