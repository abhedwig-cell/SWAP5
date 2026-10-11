program test_fpe_timeint14a_mass_identity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &
       bind_fpe_timeint13_predicted_k_provider
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
  type(b110_default_mvg_provider_t),target :: base_constitutive
  type(fpe_timeint13_predicted_k_provider_t),target :: predicted_constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),theta_prevprev(:),k_n(:),k_nm1(:),k_pred(:)
  real(real64),allocatable :: tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  character(len=32) :: material_id,regime_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain
  real(real64),parameter :: dt=0.005_real64,horizon=0.12_real64,pmax=0.05_real64,rsro=0.05_real64
  integer :: steps,step,total_nl,total_back,total_jac,total_lin,total_alt,clamp_count
  real(real64) :: cumrun,maxledger,storage_end
  character(len=48) :: final_route

  call get_command_argument(1,material_id)
  call get_command_argument(2,regime_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)

  steps=nint(horizon/dt)
  call setup()
  call initialize_state(h0,state)
  allocate(theta_prevprev(numnod),k_n(numnod),k_nm1(numnod),k_pred(numnod))
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  theta_prevprev=state%water_content
  call exact_k_from_state(state,k_n)
  k_nm1=k_n
  total_nl=0; total_back=0; total_jac=0; total_lin=0; total_alt=0
  clamp_count=0; cumrun=0.0_real64; maxledger=0.0_real64; final_route='none'
  timeint04b_floor_mode=1

  do step=1,steps
    call advance_one(step)
  end do

  storage_end=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_TIMEINT14A_RESULT|MATERIAL=',trim(material_id),'|REGIME=',trim(regime_id), &
       '|STEPS=',steps,'|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin,'|ALT=',total_alt, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|CLAMPS=',clamp_count, &
       '|RUNOFF=',cumrun,'|POND=',state%ponding_depth,'|STORAGE=',storage_end, &
       '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|MAX_LEDGER=',maxledger,'|ROUTE=',trim(final_route)
  write(*,'(A)') 'F_PE_TIMEINT14A=PASS'

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
    p%parameter_set_id=26092914_int64; p%active_nodes=numnod
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

  subroutine advance_one(step_index)
    integer,intent(in)::step_index
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::top_result
    real(real64),allocatable::theta_n(:),k_new(:)
    real(real64)::effective_baltol,storage0,storage1,ledger,soil_m1,soil_n,soil_np1,history_correction,identity_residual
    integer::nclamp

    allocate(theta_n(numnod),k_new(numnod))
    theta_n=state%water_content
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=theta_prevprev

    if(step_index>=2)then
      timeint02_mode=2
      timeint05_a0=1.5_real64; timeint05_a1=-2.0_real64; timeint05_a2=0.5_real64
      k_pred=2.0_real64*k_n-k_nm1
    else
      timeint02_mode=1
      timeint05_a0=1.0_real64; timeint05_a1=-1.0_real64; timeint05_a2=0.0_real64
      k_pred=k_n
    end if

    nclamp=count(k_pred<1.0e-12_real64)
    if(nclamp>0) clamp_count=clamp_count+1
    k_pred=max(k_pred,1.0e-12_real64)

    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_pred)
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,dt, &
         rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,k_pred(1))

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>predicted_constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    soil_m1=sum(theta_prevprev*p%dz)
    soil_n=sum(state%water_content*p%dz)
    storage0=soil_n+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_alt=total_alt+res%diagnostics%alternative_solver_calls

    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT13_DYNTOP_FAILURE|STEP=',step_index,'|STATUS=',res%status, &
           '|NL=',res%diagnostics%nonlinear_iterations,'|BACK=',res%diagnostics%backtracking_attempts, &
           '|CLAMPS=',clamp_count
      call require(.false.,'solver failed')
    end if
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite head')

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,top_result)
    call require(top_result%status>0,'final top unavailable')

    soil_np1=sum(res%candidate_state%water_content*p%dz)
    storage1=soil_np1+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*dt+top_result%runoff_depth-res%bottom_flux*dt
    call require(ieee_is_finite(ledger),'nonfinite ledger')
    if(step_index>=2)then
      history_correction=-0.5_real64*(soil_np1-2.0_real64*soil_n+soil_m1)
    else
      history_correction=0.0_real64
    end if
    identity_residual=ledger-history_correction
    write(*,'(*(g0))') 'F_PE_TIMEINT14A_STEP|MATERIAL=',trim(material_id),'|REGIME=',trim(regime_id), &
         '|STEP=',step_index,'|SOIL_M1=',soil_m1,'|SOIL_N=',soil_n,'|SOIL_NP1=',soil_np1, &
         '|POND_N=',state%ponding_depth,'|POND_NP1=',res%candidate_state%ponding_depth, &
         '|LEDGER=',ledger,'|HISTORY_CORRECTION=',history_correction,'|IDENTITY_RESIDUAL=',identity_residual, &
         '|RUNOFF=',top_result%runoff_depth,'|BOTTOM_FLUX=',res%bottom_flux,'|ROUTE=',trim(top_result%route)
    maxledger=max(maxledger,abs(ledger))
    cumrun=cumrun+top_result%runoff_depth
    final_route=top_result%route

    call exact_k_from_state(res%candidate_state,k_new)
    theta_prevprev=theta_n
    k_nm1=k_n
    k_n=k_new
    state=res%candidate_state
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEINT13_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine

end program test_fpe_timeint14a_mass_identity
