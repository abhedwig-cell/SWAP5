program test_bofek00_adaptive_wet_trajectory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: HORIZON=0.12_real64
  real(real64), parameter :: DTMIN=0.001_real64, DTMAX=0.02_real64
  real(real64), parameter :: FACT_INC=2.0_real64, FACT_DEC=0.5_real64, FACT_FAIL=2.0_real64
  integer, parameter :: NUMBIT_CRIT=4, MAXIT_POLICY=8, MAX_ATTEMPTS=256
  real(real64), parameter :: RAIN=12.0_real64, PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: HARD=1.0e-10_real64, EPS_TIME=1.0e-13_real64

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)
  real(real64) :: t, dt, cumulative_runoff, max_abs_ledger
  integer :: attempts, accepted, rejected, growths, reductions
  integer :: total_nl, total_back

  call setup()
  call initialize_state(-20.0_real64,state)

  t=0.0_real64
  dt=sqrt(DTMIN*DTMAX)
  cumulative_runoff=0.0_real64
  max_abs_ledger=0.0_real64
  attempts=0; accepted=0; rejected=0; growths=0; reductions=0
  total_nl=0; total_back=0

  write(*,'(*(g0))') 'F_PE_BOFEK00_ADAPTIVE_BEGIN|DTMIN=',DTMIN,'|DTMAX=',DTMAX, &
       '|DT0=',dt,'|NUMBIT_CRIT=',NUMBIT_CRIT,'|MAXIT=',MAXIT_POLICY, &
       '|FACT_INC=',FACT_INC,'|FACT_DEC=',FACT_DEC,'|FACT_FAIL=',FACT_FAIL

  do while (t < HORIZON-EPS_TIME)
    call execute_attempt()
    if (attempts >= MAX_ATTEMPTS) call require(.false.,'attempt limit')
  end do

  call require(abs(t-HORIZON)<=EPS_TIME,'exact experiment horizon')
  write(*,'(*(g0))') 'F_PE_BOFEK00_ADAPTIVE_END|TIME=',t,'|ATTEMPTS=',attempts, &
       '|ACCEPTED=',accepted,'|REJECTED=',rejected,'|GROWTHS=',growths, &
       '|REDUCTIONS=',reductions,'|TOTAL_NL=',total_nl,'|TOTAL_BACK=',total_back, &
       '|CUM_RUNOFF=',cumulative_runoff,'|TOP_H=',state%pressure_head(1), &
       '|POND=',state%ponding_depth,'|MAX_ABS_LEDGER=',max_abs_ledger
  write(*,'(A)') 'F_PE_BOFEK00_ADAPTIVE_TRAJECTORY=PASS'

contains

  subroutine setup()
    integer :: k
    real(real64) :: mm
    p%parameter_set_id=26092803_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);c=0.0_real64
    mm=1.0_real64-1.0_real64/1.455_real64
    do k=1,numnod
      c(1,k)=0.032_real64;c(2,k)=0.423_real64;c(3,k)=4.75_real64
      c(4,k)=0.0135_real64;c(5,k)=0.365_real64;c(6,k)=1.455_real64;c(7,k)=mm
      c(8,k)=c(4,k);c(9,k)=0.0_real64;c(10,k)=c(3,k)
      c(11,k)=0.999_real64;c(12,k)=0.99_real64*c(3,k);c(22,k)=-1.0e6_real64;c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine setup

  subroutine initialize_state(h0,s)
    real(real64),intent(in)::h0
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,sqrt(DTMIN*DTMAX))
    heads=h0
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine execute_attempt()
    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,try_dt,storage0,storage1,ledger,new_dt
    logical::ok

    try_dt=min(dt,HORIZON-t)
    attempts=attempts+1

    call bind_b110_default_mvg_provider(constitutive,hp,try_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,ok)
    call require(ok,'fixed conductivity')
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,try_dt, &
         RAIN,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)

    req=soil_water_solve_request_t()
    req%parameters=>p;req%base_state=state;req%step_duration=try_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=MAXIT_POLICY;req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=DTMIN
    req%numerical%compartment_balance_tolerance=HARD;req%numerical%total_balance_tolerance=HARD
    req%numerical%head_abs_tolerance=1.0e-9_real64;req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=HARD
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)

    write(*,'(*(g0))') 'F_PE_BOFEK00_ADAPTIVE_ATTEMPT|N=',attempts,'|T0=',t,'|DT=',try_dt, &
         '|STATUS=',res%status,'|NL=',res%diagnostics%nonlinear_iterations, &
         '|BACK=',res%diagnostics%backtracking_attempts

    if (res%status /= SW_SOLVE_CONVERGED) then
      rejected=rejected+1
      new_dt=dt
      if (new_dt > FACT_FAIL*DTMIN) then
        new_dt=new_dt/FACT_FAIL
      else
        new_dt=DTMIN
      end if
      if (new_dt < dt-EPS_TIME) reductions=reductions+1
      dt=new_dt
      call require(dt>=DTMIN-EPS_TIME,'failure reduction below dtmin')
      write(*,'(*(g0))') 'F_PE_BOFEK00_ADAPTIVE_REJECT|N=',attempts,'|NEXT_DT=',dt
      return
    end if

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,final_top)
    call require(final_top%status>0,'final top available')
    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-RAIN*try_dt+final_top%runoff_depth-res%bottom_flux*try_dt
    call require(ieee_is_finite(ledger).and.abs(ledger)<=5.0e-8_real64,'combined water ledger')

    accepted=accepted+1
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    cumulative_runoff=cumulative_runoff+final_top%runoff_depth
    max_abs_ledger=max(max_abs_ledger,abs(ledger))
    t=t+try_dt
    state=res%candidate_state

    write(*,'(*(g0))') 'F_PE_BOFEK00_ADAPTIVE_ACCEPT|N=',accepted,'|T1=',t,'|DT=',try_dt, &
         '|NL=',res%diagnostics%nonlinear_iterations,'|BACK=',res%diagnostics%backtracking_attempts, &
         '|TOP_H=',state%pressure_head(1),'|POND=',state%ponding_depth,'|RUNOFF=',final_top%runoff_depth, &
         '|CUM_RUNOFF=',cumulative_runoff,'|QTOP=',res%top_flux,'|QBOT=',res%bottom_flux, &
         '|LEDGER=',ledger,'|ROUTE=',trim(final_top%route)

    new_dt=dt
    if (res%diagnostics%nonlinear_iterations <= NUMBIT_CRIT) new_dt=min(new_dt*FACT_INC,DTMAX)
    if (res%diagnostics%nonlinear_iterations >= MAXIT_POLICY) new_dt=max(new_dt*FACT_DEC,DTMIN)
    if (new_dt > dt+EPS_TIME) growths=growths+1
    if (new_dt < dt-EPS_TIME) reductions=reductions+1
    dt=new_dt
  end subroutine execute_attempt

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_BOFEK00_ADAPTIVE_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_bofek00_adaptive_wet_trajectory
