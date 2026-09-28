program test_fpe_timeint07_third_difference
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

  integer :: timeint04b_floor_mode
  common /timeint04b_floor_common/ timeint04b_floor_mode

  real(8) :: timeint05_a0, timeint05_a1, timeint05_a2
  common /timeint05_coeff_common/ timeint05_a0, timeint05_a1, timeint05_a2

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),water(:),kk(:),cap(:),dk(:)
  real(real64),allocatable :: theta_nm1(:),h_nm1(:),h_nm2(:)
  type(soil_water_physical_state_t) :: state

  character(len=32) :: material_id,pattern
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,base_dt,horizon
  real(real64) :: factor1,factor2,prev_dt,prevprev_dt,current_dt
  integer :: step,nsteps,total_points

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,base_dt)
  call get_command_argument(10,pattern)

  select case(trim(pattern))
  case('R1')
    factor1=1.0_real64; factor2=1.0_real64
  case('R1P5')
    factor1=0.8_real64; factor2=1.2_real64
  case('R2')
    factor1=2.0_real64/3.0_real64; factor2=4.0_real64/3.0_real64
  case default
    error stop 'invalid pattern'
  end select

  horizon=0.04_real64
  nsteps=nint(horizon/base_dt)
  call require(mod(nsteps,2)==0,'pair pattern requires even step count')
  call require(abs(real(nsteps,real64)*base_dt-horizon)<=1.0e-12_real64,'base dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(theta_nm1(numnod),h_nm1(numnod),h_nm2(numnod))
  theta_nm1=state%water_content
  h_nm1=state%pressure_head
  h_nm2=state%pressure_head
  timeint04b_floor_mode=1
  total_points=0
  prev_dt=base_dt*factor1
  prevprev_dt=prev_dt

  do step=1,nsteps
    if(mod(step,2)==1)then
      current_dt=base_dt*factor1
    else
      current_dt=base_dt*factor2
    end if
    call advance_outer(step,current_dt,prev_dt,prevprev_dt)
    prevprev_dt=prev_dt
    prev_dt=current_dt
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT07_END|MATERIAL=',trim(material_id),'|RAIN=',rain, &
       '|BASE_DT=',base_dt,'|PATTERN=',trim(pattern),'|POINTS=',total_points, &
       '|TOP_H=',state%pressure_head(1),'|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(A)') 'F_PE_TIMEINT07=PASS'

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
    p%parameter_set_id=26092861_int64; p%active_nodes=numnod
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
    call bind_b110_default_mvg_provider(constitutive,hp,base_dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine solve_bdf2(s0,theta_hist,step_dt,previous_dt,use_bdf2,s1,nl,back,jac,lin,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::theta_hist(:),step_dt,previous_dt
    logical,intent(in)::use_bdf2
    type(soil_water_physical_state_t),intent(out)::s1
    integer,intent(out)::nl,back,jac,lin
    logical,intent(out)::ok
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::r,effective_baltol

    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=theta_hist
    if(use_bdf2)then
      timeint02_mode=2
      r=step_dt/previous_dt
      timeint05_a0=(1.0_real64+2.0_real64*r)/(1.0_real64+r)
      timeint05_a1=-(1.0_real64+r)
      timeint05_a2=r*r/(1.0_real64+r)
    else
      timeint02_mode=1
      timeint05_a0=1.0_real64
      timeint05_a1=-1.0_real64
      timeint05_a2=0.0_real64
    end if

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    req=soil_water_solve_request_t()
    req%parameters=>p
    req%base_state=s0
    req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-rain
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=1
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
    req%evaluation%top_boundary=>top

    call solver%solve(req,ws,res)
    nl=res%diagnostics%nonlinear_iterations
    back=res%diagnostics%backtracking_attempts
    jac=res%diagnostics%jacobian_builds
    lin=res%diagnostics%linear_solves
    ok=res%status==SW_SOLVE_CONVERGED
    if(ok)then
      ok=all(ieee_is_finite(res%candidate_state%pressure_head)) .and. &
         all(ieee_is_finite(res%candidate_state%water_content))
      if(ok)s1=res%candidate_state
    end if
  end subroutine

  subroutine advance_outer(step_index,step_dt,previous_dt,previous_previous_dt)
    integer,intent(in)::step_index
    real(real64),intent(in)::step_dt,previous_dt,previous_previous_dt
    type(soil_water_physical_state_t)::origin,full,half1,half2
    real(real64),allocatable :: old_theta(:),old_h(:)
    real(real64),allocatable :: d01(:),d12(:),d23(:),d012(:),d123(:),d3(:)
    real(real64)::e3,ehead,etheta,estorage,half_dt,r,a0
    integer::nl_f,b_f,j_f,l_f,nl_1,b_1,j_1,l_1,nl_2,b_2,j_2,l_2
    logical::ok_f,ok_1,ok_2

    origin=state
    allocate(old_theta(numnod),old_h(numnod))
    old_theta=origin%water_content
    old_h=origin%pressure_head

    if(step_index==1)then
      call solve_bdf2(origin,theta_nm1,step_dt,previous_dt,.false.,full,nl_f,b_f,j_f,l_f,ok_f)
      call require(ok_f,'bootstrap BE failed')
      h_nm2=h_nm1
      h_nm1=old_h
      theta_nm1=old_theta
      state=full
      return
    end if

    call solve_bdf2(origin,theta_nm1,step_dt,previous_dt,.true.,full,nl_f,b_f,j_f,l_f,ok_f)
    call require(ok_f,'full BDF2 failed')

    if(step_index==2)then
      h_nm2=h_nm1
      h_nm1=old_h
      theta_nm1=old_theta
      state=full
      return
    end if

    half_dt=0.5_real64*step_dt
    call solve_bdf2(origin,theta_nm1,half_dt,previous_dt,.true.,half1,nl_1,b_1,j_1,l_1,ok_1)
    ok_2=.false.; nl_2=0; b_2=0; j_2=0; l_2=0
    if(ok_1) call solve_bdf2(half1,old_theta,half_dt,half_dt,.true.,half2,nl_2,b_2,j_2,l_2,ok_2)

    allocate(d01(numnod),d12(numnod),d23(numnod),d012(numnod),d123(numnod),d3(numnod))
    d01=(full%pressure_head-old_h)/step_dt
    d12=(old_h-h_nm1)/previous_dt
    d23=(h_nm1-h_nm2)/previous_previous_dt
    d012=(d01-d12)/(step_dt+previous_dt)
    d123=(d12-d23)/(previous_dt+previous_previous_dt)
    d3=(d012-d123)/(step_dt+previous_dt+previous_previous_dt)

    r=step_dt/previous_dt
    a0=(1.0_real64+2.0_real64*r)/(1.0_real64+r)
    e3=step_dt*step_dt*(step_dt+previous_dt)/a0*maxval(abs(d3))

    if(ok_1 .and. ok_2)then
      ehead=maxval(abs(full%pressure_head-half2%pressure_head))
      etheta=maxval(abs(full%water_content-half2%water_content))
      estorage=abs((sum(full%water_content*p%dz)+full%ponding_depth)- &
                   (sum(half2%water_content*p%dz)+half2%ponding_depth))
      total_points=total_points+1
      write(*,'(*(g0))') 'F_PE_TIMEINT07_POINT|MATERIAL=',trim(material_id),'|RAIN=',rain, &
        '|PATTERN=',trim(pattern),'|STEP=',step_index,'|DT=',step_dt,'|PREV_DT=',previous_dt, &
        '|PREVPREV_DT=',previous_previous_dt,'|RATIO=',r,'|E3=',e3, &
        '|EHEAD=',ehead,'|ETHETA=',etheta,'|ESTORAGE=',estorage, &
        '|FULL_WORK=',nl_f+b_f+j_f+l_f,'|HALF_WORK=',nl_1+b_1+j_1+l_1+nl_2+b_2+j_2+l_2
    else
      write(*,'(*(g0))') 'F_PE_TIMEINT07_LABEL_UNAVAILABLE|MATERIAL=',trim(material_id),'|RAIN=',rain, &
        '|PATTERN=',trim(pattern),'|STEP=',step_index,'|DT=',step_dt,'|PREV_DT=',previous_dt, &
        '|PREVPREV_DT=',previous_previous_dt,'|RATIO=',r,'|E3=',e3,'|HALF1_OK=',merge(1,0,ok_1), &
        '|HALF2_OK=',merge(1,0,ok_2)
    end if

    h_nm2=h_nm1
    h_nm1=old_h
    theta_nm1=old_theta
    state=full
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT07_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint07_third_difference
