program test_fpe_timeint15_fluxquad
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
  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &
       bind_fpe_timeint13_predicted_k_provider
  implicit none

  integer :: timeint15_mode
  real(8) :: timeint15_origin_operator(1000)
  common /timeint15_trap_common/ timeint15_mode, timeint15_origin_operator

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: base_constitutive
  type(fpe_timeint13_predicted_k_provider_t),target :: predicted_constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),k_n(:),k_nm1(:),k_pred(:)
  real(real64),allocatable :: tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,horizon
  real(real64),parameter :: qbar=3.0_real64,qamp=1.0_real64,period=0.060_real64
  integer :: steps,step,total_nl,total_back,total_jac,total_lin,total_alt,clamp_count
  real(real64) :: maxledger,cumledger,cum_input,exact_input,storage_measure_start,storage_end
  real(real64) :: t0,t1,q0,q1,pi

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,dt)

  horizon=0.04_real64
  pi=acos(-1.0_real64)
  steps=nint(horizon/dt)
  call require(abs(real(steps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(k_n(numnod),k_nm1(numnod),k_pred(numnod))
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  call exact_k_from_state(state,k_n)
  k_nm1=k_n

  total_nl=0; total_back=0; total_jac=0; total_lin=0; total_alt=0
  clamp_count=0; maxledger=0.0_real64; cumledger=0.0_real64; cum_input=0.0_real64
  timeint15_mode=0
  timeint15_origin_operator=0.0d0

  ! Accepted BE/KLAG prehistory step ending at measurement t=0.
  q1=qrate(0.0_real64)
  call advance_interval(q1,q1,.false.,.false.)

  storage_measure_start=sum(state%water_content*p%dz)+state%ponding_depth

  do step=1,steps
    t0=real(step-1,real64)*dt
    t1=real(step,real64)*dt
    q0=qrate(t0); q1=qrate(t1)
    call advance_interval(q0,q1,.true.,.true.)
  end do

  storage_end=sum(state%water_content*p%dz)+state%ponding_depth
  exact_input=qbar*horizon + qamp*period/(2.0_real64*pi) * &
       (1.0_real64-cos(2.0_real64*pi*horizon/period))

  write(*,'(*(g0))') 'F_PE_TIMEINT15_P1_RESULT|MATERIAL=',trim(material_id),'|DT=',dt, &
       '|TOP_H=',state%pressure_head(1),'|STORAGE_START=',storage_measure_start,'|STORAGE_END=',storage_end, &
       '|CUM_TRAP_INPUT=',cum_input,'|EXACT_INPUT=',exact_input,'|QUAD_ERROR=',abs(cum_input-exact_input), &
       '|MAX_LEDGER=',maxledger,'|CUM_LEDGER=',cumledger,'|DIRECT_LEDGER=',storage_end-storage_measure_start-cum_input, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin,'|ALT=',total_alt, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|CLAMPS=',clamp_count
  write(*,'(A)') 'F_PE_TIMEINT15_P1=PASS'

contains

  real(real64) function qrate(t) result(q)
    real(real64),intent(in)::t
    q=qbar+qamp*sin(2.0_real64*pi*t/period)
  end function

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=260929151_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      cof(1,i)=tr; cof(2,i)=ts; cof(3,i)=ksat; cof(4,i)=alpha; cof(5,i)=lambda
      cof(6,i)=nvg; cof(7,i)=mm; cof(8,i)=alpha; cof(9,i)=0.0_real64
      cof(10,i)=ksat; cof(11,i)=0.999_real64; cof(12,i)=0.99_real64*ksat
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
    real(real64),allocatable::th(:),kk(:),cp(:),dk(:)
    allocate(th(numnod),kk(numnod),cp(numnod),dk(numnod))
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    heads=h
    call base_constitutive%evaluate(heads,th,kk,cp,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=th
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine exact_k_from_state(s,kout)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(out)::kout(:)
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(s%pressure_head,tmp_theta,tmp_k,tmp_cap,tmp_dk)
    kout=tmp_k
  end subroutine

  subroutine build_origin_operator(s,kvec,qin)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(in)::kvec(:),qin
    real(real64)::kface,grad
    integer::i

    timeint15_origin_operator=0.0d0
    kface=0.5_real64*(kvec(1)+kvec(2))
    grad=(s%pressure_head(1)-s%pressure_head(2))/p%node_distance(2)+1.0_real64
    timeint15_origin_operator(1)=-qin+kface*grad
    do i=2,numnod-1
      kface=0.5_real64*(kvec(i-1)+kvec(i))
      grad=(s%pressure_head(i-1)-s%pressure_head(i))/p%node_distance(i)+1.0_real64
      timeint15_origin_operator(i)=-kface*grad
      kface=0.5_real64*(kvec(i)+kvec(i+1))
      grad=(s%pressure_head(i)-s%pressure_head(i+1))/p%node_distance(i+1)+1.0_real64
      timeint15_origin_operator(i)=timeint15_origin_operator(i)+kface*grad
    end do
    kface=0.5_real64*(kvec(numnod-1)+kvec(numnod))
    grad=(s%pressure_head(numnod-1)-s%pressure_head(numnod))/p%node_distance(numnod)+1.0_real64
    timeint15_origin_operator(numnod)=-kface*grad
  end subroutine

  subroutine advance_interval(q_origin,q_endpoint,trap_mode,measure)
    real(real64),intent(in)::q_origin,q_endpoint
    logical,intent(in)::trap_mode,measure
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_physical_state_t)::origin
    real(real64),allocatable::k_new(:)
    real(real64)::storage0,storage1,ledger,effective_baltol,interval_input
    integer::nclamp

    origin=state
    allocate(k_new(numnod))

    if(trap_mode)then
      timeint15_mode=1
      k_pred=2.0_real64*k_n-k_nm1
    else
      timeint15_mode=0
      k_pred=k_n
    end if

    nclamp=count(k_pred<1.0e-12_real64)
    clamp_count=clamp_count+nclamp
    k_pred=max(k_pred,1.0e-12_real64)

    call build_origin_operator(origin,k_n,q_origin)
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_pred)

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%top_flux=-q_endpoint
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>predicted_constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top

    storage0=sum(origin%water_content*p%dz)+origin%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_alt=total_alt+res%diagnostics%alternative_solver_calls

    call require(res%status==SW_SOLVE_CONVERGED,'solver did not converge')
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite candidate')

    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    if(trap_mode)then
      interval_input=0.5_real64*dt*(q_origin+q_endpoint)
    else
      interval_input=dt*q_endpoint
    end if
    ledger=storage1-storage0-interval_input
    call require(ieee_is_finite(ledger),'nonfinite ledger')
    if(measure)then
      maxledger=max(maxledger,abs(ledger))
      cumledger=cumledger+ledger
      cum_input=cum_input+interval_input
    end if

    call exact_k_from_state(res%candidate_state,k_new)
    k_nm1=k_n
    k_n=k_new
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT15_P1_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine

end program test_fpe_timeint15_fluxquad
