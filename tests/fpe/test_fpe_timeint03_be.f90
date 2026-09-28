program test_fpe_timeint03_be
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),water(:),kk(:),cap(:),dk(:),theta_prevprev(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,dt,horizon
  integer :: requested_temporal_mode,kimpl,maxit_input,steps,step,total_nl,total_back,total_jac,total_lin
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64,BALTOL_DEPTH=2.8e-16_real64

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,dt)
  call read_int(10,requested_temporal_mode); call read_int(11,kimpl); call read_optional_int(12,maxit_input,8)
  horizon=0.04_real64
  steps=nint(horizon/dt)
  call require(abs(steps*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')
  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(theta_prevprev(numnod))
  theta_prevprev=state%water_content
  total_nl=0; total_back=0; total_jac=0; total_lin=0

  do step=1,steps
    call advance_one(step)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT03_RESULT|MATERIAL=',trim(material_id),'|RAIN=',rain,'|DT=',dt, &
       '|TMODE=',requested_temporal_mode,'|KIMPL=',kimpl,'|TOP_H=',state%pressure_head(1), &
       '|MID_H=',state%pressure_head((numnod+1)/2),'|BOTTOM_H=',state%pressure_head(numnod), &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin
  write(*,'(A)') 'F_PE_TIMEINT03=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine read_int(i,x)
    integer,intent(in)::i
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine read_optional_int(i,x,default_value)
    integer,intent(in)::i,default_value
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s)
    if(len_trim(s)==0)then
      x=default_value
    else
      read(s,*)x
    end if
  end subroutine

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=26092842_int64; p%active_nodes=numnod
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

  subroutine advance_one(step_index)
    integer,intent(in)::step_index
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64),allocatable :: theta_n(:)
    real(real64)::effective_baltol

    allocate(theta_n(numnod)); theta_n=state%water_content
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=theta_prevprev
    if(requested_temporal_mode==2 .and. step_index>=2)then
      timeint02_mode=2
    else
      timeint02_mode=1
    end if

    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    req=soil_water_solve_request_t()
    req%parameters=>p
    req%base_state=state
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-rain
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=maxit_input
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=kimpl
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top

    call solver%solve(req,ws,res)
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT03_FAILURE|STEP=',step_index,'|STATUS=',res%status, &
           '|RETRY=',merge(1,0,res%retry_advised),'|NL=',res%diagnostics%nonlinear_iterations, &
           '|BACK=',res%diagnostics%backtracking_attempts,'|JAC=',res%diagnostics%jacobian_builds, &
           '|LIN=',res%diagnostics%linear_solves,'|MAXIT=',maxit_input
      call require(.false.,'solver did not converge')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite candidate')
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves

    theta_prevprev=theta_n
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT03_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine

end program test_fpe_timeint03_be
