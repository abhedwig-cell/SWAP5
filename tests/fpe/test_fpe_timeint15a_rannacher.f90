program test_fpe_timeint15a_rannacher
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
  integer :: timeint15_origin_ready
  real(8) :: timeint15_origin_flux(1000)
  common /timeint15_trapezoid_common/ timeint15_mode, timeint15_origin_ready, timeint15_origin_flux

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
  real(real64),allocatable :: cof(:,:),tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  real(real64),allocatable :: k_n(:),k_nm1(:),k_pred(:),k_new(:)
  character(len=32) :: material_id,arm
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,dt,horizon
  integer :: steps,step,total_nl,total_back,total_jac,total_lin,clamp_count
  real(real64) :: maxledger,cumledger

  call get_command_argument(1,material_id)
  call get_command_argument(2,arm)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,rain); call read_real(10,dt)

  horizon=0.04_real64
  steps=nint(horizon/dt)
  call require(abs(real(steps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')
  call require(trim(arm)=='RANNACHER_KIMPL','invalid arm')

  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(k_n(numnod),k_nm1(numnod),k_pred(numnod),k_new(numnod))
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  call exact_k_from_state(state,k_n)
  k_nm1=k_n

  timeint15_mode=0
  timeint15_origin_ready=0
  timeint15_origin_flux=0.0d0
  total_nl=0; total_back=0; total_jac=0; total_lin=0
  clamp_count=0; maxledger=0.0_real64; cumledger=0.0_real64

  ! Rannacher startup: cover the first nominal interval with two BE half steps.
  call advance_one(1,0.5_real64*dt,.false.)
  call advance_one(2,0.5_real64*dt,.false.)

  ! Thereafter use the unchanged trapezoidal formulation at the nominal dt.
  do step=2,steps
    call advance_one(step+1,dt,.true.)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT15A_RESULT|MATERIAL=',trim(material_id),'|ARM=',trim(arm), &
       '|RAIN=',rain,'|DT=',dt,'|STEPS=',steps,'|TOP_H=',state%pressure_head(1), &
       '|MID_H=',state%pressure_head((numnod+1)/2),'|BOTTOM_H=',state%pressure_head(numnod), &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|CLAMPS=',clamp_count, &
       '|MAX_LEDGER=',maxledger,'|CUM_LEDGER=',cumledger
  write(*,'(A)') 'F_PE_TIMEINT15A=PASS'

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
    p%parameter_set_id=26092915_int64; p%active_nodes=numnod
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

  subroutine advance_one(step_index,step_dt,use_trapezoid)
    integer,intent(in)::step_index
    real(real64),intent(in)::step_dt
    logical,intent(in)::use_trapezoid
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::effective_baltol,storage0,storage1,ledger

    if(use_trapezoid)then
      timeint15_mode=1
    else
      timeint15_mode=0
    end if

    call bind_b110_default_mvg_provider(base_constitutive,hp,step_dt)

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
    req%evaluation%constitutive=>base_constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves

    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT15A_FAILURE|STEP=',step_index,'|DT=',step_dt, &
           '|TR=',merge(1,0,use_trapezoid),'|STATUS=',res%status, &
           '|NL=',res%diagnostics%nonlinear_iterations,'|BACK=',res%diagnostics%backtracking_attempts
      call require(.false.,'solver failed')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite candidate head')
    call require(all(ieee_is_finite(res%candidate_state%water_content)),'nonfinite candidate theta')

    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*step_dt
    call require(ieee_is_finite(ledger),'nonfinite ledger')
    maxledger=max(maxledger,abs(ledger))
    cumledger=cumledger+ledger
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT15_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine

end program test_fpe_timeint15a_rannacher
