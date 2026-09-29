program test_fpe_timeint12a_dynamic_be
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint12a_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fpe_timeint12a_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),water(:),kk(:),cap(:),dk(:)
  character(len=32) :: material_id,regime_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain
  integer :: kimpl,step,total_nl,total_back,total_jac,total_lin
  real(real64), parameter :: DT=0.005_real64,HORIZON=0.12_real64
  real(real64), parameter :: PMAX=0.05_real64,RSRO=0.05_real64
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64,BALTOL_DEPTH=2.8e-16_real64
  real(real64) :: cumrun,maxledger
  integer :: final_regime
  character(len=48) :: final_route

  call get_command_argument(1,material_id)
  call get_command_argument(2,regime_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_int(11,kimpl)

  call setup()
  call initialize_state(h0,state)
  total_nl=0; total_back=0; total_jac=0; total_lin=0
  cumrun=0.0_real64; maxledger=0.0_real64
  final_regime=0; final_route='none'

  do step=1,nint(HORIZON/DT)
    call advance_one(step)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT12A_RESULT|MATERIAL=',trim(material_id),'|REGIME=',trim(regime_id), &
       '|KIMPL=',kimpl,'|STEPS=',nint(HORIZON/DT),'|NL=',total_nl,'|BACK=',total_back, &
       '|JAC=',total_jac,'|LIN=',total_lin,'|RUNOFF=',cumrun,'|POND=',state%ponding_depth, &
       '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|MAX_LEDGER=',maxledger,'|FINAL_REGIME=',final_regime,'|FINAL_ROUTE=',trim(final_route)
  write(*,'(A)') 'F_PE_TIMEINT12A=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i; real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine
  subroutine read_int(i,x)
    integer,intent(in)::i; integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=260929121_int64; p%active_nodes=numnod
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
    allocate(water(numnod),kk(numnod),cap(numnod),dk(numnod))
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,DT)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine advance_one(step_index)
    integer,intent(in)::step_index
    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::top_result
    real(real64)::fixed_k,effective_baltol,storage0,storage1,ledger
    logical::ok

    call bind_b110_default_mvg_provider(constitutive,hp,DT)
    if(kimpl==0)then
      call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,ok)
      call require(ok,'fixed top conductivity')
      call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,DT, &
           rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)
    else
      call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,DT, &
           rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64)
    end if

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=DT
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=kimpl; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/DT)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive; req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT12A_FAILURE|STEP=',step_index,'|KIMPL=',kimpl,'|STATUS=',res%status, &
           '|NL=',res%diagnostics%nonlinear_iterations,'|BACK=',res%diagnostics%backtracking_attempts
      call require(.false.,'solver did not converge')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'finite head')
    call require(all(ieee_is_finite(res%candidate_state%water_content)),'finite water')

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,top_result)
    call require(top_result%status>0,'final top available')
    final_regime=top_result%regime; final_route=top_result%route

    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*DT+top_result%runoff_depth-res%bottom_flux*DT
    call require(abs(ledger)<=5.0e-8_real64,'ledger')
    maxledger=max(maxledger,abs(ledger)); cumrun=cumrun+top_result%runoff_depth

    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond; character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_TIMEINT12A_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint12a_dynamic_be
