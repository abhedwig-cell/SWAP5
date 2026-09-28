program test_fpe_dynerr01_indicator
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_dynerr01_temporal_indicator, only: evaluate_reference_richards_temporal_indicator
  implicit none

  real(real64), parameter :: HIST_DT=0.005_real64
  real(real64), parameter :: DTMIN=1.0e-6_real64
  real(real64), parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: BAL_CONFIG=1.0e-12_real64, BAL_DEPTH=2.8e-16_real64
  real(real64), parameter :: HEAD_TOL=1.0e-9_real64
  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:),previous_derivative(:)
  type(soil_water_physical_state_t) :: initial,origin,full,half1,half2
  character(len=32) :: case_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,step_dt
  real(real64) :: r_hist,l_hist,r_full,l_full,r_h1,l_h1,r_h2,l_h2
  real(real64) :: indicator,actual_h,runoff_delta,storage_delta,max_ledger,derivative
  integer :: w_hist,w_full,w_h1,w_h2,ind_status,regime_hist,regime_full,regime_h1,regime_h2
  logical :: ok_hist,ok_full,ok_h1,ok_h2

  call get_command_argument(1,case_id)
  call read_real(2,tr);call read_real(3,ts);call read_real(4,alpha);call read_real(5,nvg)
  call read_real(6,ksat);call read_real(7,lambda);call read_real(8,h0);call read_real(9,rain);call read_real(10,step_dt)
  call setup()
  call initialize_state(h0,initial)

  allocate(previous_derivative(numnod))
  call advance_step(initial,HIST_DT,previous_derivative,.false.,origin,r_hist,l_hist,w_hist,ind_status,indicator,regime_hist,derivative,ok_hist)
  if(.not.ok_hist)then
    write(*,'(*(g0))')'F_PE_DYNERR01|CASE=',trim(case_id),'|DT=',step_dt,'|OK=0|STAGE=HISTORY'
    stop
  end if
  previous_derivative=(origin%pressure_head-initial%pressure_head)/HIST_DT

  call advance_step(origin,step_dt,previous_derivative,.true.,full,r_full,l_full,w_full,ind_status,indicator,regime_full,derivative,ok_full)
  call advance_step(origin,0.5_real64*step_dt,previous_derivative,.false.,half1,r_h1,l_h1,w_h1,ind_status,actual_h,regime_h1,derivative,ok_h1)
  if(ok_h1)then
    call advance_step(half1,0.5_real64*step_dt,previous_derivative,.false.,half2,r_h2,l_h2,w_h2,ind_status,actual_h,regime_h2,derivative,ok_h2)
  else
    ok_h2=.false.; r_h2=0.0_real64;l_h2=0.0_real64;w_h2=0;regime_h2=0
  end if

  if(.not.(ok_full.and.ok_h1.and.ok_h2))then
    write(*,'(*(g0))')'F_PE_DYNERR01|CASE=',trim(case_id),'|DT=',step_dt,'|OK=0|STAGE=PHYSICAL', &
      '|FULL=',merge(1,0,ok_full),'|H1=',merge(1,0,ok_h1),'|H2=',merge(1,0,ok_h2)
    stop
  end if

  actual_h=maxval(abs(full%pressure_head-half2%pressure_head))
  runoff_delta=abs(r_full-(r_h1+r_h2))
  storage_delta=abs(storage(full)-storage(half2))
  max_ledger=max(abs(l_full),abs(l_h1),abs(l_h2))
  write(*,'(*(g0))')'F_PE_DYNERR01|CASE=',trim(case_id),'|DT=',step_dt,'|OK=1', &
    '|IND_STATUS=',ind_status,'|IND=',indicator,'|ACTUAL_H=',actual_h,'|RUNOFF_D=',runoff_delta, &
    '|STORAGE_D=',storage_delta,'|MAX_LEDGER=',max_ledger,'|REGIME=',regime_full, &
    '|REGIME_FULL=',regime_full,'|REGIME_H1=',regime_h1,'|REGIME_H2=',regime_h2, &
    '|TOP_FULL=',full%pressure_head(1),'|TOP_H1=',half1%pressure_head(1),'|TOP_H2=',half2%pressure_head(1), &
    '|POND_FULL=',full%ponding_depth,'|POND_H1=',half1%ponding_depth,'|POND_H2=',half2%ponding_depth,'|DERIV=',derivative, &
    '|WORK_FULL=',w_full,'|WORK_HALVES=',w_h1+w_h2
contains
  subroutine read_real(i,x)
    integer,intent(in)::i;real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s);read(s,*)x
  end subroutine

  subroutine setup()
    integer::k;real(real64)::mm
    p%parameter_set_id=26092821_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);c=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
      c(1,k)=tr;c(2,k)=ts;c(3,k)=ksat;c(4,k)=alpha;c(5,k)=lambda;c(6,k)=nvg;c(7,k)=mm
      c(8,k)=alpha;c(9,k)=0.0_real64;c(10,k)=ksat;c(11,k)=0.999_real64;c(12,k)=0.99_real64*ksat
      c(22,k)=-1.0e6_real64;c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod));qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,HIST_DT)
    heads=h;call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod;allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine

  subroutine advance_step(s0,dt,prev,need_indicator,s1,runoff,ledger,work,indicator_status,indicator_bound,top_regime,top_derivative,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::dt,prev(:)
    logical,intent(in)::need_indicator
    type(soil_water_physical_state_t),intent(out)::s1
    real(real64),intent(out)::runoff,ledger,indicator_bound,top_derivative
    integer,intent(out)::work,indicator_status,top_regime
    logical,intent(out)::ok
    type(b110_dynamic_top_boundary_solver_provider_t),target::top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    type(soil_water_temporal_indicator_request_t)::ireq
    type(soil_water_temporal_indicator_result_t)::ires
    real(real64)::fixed_k,effective_bal,s0store,s1store
    logical::k_ok

    ok=.false.;runoff=0.0_real64;ledger=0.0_real64;work=0
    indicator_status=0;indicator_bound=huge(0.0_real64);top_regime=0;top_derivative=0.0_real64
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)return
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=s0;req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8;req%numerical%max_backtracking=8;req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1;req%numerical%min_step_duration=DTMIN
    effective_bal=max(BAL_CONFIG,BAL_DEPTH/dt)
    req%numerical%compartment_balance_tolerance=effective_bal;req%numerical%total_balance_tolerance=effective_bal
    req%numerical%head_abs_tolerance=HEAD_TOL;req%numerical%head_rel_tolerance=HEAD_TOL
    req%numerical%ponding_tolerance=BAL_CONFIG
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top
    s0store=storage(s0)
    call solver%solve(req,ws,res)
    work=res%diagnostics%nonlinear_iterations+res%diagnostics%backtracking_attempts+res%diagnostics%jacobian_builds+res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)return
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1),res%candidate_state%ponding_depth,bc,final_top)
    if(final_top%status<=0)return
    s1=res%candidate_state;runoff=final_top%runoff_depth
    s1store=storage(s1)
    ledger=s1store-s0store-rain*dt+runoff-res%bottom_flux*dt
    if(.not.ieee_is_finite(ledger).or.abs(ledger)>5.0e-8_real64)return
    top_regime=final_top%regime
    if(final_top%surface_head_derivative_available)top_derivative=final_top%surface_head_dpressure_head_top
    if(need_indicator)then
      ireq=soil_water_temporal_indicator_request_t()
      ireq%previous_right_derivative_available=.true.
      allocate(ireq%previous_right_derivative(numnod));ireq%previous_right_derivative=prev
      call evaluate_reference_richards_temporal_indicator(req,res,ireq,ires)
      indicator_status=ires%status
      if(ires%status==SW_TEMPORAL_INDICATOR_AVAILABLE)indicator_bound=ires%head_inf_bound
    end if
    ok=.true.
  end subroutine

  real(real64) function storage(s) result(v)
    type(soil_water_physical_state_t),intent(in)::s
    v=sum(s%water_content*p%dz)+s%ponding_depth
  end function
end program test_fpe_dynerr01_indicator
