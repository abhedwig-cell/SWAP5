program test_fpe_timeint16b_startup
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

  integer :: timeint16_capture_origin, timeint16_origin_ready
  real(8) :: timeint16_origin_nonstorage(1000)
  common /timeint16_origin_common/ timeint16_capture_origin, timeint16_origin_ready, timeint16_origin_nonstorage

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),theta_dot_prev(:),theta_dot_end(:),theta_tg(:),head_tg(:)
  real(real64),allocatable :: check_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:),theta_n(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,dt,horizon
  integer :: steps,step,total_nl,total_back,total_jac,total_lin
  real(real64) :: maxledger,cumledger,max_roundtrip,init_mass_rate

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,dt)

  horizon=0.04_real64
  steps=nint(horizon/dt)
  call require(abs(real(steps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(theta_dot_prev(numnod),theta_dot_end(numnod),theta_tg(numnod),head_tg(numnod),theta_n(numnod))
  allocate(check_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  theta_dot_prev=0.0_real64
  total_nl=0; total_back=0; total_jac=0; total_lin=0
  maxledger=0.0_real64; cumledger=0.0_real64; max_roundtrip=0.0_real64
  init_mass_rate=huge(1.0_real64)
  timeint16_capture_origin=0
  timeint16_origin_ready=0
  timeint16_origin_nonstorage=0.0d0

  ! Event-local startup: cover the first nominal interval with two BE half steps.
  call advance_one(1,0.5_real64*dt,.false.)
  call advance_one(2,0.5_real64*dt,.false.)

  ! Re-enter TG only after the discontinuous forcing event has been damped.
  do step=2,steps
    call advance_one(step+1,dt,.true.)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT16B_RESULT|MATERIAL=',trim(material_id),'|RAIN=',rain,'|DT=',dt, &
       '|STEPS=',steps,'|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|TOP_THETA=',state%water_content(1), &
       '|MID_THETA=',state%water_content((numnod+1)/2),'|BOTTOM_THETA=',state%water_content(numnod), &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|MAX_LEDGER=',maxledger, &
       '|CUM_LEDGER=',cumledger,'|MAX_ROUNDTRIP=',max_roundtrip,'|INIT_MASS_RATE=',init_mass_rate
  write(*,'(A)') 'F_PE_TIMEINT16B=PASS'

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
    p%parameter_set_id=26092916_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      cof(1,i)=tr
      cof(2,i)=ts
      cof(3,i)=ksat
      cof(4,i)=alpha
      cof(5,i)=lambda
      cof(6,i)=nvg
      cof(7,i)=mm
      cof(8,i)=alpha
      cof(9,i)=0.0_real64
      cof(10,i)=ksat
      cof(11,i)=0.999_real64
      cof(12,i)=0.99_real64*ksat
      cof(22,i)=-1.0e6_real64
      cof(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64
    qssdi=0.0_real64
    qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod)
    real(real64),allocatable::th(:),kk(:),cp(:),dk(:)
    allocate(th(numnod),kk(numnod),cp(numnod),dk(numnod))
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    heads=h
    call constitutive%evaluate(heads,th,kk,cp,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads
    s%water_content=th
    s%ponding_depth=0.0_real64
    s%groundwater_level=-999.0_real64
  end subroutine

  subroutine advance_one(step_index,step_dt,use_tg)
    integer,intent(in)::step_index
    real(real64),intent(in)::step_dt
    logical,intent(in)::use_tg
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::effective_baltol,storage0,storage1,ledger,rt
    integer::i

    theta_n=state%water_content

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    req=soil_water_solve_request_t()
    req%parameters=>p
    req%base_state=state
    req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-rain
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8
    req%numerical%max_backtracking=8
    req%numerical%conductivity_mean_method=1
    req%numerical%conductivity_implicit_mode=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/step_dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top

    ! Capture the governing non-storage operator at every accepted origin.
    ! This makes theta_dot_prev belong to the actual accepted TG state, not to
    ! the previous BE predictor.
    timeint16_origin_ready=0
    timeint16_capture_origin=1

    storage0=sum(theta_n*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves

    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT16B_FAILURE|STEP=',step_index,'|DT=',step_dt,'|STATUS=',res%status, &
           '|NL=',res%diagnostics%nonlinear_iterations,'|BACK=',res%diagnostics%backtracking_attempts
      call require(.false.,'BE-like endpoint solve failed')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite BE head')
    call require(all(ieee_is_finite(res%candidate_state%water_content)),'nonfinite BE theta')

    theta_dot_end=(res%candidate_state%water_content-theta_n)/step_dt

    if(use_tg)then
      call require(timeint16_origin_ready==1,'origin operator was not captured')
      do i=1,numnod
        theta_dot_prev(i)=-timeint16_origin_nonstorage(i)/p%dz(i)
      end do
      if(init_mass_rate>0.5_real64*huge(1.0_real64))then
        init_mass_rate=sum(theta_dot_prev*p%dz)
        call require(abs(init_mass_rate-rain)<=5.0e-8_real64,'initial governing derivative mass mismatch')
      end if

      theta_tg=theta_n+0.5_real64*step_dt*(theta_dot_prev+theta_dot_end)
      call require(all(theta_tg>tr),'TG theta at/below residual water content')
      call require(all(theta_tg<ts),'TG theta at/above saturation')

      do i=1,numnod
        head_tg(i)=inverse_default_mvg(i,theta_tg(i))
      end do
      call require(all(ieee_is_finite(head_tg)),'nonfinite inverse head')

      call constitutive%evaluate(head_tg,check_theta,tmp_k,tmp_cap,tmp_dk)
      rt=maxval(abs(check_theta-theta_tg))
      max_roundtrip=max(max_roundtrip,rt)
      call require(rt<=1.0e-12_real64,'theta-head roundtrip failed')

      state=res%candidate_state
      state%pressure_head=head_tg
      state%water_content=theta_tg
    else
      state=res%candidate_state
    end if

    storage1=sum(state%water_content*p%dz)+state%ponding_depth
    ledger=storage1-storage0-rain*step_dt
    call require(ieee_is_finite(ledger),'nonfinite ledger')
    maxledger=max(maxledger,abs(ledger))
    cumledger=cumledger+ledger

    ! The derivative history for the next interval is deliberately not taken
    ! from the BE predictor. It is re-evaluated from the accepted TG origin at
    ! the beginning of the next trial.
  end subroutine

  real(real64) function inverse_default_mvg(node,theta) result(head)
    integer,intent(in)::node
    real(real64),intent(in)::theta
    real(real64)::c1,c2,c4,c6,c7,c25,c26,c27,se,arg
    c1=hp%cofgen(1,node)
    c2=hp%cofgen(2,node)
    c4=hp%cofgen(4,node)
    c6=hp%cofgen(6,node)
    c7=hp%cofgen(7,node)
    c25=hp%cofgen(25,node)
    c26=hp%cofgen(26,node)
    c27=hp%cofgen(27,node)

    if(theta>=c26)then
      call require(c27>0.0_real64,'invalid near-saturation inverse slope')
      head=-1.0e-2_real64+(theta-c26)/c27
      head=min(head,0.0_real64)
    else
      se=(theta-c1)/c25
      call require(se>0.0_real64 .and. se<1.0_real64,'invalid effective saturation for inverse')
      arg=se**(-1.0_real64/c7)-1.0_real64
      call require(arg>=0.0_real64,'negative inverse retention argument')
      head=-(arg**(1.0_real64/c6))/c4
    end if
  end function

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT16B_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine

end program test_fpe_timeint16b_startup
