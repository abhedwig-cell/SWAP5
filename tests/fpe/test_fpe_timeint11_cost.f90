program test_fpe_timeint11_cost
  use, intrinsic :: iso_fortran_env, only: int64, real64
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
  type(soil_water_physical_state_t) :: initial,bdf_state,comp_state,stage1,stage2,bdf_next

  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,outer_dt,horizon,gamma,h1,h2
  real(real64),allocatable :: bdf_theta_nm1(:),old_theta(:)
  integer :: nsteps,step
  integer :: bdf_nl,bdf_back,bdf_jac,bdf_lin
  integer :: cmp_nl,cmp_back,cmp_jac,cmp_lin
  integer :: nl,back,jac,lin
  logical :: ok

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,outer_dt)

  horizon=0.04_real64
  gamma=2.0_real64-sqrt(2.0_real64)
  h1=gamma*outer_dt
  h2=(1.0_real64-gamma)*outer_dt
  nsteps=nint(horizon/outer_dt)
  call require(abs(real(nsteps,real64)*outer_dt-horizon)<=1.0e-12_real64,'outer dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,initial)
  bdf_state=initial
  comp_state=initial
  allocate(bdf_theta_nm1(numnod),old_theta(numnod))
  bdf_theta_nm1=initial%water_content
  timeint04b_floor_mode=1

  bdf_nl=0; bdf_back=0; bdf_jac=0; bdf_lin=0
  cmp_nl=0; cmp_back=0; cmp_jac=0; cmp_lin=0

  do step=1,nsteps
    old_theta=bdf_state%water_content
    if(step==1)then
      call solve_step(bdf_state,bdf_theta_nm1,outer_dt,outer_dt,.false.,bdf_next,nl,back,jac,lin,ok)
    else
      call solve_step(bdf_state,bdf_theta_nm1,outer_dt,outer_dt,.true.,bdf_next,nl,back,jac,lin,ok)
    end if
    call require(ok,'single BDF2 path failed')
    bdf_nl=bdf_nl+nl; bdf_back=bdf_back+back; bdf_jac=bdf_jac+jac; bdf_lin=bdf_lin+lin
    bdf_theta_nm1=old_theta
    bdf_state=bdf_next

    old_theta=comp_state%water_content
    call solve_step(comp_state,old_theta,h1,h1,.false.,stage1,nl,back,jac,lin,ok)
    call require(ok,'composite stage1 failed')
    cmp_nl=cmp_nl+nl; cmp_back=cmp_back+back; cmp_jac=cmp_jac+jac; cmp_lin=cmp_lin+lin

    call solve_step(stage1,old_theta,h2,h1,.true.,stage2,nl,back,jac,lin,ok)
    call require(ok,'composite stage2 failed')
    cmp_nl=cmp_nl+nl; cmp_back=cmp_back+back; cmp_jac=cmp_jac+jac; cmp_lin=cmp_lin+lin
    comp_state=stage2
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT11_RESULT|MATERIAL=',trim(material_id),'|RAIN=',rain,'|DT=',outer_dt, &
       '|NSTEPS=',nsteps,'|BDF_NL=',bdf_nl,'|BDF_BACK=',bdf_back,'|BDF_JAC=',bdf_jac,'|BDF_LIN=',bdf_lin, &
       '|CMP_NL=',cmp_nl,'|CMP_BACK=',cmp_back,'|CMP_JAC=',cmp_jac,'|CMP_LIN=',cmp_lin, &
       '|BDF_WORK=',bdf_nl+bdf_back+bdf_jac+bdf_lin,'|CMP_WORK=',cmp_nl+cmp_back+cmp_jac+cmp_lin, &
       '|BDF_TOP_H=',bdf_state%pressure_head(1),'|CMP_TOP_H=',comp_state%pressure_head(1)
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
    call bind_b110_default_mvg_provider(constitutive,hp,outer_dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine solve_step(s0,theta_hist,step_dt,previous_dt,use_bdf2,s1,nl,back,jac,lin,ok)
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
      timeint05_a0=1.0_real64; timeint05_a1=-1.0_real64; timeint05_a2=0.0_real64
    end if

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=s0; req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%top_flux=-rain
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=1; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/step_dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive; req%evaluation%source_sink=>source_sink; req%evaluation%top_boundary=>top

    call solver%solve(req,ws,res)
    nl=res%diagnostics%nonlinear_iterations; back=res%diagnostics%backtracking_attempts
    jac=res%diagnostics%jacobian_builds; lin=res%diagnostics%linear_solves
    ok=res%status==SW_SOLVE_CONVERGED
    if(ok)s1=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT11_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint11_cost
