program test_fpe_timeint11_sdirk2
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
  type(soil_water_physical_state_t) :: initial_state,state,bdf_state
  real(real64),allocatable :: bdf_theta_nm1(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,dt,horizon
  real(real64), parameter :: gamma = 1.0_real64 - 1.0_real64/sqrt(2.0_real64)
  integer :: nsteps,step,total_sdirk_work,total_bdf_work,total_alt

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,dt)

  horizon=0.04_real64
  nsteps=nint(horizon/dt)
  call require(nsteps>0,'invalid step count')
  call require(abs(real(nsteps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,initial_state)
  state=initial_state
  bdf_state=initial_state
  allocate(bdf_theta_nm1(numnod))
  bdf_theta_nm1=initial_state%water_content
  timeint04b_floor_mode=1
  total_sdirk_work=0; total_bdf_work=0; total_alt=0

  do step=1,nsteps
    call advance_sdirk_with_label(step,state,dt)
  end do

  call run_bdf2_comparator()

  write(*,'(*(g0))') 'F_PE_TIMEINT11_END|MATERIAL=',trim(material_id),'|RAIN=',rain,'|DT=',dt, &
       '|NSTEPS=',nsteps,'|TOP_H=',state%pressure_head(1), &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|SDIRK_WORK=',total_sdirk_work,'|BDF_WORK=',total_bdf_work,'|ALT=',total_alt
  write(*,'(A)') 'F_PE_TIMEINT11=PASS'

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
    p%parameter_set_id=26092911_int64; p%active_nodes=numnod
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

  subroutine configure_time_mode(mode,step_dt,previous_dt,theta_hist)
    integer,intent(in)::mode
    real(real64),intent(in)::step_dt,previous_dt,theta_hist(:)
    real(real64)::r
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=theta_hist
    if(mode==2)then
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
  end subroutine

  subroutine solve_endpoint(s0,theta_hist,step_dt,previous_dt,mode,extra_residual,s1,work,alt,balance,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::theta_hist(:),step_dt,previous_dt,extra_residual(:)
    integer,intent(in)::mode
    type(soil_water_physical_state_t),intent(out)::s1
    integer,intent(out)::work,alt
    real(real64),intent(out)::balance
    logical,intent(out)::ok
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::effective_baltol
    integer::i

    call configure_time_mode(mode,step_dt,previous_dt,theta_hist)
    qdra=0.0_real64; qssdi=0.0_real64
    do i=1,numnod
      if(extra_residual(i)>=0.0_real64)then
        qdra(1,i)=extra_residual(i)
      else
        qssdi(i)=-extra_residual(i)
      end if
    end do

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
    work=res%diagnostics%nonlinear_iterations+res%diagnostics%backtracking_attempts+ &
         res%diagnostics%jacobian_builds+res%diagnostics%linear_solves
    alt=res%diagnostics%alternative_solver_calls
    balance=huge(1.0_real64)
    if(res%integrated_mass_balance_residual_available) balance=abs(res%integrated_mass_balance_residual_cm)
    ok=res%status==SW_SOLVE_CONVERGED
    if(ok)then
      ok=all(ieee_is_finite(res%candidate_state%pressure_head)) .and. &
         all(ieee_is_finite(res%candidate_state%water_content))
      if(ok)s1=res%candidate_state
    end if
    qdra=0.0_real64; qssdi=0.0_real64
  end subroutine

  subroutine sdirk_step(origin,physical_dt,final_state,stage1_state,e11,work,alt,maxbal,ok)
    type(soil_water_physical_state_t),intent(in)::origin
    real(real64),intent(in)::physical_dt
    type(soil_water_physical_state_t),intent(out)::final_state,stage1_state
    real(real64),intent(out)::e11,maxbal
    integer,intent(out)::work,alt
    logical,intent(out)::ok
    real(real64),allocatable::zero(:),extra(:),hemb(:)
    real(real64)::stage_dt,coef,b1,b2
    integer::w1,w2,a1,a2,i
    logical::ok1,ok2

    allocate(zero(numnod),extra(numnod),hemb(numnod))
    zero=0.0_real64
    stage_dt=gamma*physical_dt

    call solve_endpoint(origin,origin%water_content,stage_dt,stage_dt,1,zero,stage1_state,w1,a1,b1,ok1)
    if(.not.ok1)then
      ok=.false.; work=w1; alt=a1; maxbal=b1; e11=huge(1.0_real64); return
    end if

    coef=(1.0_real64-gamma)/gamma
    do i=1,numnod
      ! Stage-1 residual operator S(Y1) from its exact BE storage equation.
      extra(i)=-coef*p%dz(i)*(stage1_state%water_content(i)-origin%water_content(i))/stage_dt
    end do

    call solve_endpoint(origin,origin%water_content,stage_dt,stage_dt,1,extra,final_state,w2,a2,b2,ok2)
    work=w1+w2; alt=a1+a2; maxbal=max(b1,b2); ok=ok1.and.ok2
    if(.not.ok)then
      e11=huge(1.0_real64); return
    end if

    hemb=origin%pressure_head+(stage1_state%pressure_head-origin%pressure_head)/gamma
    e11=maxval(abs(final_state%pressure_head-hemb))
  end subroutine

  subroutine advance_sdirk_with_label(step_index,current,physical_dt)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t),intent(inout)::current
    real(real64),intent(in)::physical_dt
    type(soil_water_physical_state_t)::origin,full,s1,half1,hs1,half2,hs2
    real(real64)::e11,ehead,etheta,estorage,bf,bh1,bh2,ehalf
    integer::wf,af,w1,a1,w2,a2
    logical::okf,ok1,ok2

    origin=current
    call sdirk_step(origin,physical_dt,full,s1,e11,wf,af,bf,okf)
    call require(okf,'full SDIRK2 failed')
    total_sdirk_work=total_sdirk_work+wf
    total_alt=total_alt+af

    call sdirk_step(origin,0.5_real64*physical_dt,half1,hs1,ehalf,w1,a1,bh1,ok1)
    ok2=.false.; w2=0; a2=0; bh2=0.0_real64
    if(ok1) call sdirk_step(half1,0.5_real64*physical_dt,half2,hs2,ehalf,w2,a2,bh2,ok2)

    if(ok1.and.ok2)then
      ehead=maxval(abs(full%pressure_head-half2%pressure_head))
      etheta=maxval(abs(full%water_content-half2%water_content))
      estorage=abs((sum(full%water_content*p%dz)+full%ponding_depth)- &
                   (sum(half2%water_content*p%dz)+half2%ponding_depth))
      write(*,'(*(g0))') 'F_PE_TIMEINT11_POINT|MATERIAL=',trim(material_id),'|RAIN=',rain, &
           '|STEP=',step_index,'|DT=',physical_dt,'|E11=',e11,'|EHEAD=',ehead, &
           '|ETHETA=',etheta,'|ESTORAGE=',estorage,'|FULL_WORK=',wf,'|HALF_WORK=',w1+w2, &
           '|ALT=',af,'|MAX_BAL=',bf
    else
      write(*,'(*(g0))') 'F_PE_TIMEINT11_LABEL_UNAVAILABLE|MATERIAL=',trim(material_id),'|RAIN=',rain, &
           '|STEP=',step_index,'|DT=',physical_dt,'|HALF1_OK=',merge(1,0,ok1),'|HALF2_OK=',merge(1,0,ok2)
    end if
    current=full
  end subroutine

  subroutine run_bdf2_comparator()
    type(soil_water_physical_state_t)::origin,next
    real(real64),allocatable::zero(:),theta_hist(:)
    real(real64)::bal
    integer::i,w,a
    logical::ok
    allocate(zero(numnod),theta_hist(numnod)); zero=0.0_real64
    bdf_state=initial_state
    theta_hist=initial_state%water_content
    total_bdf_work=0

    do i=1,nsteps
      origin=bdf_state
      if(i==1)then
        call solve_endpoint(origin,theta_hist,dt,dt,1,zero,next,w,a,bal,ok)
      else
        call solve_endpoint(origin,theta_hist,dt,dt,2,zero,next,w,a,bal,ok)
      end if
      call require(ok,'paired BDF2 comparator failed')
      total_bdf_work=total_bdf_work+w
      total_alt=total_alt+a
      theta_hist=origin%water_content
      bdf_state=next
    end do
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT11_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint11_sdirk2
