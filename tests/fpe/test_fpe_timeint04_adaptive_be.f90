program test_fpe_timeint04_adaptive_be
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: REF_DTMIN=0.001_real64, REF_DTMAX=0.020_real64
  real(real64), parameter :: AUTO_FLOOR=1.0e-6_real64, AUTO_CEILING=0.080_real64
  real(real64), parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: BAL_CONFIG=1.0e-12_real64, BAL_DEPTH=2.8e-16_real64, HEAD_TOL=1.0e-9_real64
  real(real64), parameter :: H_SCALE=0.50_real64, THETA_SCALE=1.0e-4_real64, EPS_TIME=1.0e-13_real64

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)
  character(len=32) :: case_id,mode
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,horizon,safety

  type result_t
    logical :: ok=.false.
    integer :: attempts=0,accepted=0,rejected=0,solver_rejected=0,temporal_rejected=0
    integer :: work=0
    real(real64) :: runoff=0.0_real64,max_ledger=0.0_real64
    real(real64) :: top_h=0.0_real64,mid_h=0.0_real64,bottom_h=0.0_real64,pond=0.0_real64,storage=0.0_real64
  end type result_t
  type(result_t) :: out

  call get_command_argument(1,case_id); call get_command_argument(2,mode)
  call read_real(3,tr);call read_real(4,ts);call read_real(5,alpha);call read_real(6,nvg)
  call read_real(7,ksat);call read_real(8,lambda);call read_real(9,h0);call read_real(10,rain)
  call read_real(11,horizon);call read_real(12,safety)
  call setup()
  if(trim(mode)=='REFERENCE')then
    call run_reference(out)
  else
    call run_auto(safety,out)
  end if
  if(.not.out%ok)then
    write(*,'(*(g0))')'F_PE_TIMEINT04|CASE=',trim(case_id),'|MODE=',trim(mode),'|OK=0', &
      '|ATTEMPTS=',out%attempts,'|ACCEPTED=',out%accepted,'|REJECTED=',out%rejected, &
      '|SOLVER_REJECTED=',out%solver_rejected,'|TEMPORAL_REJECTED=',out%temporal_rejected,'|WORK=',out%work
    stop
  end if
  write(*,'(*(g0))')'F_PE_TIMEINT04|CASE=',trim(case_id),'|MODE=',trim(mode),'|OK=1', &
    '|ATTEMPTS=',out%attempts,'|ACCEPTED=',out%accepted,'|REJECTED=',out%rejected, &
    '|SOLVER_REJECTED=',out%solver_rejected,'|TEMPORAL_REJECTED=',out%temporal_rejected,'|WORK=',out%work, &
    '|RUNOFF=',out%runoff,'|TOP_H=',out%top_h,'|MID_H=',out%mid_h,'|BOTTOM_H=',out%bottom_h, &
    '|POND=',out%pond,'|STORAGE=',out%storage,'|MAX_LEDGER=',out%max_ledger

contains
  subroutine read_real(i,x)
    integer,intent(in)::i; real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s);read(s,*)x
  end subroutine

  subroutine setup()
    integer::k;real(real64)::mm
    p%parameter_set_id=26092842_int64;p%active_nodes=numnod
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

  subroutine initialize_state(s)
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,sqrt(REF_DTMIN*REF_DTMAX))
    heads=h0;call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod;allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine

  real(real64) function state_storage(s) result(v)
    type(soil_water_physical_state_t),intent(in)::s
    v=sum(s%water_content*p%dz)+s%ponding_depth
  end function

  subroutine solve_one(s0,dt,s1,runoff,ledger,work,nlit,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::dt
    type(soil_water_physical_state_t),intent(out)::s1
    real(real64),intent(out)::runoff,ledger
    integer,intent(out)::work,nlit
    logical,intent(out)::ok
    type(b110_dynamic_top_boundary_solver_provider_t),target::top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,effective_bal,s0store,s1store
    logical::k_ok

    ok=.false.;runoff=0.0_real64;ledger=0.0_real64;work=0;nlit=0
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)return
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=s0;req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8;req%numerical%max_backtracking=8;req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1;req%numerical%min_step_duration=AUTO_FLOOR
    effective_bal=max(BAL_CONFIG,BAL_DEPTH/dt)
    req%numerical%compartment_balance_tolerance=effective_bal;req%numerical%total_balance_tolerance=effective_bal
    req%numerical%head_abs_tolerance=HEAD_TOL;req%numerical%head_rel_tolerance=HEAD_TOL;req%numerical%ponding_tolerance=BAL_CONFIG
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top
    s0store=state_storage(s0)
    call solver%solve(req,ws,res)
    nlit=res%diagnostics%nonlinear_iterations
    work=res%diagnostics%nonlinear_iterations+res%diagnostics%backtracking_attempts+res%diagnostics%jacobian_builds+res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)return
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1),res%candidate_state%ponding_depth,bc,final_top)
    if(final_top%status<=0)return
    s1=res%candidate_state;runoff=final_top%runoff_depth
    s1store=state_storage(s1)
    ledger=s1store-s0store-rain*dt+runoff-res%bottom_flux*dt
    if(.not.ieee_is_finite(ledger).or.abs(ledger)>5.0e-8_real64)return
    ok=.true.
  end subroutine

  subroutine finalize_result(s,r)
    type(soil_water_physical_state_t),intent(in)::s
    type(result_t),intent(inout)::r
    r%top_h=s%pressure_head(1);r%mid_h=s%pressure_head((numnod+1)/2);r%bottom_h=s%pressure_head(numnod)
    r%pond=s%ponding_depth;r%storage=state_storage(s);r%ok=.true.
  end subroutine

  subroutine run_reference(r)
    type(result_t),intent(out)::r
    type(soil_water_physical_state_t)::state,candidate
    real(real64)::t,dt,try_dt,runoff,ledger,new_dt
    integer::work,nlit
    logical::ok
    r=result_t();call initialize_state(state)
    t=0.0_real64;dt=sqrt(REF_DTMIN*REF_DTMAX)
    do while(t<horizon-EPS_TIME)
      try_dt=min(dt,horizon-t);r%attempts=r%attempts+1
      call solve_one(state,try_dt,candidate,runoff,ledger,work,nlit,ok);r%work=r%work+work
      if(.not.ok)then
        r%rejected=r%rejected+1;r%solver_rejected=r%solver_rejected+1
        new_dt=max(REF_DTMIN,0.5_real64*dt)
        if(new_dt>=dt-EPS_TIME)return
        dt=new_dt;cycle
      end if
      state=candidate;r%accepted=r%accepted+1;r%runoff=r%runoff+runoff;r%max_ledger=max(r%max_ledger,abs(ledger))
      t=t+try_dt;new_dt=dt
      if(nlit<=4)new_dt=min(2.0_real64*new_dt,REF_DTMAX)
      if(nlit>=8)new_dt=max(0.5_real64*new_dt,REF_DTMIN)
      dt=new_dt
    end do
    call finalize_result(state,r)
  end subroutine

  subroutine run_auto(safety_factor,r)
    real(real64),intent(in)::safety_factor
    type(result_t),intent(out)::r
    type(soil_water_physical_state_t)::state,candidate,origin
    real(real64),allocatable::prev_hdot(:),prev_tdot(:),cur_hdot(:),cur_tdot(:)
    real(real64)::t,dt,try_dt,runoff,ledger,score,factor,new_dt,retry_factor
    integer::work,nlit
    logical::ok,history_available
    r=result_t();call initialize_state(state)
    allocate(prev_hdot(numnod),prev_tdot(numnod),cur_hdot(numnod),cur_tdot(numnod))
    prev_hdot=0.0_real64;prev_tdot=0.0_real64;history_available=.false.
    t=0.0_real64;dt=sqrt(REF_DTMIN*REF_DTMAX)

    do while(t<horizon-EPS_TIME)
      origin=state;try_dt=min(dt,horizon-t);r%attempts=r%attempts+1
      call solve_one(origin,try_dt,candidate,runoff,ledger,work,nlit,ok);r%work=r%work+work
      if(.not.ok)then
        r%rejected=r%rejected+1;r%solver_rejected=r%solver_rejected+1
        new_dt=max(AUTO_FLOOR,0.5_real64*try_dt)
        if(new_dt>=try_dt-EPS_TIME)return
        dt=new_dt;cycle
      end if

      cur_hdot=(candidate%pressure_head-origin%pressure_head)/try_dt
      cur_tdot=(candidate%water_content-origin%water_content)/try_dt

      if(.not.history_available)then
        score=0.0_real64
      else
        score=max(maxval(abs(0.5_real64*try_dt*(cur_hdot-prev_hdot)))/H_SCALE, &
                  maxval(abs(0.5_real64*try_dt*(cur_tdot-prev_tdot)))/THETA_SCALE)
      end if

      if(history_available .and. score>1.0_real64)then
        r%rejected=r%rejected+1;r%temporal_rejected=r%temporal_rejected+1
        retry_factor=max(0.25_real64,min(0.8_real64,safety_factor/sqrt(max(score,1.0e-12_real64))))
        new_dt=max(AUTO_FLOOR,try_dt*retry_factor)
        if(new_dt>=try_dt-EPS_TIME)return
        dt=new_dt;cycle
      end if

      state=candidate;r%accepted=r%accepted+1;r%runoff=r%runoff+runoff;r%max_ledger=max(r%max_ledger,abs(ledger))
      t=t+try_dt
      prev_hdot=cur_hdot;prev_tdot=cur_tdot;history_available=.true.

      if(score<=0.0_real64)then
        factor=2.0_real64
      else
        factor=max(0.5_real64,min(2.0_real64,safety_factor/sqrt(max(score,1.0e-12_real64))))
      end if
      dt=min(AUTO_CEILING,max(AUTO_FLOOR,try_dt*factor))
    end do
    call finalize_result(state,r)
  end subroutine
end program test_fpe_timeint04_adaptive_be
