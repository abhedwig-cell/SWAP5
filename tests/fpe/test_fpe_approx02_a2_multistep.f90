program test_fpe_approx02_a2_multistep
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_physical_state_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: exact_tol=1.0e-12_real64
  real(real64) :: candidate_tol
  real(real64), parameter :: duration=1.0e-3_real64
  integer, parameter :: nsteps=20

  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(b110_source_sink_provider_t), target :: ss
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver_exact, solver_a2
  type(reference_richards_legacy_workspace_t) :: ws_exact, ws_a2
  type(soil_water_solve_request_t) :: req_exact, req_a2
  type(soil_water_solve_result_t) :: res_exact, res_a2
  real(real64), target :: drainage(1,numnod), irrigation(numnod), roots(numnod)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0
  real(real64) :: water(numnod),cond(numnod),cap(numnod),dkdh(numnod),heads(numnod)
  real(real64) :: exact_heads(numnod,nsteps), exact_theta(numnod,nsteps), exact_flux(nsteps)
  real(real64) :: exact_cum_exchange(nsteps), a2_cum_exchange
  real(real64) :: max_head_abs,max_head_rel,max_theta_abs,max_theta_rel,max_flux_abs,max_flux_rel
  real(real64) :: final_head_abs,final_head_rel,final_theta_abs,final_theta_rel
  real(real64) :: cum_abs,cum_rel,t0,t1,exact_seconds,a2_seconds
  integer :: exact_nonlinear,exact_backtrack,a2_nonlinear,a2_backtrack
  integer :: step,i
  character(len=8) :: material
  character(len=64) :: arg

  if(command_argument_count()/=2 .and. command_argument_count()/=3) error stop 'usage: MATERIAL H0_CM [CANDIDATE_TOL]'
  call get_command_argument(1,material)
  call get_command_argument(2,arg); read(arg,*) h0
  candidate_tol=1.0e-4_real64
  if(command_argument_count()==3)then
    call get_command_argument(3,arg); read(arg,*) candidate_tol
  end if
  if(candidate_tol<=0.0_real64) error stop 'invalid candidate tolerance'
  call material_parameters(trim(material),tr,ts,alpha,nvg,ksat,lambda)

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=630201_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=tr; cofgen(2,i)=ts; cofgen(3,i)=ksat
    cofgen(4,i)=alpha; cofgen(5,i)=lambda; cofgen(6,i)=nvg
    cofgen(7,i)=1.0_real64-1.0_real64/nvg; cofgen(8,i)=alpha
    cofgen(9,i)=0.0_real64; cofgen(10,i)=ksat; cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*ksat; cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,duration)

  heads=h0
  call hyd%evaluate(heads,water,cond,cap,dkdh)
  drainage=0.0_real64; irrigation=0.0_real64; roots=0.0_real64
  call bind_b110_source_sink_provider(ss,drainage,irrigation,roots)

  call initialize_request(req_exact,params,hyd,ss,top,heads,water,h0,exact_tol)
  call initialize_request(req_a2,params,hyd,ss,top,heads,water,h0,candidate_tol)

  exact_nonlinear=0; exact_backtrack=0
  exact_cum_exchange=0.0_real64
  call cpu_time(t0)
  do step=1,nsteps
    call solver_exact%solve(req_exact,ws_exact,res_exact)
    if(res_exact%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'APPROX02_A2_FAIL|ARM=exact|STEP=',step,'|STATUS=',res_exact%status
      error stop 1
    end if
    exact_heads(:,step)=res_exact%candidate_state%pressure_head
    exact_theta(:,step)=res_exact%candidate_state%water_content
    exact_flux(step)=res_exact%bottom_flux
    if(step==1)then
      exact_cum_exchange(step)=res_exact%bottom_flux*duration
    else
      exact_cum_exchange(step)=exact_cum_exchange(step-1)+res_exact%bottom_flux*duration
    end if
    exact_nonlinear=exact_nonlinear+res_exact%diagnostics%nonlinear_iterations
    exact_backtrack=exact_backtrack+res_exact%diagnostics%backtracking_attempts
    req_exact%base_state=res_exact%candidate_state
  end do
  call cpu_time(t1)
  exact_seconds=t1-t0

  a2_nonlinear=0; a2_backtrack=0; a2_cum_exchange=0.0_real64
  max_head_abs=0.0_real64; max_head_rel=0.0_real64
  max_theta_abs=0.0_real64; max_theta_rel=0.0_real64
  max_flux_abs=0.0_real64; max_flux_rel=0.0_real64
  call cpu_time(t0)
  do step=1,nsteps
    call solver_a2%solve(req_a2,ws_a2,res_a2)
    if(res_a2%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'APPROX02_A2_FAIL|ARM=A2|STEP=',step,'|STATUS=',res_a2%status
      error stop 1
    end if
    a2_cum_exchange=a2_cum_exchange+res_a2%bottom_flux*duration
    max_head_abs=max(max_head_abs,maxval(abs(res_a2%candidate_state%pressure_head-exact_heads(:,step))))
    max_head_rel=max(max_head_rel,maxval(abs(res_a2%candidate_state%pressure_head-exact_heads(:,step))/ &
         max(abs(exact_heads(:,step)),1.0e-30_real64)))
    max_theta_abs=max(max_theta_abs,maxval(abs(res_a2%candidate_state%water_content-exact_theta(:,step))))
    max_theta_rel=max(max_theta_rel,maxval(abs(res_a2%candidate_state%water_content-exact_theta(:,step))/ &
         max(abs(exact_theta(:,step)),1.0e-30_real64)))
    max_flux_abs=max(max_flux_abs,abs(res_a2%bottom_flux-exact_flux(step)))
    max_flux_rel=max(max_flux_rel,abs(res_a2%bottom_flux-exact_flux(step))/max(abs(exact_flux(step)),1.0e-30_real64))
    a2_nonlinear=a2_nonlinear+res_a2%diagnostics%nonlinear_iterations
    a2_backtrack=a2_backtrack+res_a2%diagnostics%backtracking_attempts
    req_a2%base_state=res_a2%candidate_state
  end do
  call cpu_time(t1)
  a2_seconds=t1-t0

  final_head_abs=maxval(abs(res_a2%candidate_state%pressure_head-exact_heads(:,nsteps)))
  final_head_rel=maxval(abs(res_a2%candidate_state%pressure_head-exact_heads(:,nsteps))/ &
       max(abs(exact_heads(:,nsteps)),1.0e-30_real64))
  final_theta_abs=maxval(abs(res_a2%candidate_state%water_content-exact_theta(:,nsteps)))
  final_theta_rel=maxval(abs(res_a2%candidate_state%water_content-exact_theta(:,nsteps))/ &
       max(abs(exact_theta(:,nsteps)),1.0e-30_real64))
  cum_abs=abs(a2_cum_exchange-exact_cum_exchange(nsteps))
  cum_rel=cum_abs/max(abs(exact_cum_exchange(nsteps)),1.0e-30_real64)

  if(.not.ieee_is_finite(max_head_rel) .or. .not.ieee_is_finite(cum_rel)) error stop 'nonfinite A2 error metric'

  write(*,'(*(g0))') 'APPROX02_A2_MULTISTEP|MATERIAL=',trim(material),'|H0=',h0,'|STEPS=',nsteps, &
       '|DURATION=',duration,'|CANDIDATE_TOL=',candidate_tol,'|EXACT_SECONDS=',exact_seconds,'|A2_SECONDS=',a2_seconds, &
       '|RUNTIME_RATIO=',a2_seconds/exact_seconds,'|SPEEDUP_PERCENT=',100.0_real64*(1.0_real64-a2_seconds/exact_seconds), &
       '|EXACT_NONLINEAR=',exact_nonlinear,'|A2_NONLINEAR=',a2_nonlinear, &
       '|EXACT_BACKTRACK=',exact_backtrack,'|A2_BACKTRACK=',a2_backtrack, &
       '|MAX_HEAD_ABS_CM=',max_head_abs,'|MAX_HEAD_REL=',max_head_rel, &
       '|MAX_THETA_ABS=',max_theta_abs,'|MAX_THETA_REL=',max_theta_rel, &
       '|MAX_FLUX_ABS=',max_flux_abs,'|MAX_FLUX_REL=',max_flux_rel, &
       '|FINAL_HEAD_ABS_CM=',final_head_abs,'|FINAL_HEAD_REL=',final_head_rel, &
       '|FINAL_THETA_ABS=',final_theta_abs,'|FINAL_THETA_REL=',final_theta_rel, &
       '|EXACT_CUM_BOTTOM_CM=',exact_cum_exchange(nsteps),'|A2_CUM_BOTTOM_CM=',a2_cum_exchange, &
       '|CUM_BOTTOM_ABS_CM=',cum_abs,'|CUM_BOTTOM_REL=',cum_rel
  print '(A)','FPE_APPROX02_A2_MULTISTEP=PASS'

contains

  subroutine initialize_request(req,p,provider,source_sink,top_provider,h_init,theta_init,hbot,tol)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::provider
    type(b110_source_sink_provider_t),target,intent(in)::source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top_provider
    real(real64),intent(in)::h_init(:),theta_init(:),hbot,tol
    req%parameters=>p
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=h_init
    req%base_state%water_content=theta_init
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-2.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=7
    req%boundary%top_flux=0.0_real64
    req%boundary%bottom_head=hbot
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=48
    req%numerical%max_backtracking=16
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-12_real64
    req%numerical%compartment_balance_tolerance=tol
    req%numerical%total_balance_tolerance=tol
    req%numerical%head_abs_tolerance=tol
    req%numerical%head_rel_tolerance=tol
    req%numerical%ponding_tolerance=exact_tol
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
    req%step_duration=duration
    req%request_interface_sensitivity=.false.
  end subroutine initialize_request

  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop 'unknown material'
    end select
  end subroutine material_parameters
end program test_fpe_approx02_a2_multistep
