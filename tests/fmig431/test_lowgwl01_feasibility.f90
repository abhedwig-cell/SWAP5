! Diagnostic only: the public solver must reject mode 1. The explicit raw
! HeadCalc call deliberately bypasses that guard to expose unadmitted debt.
program test_lowgwl01_feasibility
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
  integer :: i
  interface
    subroutine headcalc(worker,fsi_workspace,history,state_binding,evaluation_context,boundary_conditions, &
                        numerical_config,physical_config,explicit_step_duration,parameter_set)
      import
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      type(soil_water_physical_config_t), intent(in), optional :: physical_config
      real(real64), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine
  end interface
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
  request%base_state%groundwater_level=-999.0_real64
  request%boundary%bottom_mode=1
  request%boundary%bottom_head=-100.0_real64
  request%boundary%bottom_flux=0.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%top_flux=0.0_real64
  request%step_duration=0.125_real64
  request%numerical%max_iterations=8
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%head_abs_tolerance=1.0e-12_real64
  request%numerical%head_rel_tolerance=1.0e-12_real64
  request%numerical%ponding_tolerance=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=1.0e-12_real64
  request%numerical%total_balance_tolerance=1.0e-12_real64
  request%evaluation%constitutive=>hydraulic
  request%evaluation%source_sink=>sources
  request%evaluation%top_boundary=>top

  call solver%solve(request,ws,result)
  if (result%status/=SW_SOLVE_CONVERGED) error stop 'below-profile mode1 did not converge'
  if (.not.allocated(result%candidate_state%pressure_head)) error stop 'below-profile mode1 missing candidate'
  if (result%candidate_state%active_nodes/=n) error stop 'below-profile mode1 candidate shape'
  if (abs(result%candidate_state%groundwater_level+100.0_real64)>1.0e-12_real64) error stop 'prescribed GWL publication'
  if (.not.result%native_balance_rate_residual_available .or. .not.result%integrated_mass_balance_residual_available) &
       error stop 'below-profile mode1 mass residual missing'
  if (abs(result%integrated_mass_balance_residual_cm)>1.0e-10_real64) error stop 'below-profile mode1 mass residual'
  if (abs(result%bottom_flux)>1.0e-10_real64) error stop 'hydrostatic below-profile qbot'
  print '(a)','F-MIG431-LOWGWL01_BELOW_PROFILE_TYPED=PASS'

  request%boundary%bottom_head=-42.0_real64
  request%base_state%pressure_head=-42.0_real64-p%z
  call hydraulic%evaluate(request%base_state%pressure_head,request%base_state%water_content,k,cap,dkdh)
  call initialize_reference_state_binding(state,request)
  call headcalc(worker,rawws,history,state,request%evaluation,request%boundary,request%numerical, &
                request%physical,request%step_duration,p)
  if (worker%control%request_dt_reduction .or. state%fldecdt) error stop 'raw in-profile provider route requested retry'
  if (state%fllowgwl) error stop 'raw in-profile route misclassified below profile'
  if (abs(state%qbot)>1.0e-10_real64) error stop 'raw in-profile hydrostatic qbot'
  if (maxval(abs(state%h-request%base_state%pressure_head))>1.0e-10_real64) error stop 'raw in-profile head reconstruction'
  if (maxval(abs(state%theta(5:n)-cof(2,5:n)))>1.0e-12_real64) error stop 'raw in-profile saturated theta'
  if (worker%diagnostics%constitutive_evaluations<=0) error stop 'raw in-profile provider not used'
  print '(a)','F-MIG431-LOWGWL01_IN_PROFILE_PROVIDER_RAW=PASS'

  call solver%solve(request,ws,result)
  if (result%status/=SW_SOLVE_FAILED) error stop 'in-profile mode1 must remain fail-closed'
  if (trim(result%diagnostics%route)/='mode1-inprofile-deferred') error stop 'wrong in-profile guard'
  if (allocated(result%candidate_state%pressure_head)) error stop 'in-profile rejection emitted candidate'
  print '(a)','F-MIG431-LOWGWL01_IN_PROFILE_FAIL_CLOSED=PASS'

end program
