program test_fpe_kimpl_dyntop02_maxit
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_timeint12_dynamic_top_provider, only: fpe_timeint12_dynamic_top_provider_t, &
       bind_fpe_timeint12_dynamic_top_provider
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t),target :: top_lag
  type(fpe_timeint12_dynamic_top_provider_t),target :: top_impl
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:)

  character(len=32) :: material_id,mode
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain
  real(real64),parameter :: step_dt=0.005_real64,horizon=0.12_real64
  real(real64),parameter :: pmax=0.05_real64,rsro=0.05_real64
  integer :: steps,i,total_nl,total_back,total_jac,total_lin,total_alt,maxit_input
  real(real64) :: cumrun,maxledger,storage_end
  character(len=48) :: final_route

  call get_command_argument(1,material_id)
  call get_command_argument(2,mode)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_int(11,maxit_input)

  call setup()
  call initialize_state(h0,state)
  steps=nint(horizon/step_dt)
  total_nl=0; total_back=0; total_jac=0; total_lin=0; total_alt=0
  cumrun=0.0_real64; maxledger=0.0_real64; final_route='none'

  do i=1,steps
    call advance_one()
  end do

  storage_end=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_KIMPL_DYNTOP02_RESULT|MATERIAL=',trim(material_id),'|MODE=',trim(mode), &
       '|MAXIT=',maxit_input,'|STEPS=',steps,'|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|ALT=',total_alt,'|WORK=',total_nl+total_back+total_jac+total_lin, &
       '|RUNOFF=',cumrun,'|POND=',state%ponding_depth,'|STORAGE=',storage_end, &
       '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|MAX_LEDGER=',maxledger,'|ROUTE=',trim(final_route)
  write(*,'(A)') 'F_PE_KIMPL_DYNTOP02=PASS'

contains

  subroutine read_int(idx,x)
    integer,intent(in)::idx
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(idx,s); read(s,*)x
  end subroutine

  subroutine read_real(idx,x)
    integer,intent(in)::idx
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(idx,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::k
    real(real64)::mm
    p%parameter_set_id=26092912_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
      cof(1,k)=tr; cof(2,k)=ts; cof(3,k)=ksat; cof(4,k)=alpha; cof(5,k)=lambda; cof(6,k)=nvg; cof(7,k)=mm
      cof(8,k)=alpha; cof(9,k)=0.0_real64; cof(10,k)=ksat; cof(11,k)=0.999_real64; cof(12,k)=0.99_real64*ksat
      cof(22,k)=-1.0e6_real64; cof(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine advance_one()
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::top_result
    real(real64)::fixed_k,storage0,storage1,ledger,effective_baltol
    logical::ok

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    req=soil_water_solve_request_t()
    req%parameters=>p
    req%base_state=state
    req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=maxit_input
    req%numerical%max_backtracking=8
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/step_dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink

    if(trim(mode)=='KIMPL')then
      req%numerical%conductivity_implicit_mode=1
      call bind_fpe_timeint12_dynamic_top_provider(top_impl,p,hp,state%ponding_depth,step_dt,rain)
      req%evaluation%dynamic_top_boundary=>top_impl
    else if(trim(mode)=='KLAG')then
      req%numerical%conductivity_implicit_mode=0
      call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,ok)
      call require(ok,'fixed K unavailable')
      call bind_b110_dynamic_top_boundary_solver_provider(top_lag,p,hp,1,state%ponding_depth,step_dt, &
           rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,fixed_k)
      req%evaluation%dynamic_top_boundary=>top_lag
    else
      call require(.false.,'invalid mode')
    end if

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_alt=total_alt+res%diagnostics%alternative_solver_calls
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_KIMPL_DYNTOP02_FAILURE|STEP=',i,'|MAXIT=',maxit_input, &
           '|STATUS=',res%status,'|NL=',res%diagnostics%nonlinear_iterations, &
           '|BACK=',res%diagnostics%backtracking_attempts,'|JAC=',res%diagnostics%jacobian_builds, &
           '|LIN=',res%diagnostics%linear_solves
      call require(.false.,'solver failed')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite head')
    call require(all(ieee_is_finite(res%candidate_state%water_content)),'nonfinite water content')

    bc=soil_water_boundary_conditions_t()
    if(trim(mode)=='KIMPL')then
      call top_impl%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
           res%candidate_state%ponding_depth,bc,top_result)
    else
      call top_lag%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
           res%candidate_state%ponding_depth,bc,top_result)
    end if
    call require(top_result%status>0,'final top unavailable')

    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*step_dt+top_result%runoff_depth-res%bottom_flux*step_dt
    call require(ieee_is_finite(ledger),'nonfinite ledger')
    maxledger=max(maxledger,abs(ledger))
    cumrun=cumrun+top_result%runoff_depth
    final_route=top_result%route
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT12A_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_kimpl_dyntop02_maxit
