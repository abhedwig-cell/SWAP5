program test_fpe_timeint12_dyntop_bdf2
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  integer :: timeint04b_floor_mode
  common /timeint04b_floor_common/ timeint04b_floor_mode

  real(8) :: timeint05_a0, timeint05_a1, timeint05_a2
  common /timeint05_coeff_common/ timeint05_a0, timeint05_a1, timeint05_a2

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),water(:),kk(:),cap(:),dk(:),theta_hist(:)
  type(soil_water_physical_state_t) :: state

  character(len=32) :: material_id,mode
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,dt,horizon
  real(real64),parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  integer :: nsteps,step,origin_regime,candidate_regime
  integer :: total_nl,total_back,total_jac,total_lin
  integer :: bdf_steps,be_bootstrap_steps,be_transition_steps,discarded_bdf
  integer :: flux_to_head,head_to_flux
  real(real64) :: cumrun,maxeqres,runoff,eqres
  real(real64) :: prev_dt
  logical :: history_valid,ok

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,h0); call read_real(9,rain)
  call read_real(10,dt); call get_command_argument(11,mode)

  horizon=0.12_real64
  nsteps=nint(horizon/dt)
  call require(abs(real(nsteps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')
  call require(trim(mode)=='BE_FULL' .or. trim(mode)=='BDF2_RAW' .or. trim(mode)=='BDF2_FALLBACK', 'invalid mode')

  call setup()
  call initialize_state(h0,state)
  allocate(theta_hist(numnod))
  theta_hist=state%water_content

  timeint04b_floor_mode=1
  history_valid=.false.
  origin_regime=0
  prev_dt=dt
  total_nl=0; total_back=0; total_jac=0; total_lin=0
  bdf_steps=0; be_bootstrap_steps=0; be_transition_steps=0; discarded_bdf=0
  flux_to_head=0; head_to_flux=0
  cumrun=0.0_real64; maxeqres=0.0_real64

  do step=1,nsteps
    call advance_primary(step)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT12_RESULT|MATERIAL=',trim(material_id),'|MODE=',trim(mode), &
       '|H0=',h0,'|RAIN=',rain,'|DT=',dt,'|STEPS=',nsteps, &
       '|BDF_STEPS=',bdf_steps,'|BE_BOOT=',be_bootstrap_steps,'|BE_TRANS=',be_transition_steps, &
       '|DISCARDED_BDF=',discarded_bdf,'|F2H=',flux_to_head,'|H2F=',head_to_flux, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|RUNOFF=',cumrun, &
       '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|POND=',state%ponding_depth, &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth,'|MAX_EQ_RES=',maxeqres
  write(*,'(A)') 'F_PE_TIMEINT12=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=26092912_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      cof(1,i)=tr; cof(2,i)=ts; cof(3,i)=ksat; cof(4,i)=alpha; cof(5,i)=lambda; cof(6,i)=nvg; cof(7,i)=mm
      cof(8,i)=alpha; cof(9,i)=0.0_real64; cof(10,i)=ksat; cof(11,i)=0.999_real64; cof(12,i)=0.99_real64*ksat
      cof(22,i)=-1.0e6_real64; cof(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod)
    allocate(water(numnod),kk(numnod),cap(numnod),dk(numnod))
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine solve_one(s0,theta_prevprev,step_dt,previous_dt,apply_bdf2,s1,regime,runoff_depth,eq_res, &
                       nl,back,jac,lin,solve_ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::theta_prevprev(:),step_dt,previous_dt
    logical,intent(in)::apply_bdf2
    type(soil_water_physical_state_t),intent(out)::s1
    integer,intent(out)::regime,nl,back,jac,lin
    real(real64),intent(out)::runoff_depth,eq_res
    logical,intent(out)::solve_ok

    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(b110_dynamic_top_boundary_solver_provider_t),target::top
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::top_result
    real(real64)::r,effective_baltol

    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=theta_prevprev
    if(apply_bdf2)then
      timeint02_mode=2
      r=step_dt/previous_dt
      timeint05_a0=(1.0_real64+2.0_real64*r)/(1.0_real64+r)
      timeint05_a1=-(1.0_real64+r)
      timeint05_a2=r*r/(1.0_real64+r)
    else
      timeint02_mode=1
      timeint05_a0=1.0_real64; timeint05_a1=-1.0_real64; timeint05_a2=0.0_real64
    end if

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,step_dt, &
         rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64)

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=s0; req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=1; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/step_dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive; req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    call solver%solve(req,ws,res)
    nl=res%diagnostics%nonlinear_iterations; back=res%diagnostics%backtracking_attempts
    jac=res%diagnostics%jacobian_builds; lin=res%diagnostics%linear_solves
    solve_ok=res%status==SW_SOLVE_CONVERGED
    regime=0; runoff_depth=0.0_real64; eq_res=huge(1.0_real64)
    if(.not.solve_ok)return
    if(.not.all(ieee_is_finite(res%candidate_state%pressure_head)))then
      solve_ok=.false.; return
    end if

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,top_result)
    if(top_result%status/=SW_TOP_BOUNDARY_AVAILABLE)then
      solve_ok=.false.; return
    end if
    regime=top_result%regime
    runoff_depth=top_result%runoff_depth
    if(.not.res%integrated_mass_balance_residual_available)then
      solve_ok=.false.; return
    end if
    eq_res=abs(res%integrated_mass_balance_residual_cm)
    if(.not.ieee_is_finite(eq_res))then
      solve_ok=.false.; return
    end if
    s1=res%candidate_state
  end subroutine

  subroutine add_work(nl,back,jac,lin)
    integer,intent(in)::nl,back,jac,lin
    total_nl=total_nl+nl; total_back=total_back+back
    total_jac=total_jac+jac; total_lin=total_lin+lin
  end subroutine

  subroutine count_transition(old_regime,new_regime)
    integer,intent(in)::old_regime,new_regime
    if(old_regime==SW_TOP_BOUNDARY_REGIME_FLUX .and. new_regime==SW_TOP_BOUNDARY_REGIME_HEAD) flux_to_head=flux_to_head+1
    if(old_regime==SW_TOP_BOUNDARY_REGIME_HEAD .and. new_regime==SW_TOP_BOUNDARY_REGIME_FLUX) head_to_flux=head_to_flux+1
  end subroutine

  subroutine advance_primary(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::origin,candidate,be_candidate
    real(real64),allocatable::origin_theta(:)
    integer::reg,nl,back,jac,lin,be_reg,be_nl,be_back,be_jac,be_lin
    real(real64)::run,eres,be_run,be_eres
    logical::apply_bdf,transition,be_ok

    origin=state
    allocate(origin_theta(numnod)); origin_theta=origin%water_content

    if(trim(mode)=='BE_FULL')then
      call solve_one(origin,theta_hist,dt,prev_dt,.false.,candidate,reg,run,eres,nl,back,jac,lin,ok)
      call require(ok,'BE full solve failed')
      call add_work(nl,back,jac,lin)
      be_bootstrap_steps=be_bootstrap_steps+1
      if(origin_regime/=0 .and. reg/=origin_regime)call count_transition(origin_regime,reg)
      theta_hist=origin_theta; prev_dt=dt; state=candidate; origin_regime=reg
      cumrun=cumrun+run; maxeqres=max(maxeqres,eres)
      history_valid=.true.
      return
    end if

    apply_bdf=history_valid
    if(.not.apply_bdf)then
      call solve_one(origin,theta_hist,dt,prev_dt,.false.,candidate,reg,run,eres,nl,back,jac,lin,ok)
      call require(ok,'bootstrap BE solve failed')
      call add_work(nl,back,jac,lin)
      be_bootstrap_steps=be_bootstrap_steps+1
      if(origin_regime/=0 .and. reg/=origin_regime)call count_transition(origin_regime,reg)
      theta_hist=origin_theta; prev_dt=dt; state=candidate; origin_regime=reg
      cumrun=cumrun+run; maxeqres=max(maxeqres,eres)
      history_valid=.true.
      return
    end if

    call solve_one(origin,theta_hist,dt,prev_dt,.true.,candidate,reg,run,eres,nl,back,jac,lin,ok)
    call require(ok,'BDF2 candidate solve failed')
    call add_work(nl,back,jac,lin)
    bdf_steps=bdf_steps+1

    transition=(origin_regime/=0 .and. reg/=origin_regime)
    if(trim(mode)=='BDF2_FALLBACK' .and. transition)then
      discarded_bdf=discarded_bdf+1
      call count_transition(origin_regime,reg)
      call solve_one(origin,theta_hist,dt,prev_dt,.false.,be_candidate,be_reg,be_run,be_eres, &
           be_nl,be_back,be_jac,be_lin,be_ok)
      call require(be_ok,'transition BE fallback failed')
      call add_work(be_nl,be_back,be_jac,be_lin)
      be_transition_steps=be_transition_steps+1
      theta_hist=origin_theta; prev_dt=dt; state=be_candidate; origin_regime=be_reg
      cumrun=cumrun+be_run; maxeqres=max(maxeqres,be_eres)
      history_valid=.true.
      return
    end if

    if(transition)call count_transition(origin_regime,reg)
    theta_hist=origin_theta; prev_dt=dt; state=candidate; origin_regime=reg
    cumrun=cumrun+run; maxeqres=max(maxeqres,eres)
    history_valid=.true.
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT12_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint12_dyntop_bdf2
