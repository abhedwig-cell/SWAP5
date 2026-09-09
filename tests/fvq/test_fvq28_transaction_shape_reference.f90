program test_fvq28_transaction_shape_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: nonlinear_head_tol = 1.0e-12_real64
  integer, parameter :: nh = 6, nj = 4, na = 3
  real(real64), parameter :: initial_heads(nh) = [ &
       -40.0_real64, -55.0_real64, -110.0_real64, -160.0_real64, -210.0_real64, -320.0_real64 ]
  real(real64), parameter :: head_jumps(nj) = [ -0.05_real64, -0.01_real64, 0.01_real64, 0.05_real64 ]
  real(real64), parameter :: attempt_dt(na) = [0.25_real64,0.125_real64,0.0625_real64]
  integer, parameter :: nref = 512

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  integer :: ih, ij, ia, case_id

  call configure_shared(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       drainage, subsurface, root_sink, cofgen)
  case_id = 0
  do ih = 1, nh
    do ij = 1, nj
      case_id = case_id + 1
      do ia = 1, na
        call characterize_attempt(case_id, ih, ij, ia, initial_heads(ih), head_jumps(ij), attempt_dt(ia), &
             parameters, hydraulic_parameters, constitutive, source_sink, top_provider, solver, workspace)
      end do
    end do
  end do
  call require(case_id == 24, 'frozen held-out case count')
  write(*,'(A,I0,A,I0)') 'FVQ28B_REFERENCE_DRIVER PASS CASES=', case_id, ':ATTEMPTS_PER_CASE=', na

contains

  subroutine configure_shared(p, hp, cp, sp, tp, qdra, qssdi, qrot, c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    integer :: k
    p%parameter_set_id = 282829_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z; p%dz = dz; p%node_distance = disnod(1:numnod)
    allocate(c(24,numnod)); c = 0.0_real64
    do k = 1, numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp, c)
    call bind_b110_default_mvg_provider(cp, hp, attempt_dt(1))
    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp, qdra, qssdi, qrot)
    if (.not. same_type_as(tp,tp)) error stop 'unreachable top provider type'
  end subroutine configure_shared

  subroutine characterize_attempt(cid, state_id, jump_id, attempt_id, h0, jump, horizon, p, hp, cp, sp, tp, s, ws)
    integer, intent(in) :: cid, state_id, jump_id, attempt_id
    real(real64), intent(in) :: h0, jump, horizon
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t) :: initial, full_ep, half_ep, ref_ep
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: k0, hbot, mass1, mass2, massref, sol1, sol2, solref, dhead, e2h
    integer :: nit1, nit2, nitref, nb1, nb2, nbref, k
    integer :: failstep1, failstep2, failstepref, status1, status2, statusref
    logical :: ok1, ok2, okref

    call bind_b110_default_mvg_provider(cp, hp, horizon)
    heads = h0
    call cp%evaluate(heads, water, conductivity, capacity, dkdh)
    do k=2,numnod
      call require(transfer(conductivity(k),0_int64)==transfer(conductivity(1),0_int64),'uniform initial conductivity')
    end do
    k0=conductivity(1); hbot=h0+jump
    initial%active_nodes=numnod
    allocate(initial%pressure_head(numnod), initial%water_content(numnod))
    initial%pressure_head=heads; initial%water_content=water
    initial%ponding_depth=0.0_real64; initial%groundwater_level=-2.0_real64

    call run_trajectory(1,horizon,h0,hbot,k0,p,hp,cp,sp,tp,s,ws,initial,full_ep,mass1,sol1,nit1,nb1,ok1,failstep1,status1)
    call run_trajectory(2,horizon,h0,hbot,k0,p,hp,cp,sp,tp,s,ws,initial,half_ep,mass2,sol2,nit2,nb2,ok2,failstep2,status2)
    call run_trajectory(nref,horizon,h0,hbot,k0,p,hp,cp,sp,tp,s,ws,initial,ref_ep,massref,solref,nitref,nbref,okref,failstepref,statusref)

    if (ok1 .and. ok2) then
      dhead=maxval(abs(full_ep%pressure_head-half_ep%pressure_head))
    else
      dhead=-1.0_real64
    end if
    if (ok2 .and. okref) then
      e2h=maxval(abs(half_ep%pressure_head-ref_ep%pressure_head))
    else
      e2h=-1.0_real64
    end if

    if (ok1 .and. ok2 .and. okref) then
      write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0)') &
           'FVQ28B_REF_OK:CASE=',cid,':STATE=',state_id,':JUMP_ID=',jump_id,':ATTEMPT=',attempt_id, &
           ':DT=',horizon,':DHEAD=',dhead,':E2=',e2h,':MAX_MASS=',max(mass1,mass2,massref), &
           ':MAX_SOLVER_RES=',max(sol1,sol2,solref),':H0=',h0,':MAX_NITER=',max(nit1,nit2,nitref), &
           ':MAX_NBACK=',max(nb1,nb2,nbref)
    else
      write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,L1,A,L1,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,ES26.17E3)') &
           'FVQ28B_REF_UNAVAILABLE:CASE=',cid,':STATE=',state_id,':JUMP_ID=',jump_id,':ATTEMPT=',attempt_id, &
           ':DT=',horizon,':DHEAD=',dhead,':FULL_OK=',ok1,':HALF_OK=',ok2,':REF_OK=',okref, &
           ':FULL_FAIL_STEP=',failstep1,':FULL_STATUS=',status1,':HALF_FAIL_STEP=',failstep2,':HALF_STATUS=',status2, &
           ':REF_FAIL_STEP=',failstepref,':REF_STATUS=',statusref,':MAX_MASS=',max(mass1,mass2,massref)
    end if
  end subroutine characterize_attempt

  subroutine run_trajectory(ns,horizon,h0,hbot,k0,p,hp,cp,sp,tp,s,ws,initial,endpoint,max_mass,max_solver,max_niter,max_nback,ok,fail_step,fail_status)
    integer, intent(in) :: ns
    real(real64), intent(in) :: horizon,h0,hbot,k0
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t), intent(in) :: initial
    type(soil_water_physical_state_t), intent(out) :: endpoint
    real(real64), intent(out) :: max_mass,max_solver
    integer, intent(out) :: max_niter,max_nback,fail_step,fail_status
    logical, intent(out) :: ok
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: subdt,storage0,storage1,total_in,total_out,residual
    integer :: istep

    subdt=horizon/real(ns,real64)
    state=initial; endpoint=initial
    max_mass=0.0_real64; max_solver=0.0_real64; max_niter=0; max_nback=0
    ok=.false.; fail_step=0; fail_status=0
    if (subdt < 1.0e-6_real64) then
      fail_status=-100
      return
    end if

    do istep=1,ns
      call bind_b110_default_mvg_provider(cp,hp,subdt)
      request=soil_water_solve_request_t()
      request%parameters=>p; request%base_state=state; request%step_duration=subdt
      request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; request%boundary%bottom_mode=5
      request%boundary%top_flux=-k0; request%boundary%top_head=h0
      request%boundary%bottom_flux=12345.678_real64; request%boundary%bottom_head=hbot
      request%physical%macropore_active=.false.
      request%numerical%max_iterations=8; request%numerical%max_backtracking=4
      request%numerical%conductivity_implicit_mode=0; request%numerical%conductivity_mean_method=1
      request%numerical%min_step_duration=1.0e-6_real64
      request%numerical%compartment_balance_tolerance=hard_mass_gate
      request%numerical%total_balance_tolerance=hard_mass_gate
      request%numerical%head_abs_tolerance=nonlinear_head_tol
      request%numerical%head_rel_tolerance=nonlinear_head_tol
      request%numerical%ponding_tolerance=nonlinear_head_tol
      request%evaluation%constitutive=>cp; request%evaluation%source_sink=>sp; request%evaluation%top_boundary=>tp
      storage0=sum(state%water_content*p%dz)+state%ponding_depth
      call s%solve(request,ws,result)
      max_niter=max(max_niter,result%diagnostics%nonlinear_iterations)
      max_nback=max(max_nback,result%diagnostics%backtracking_attempts)
      max_solver=max(max_solver,abs(result%unrounded_mass_balance_residual))
      if (result%status /= SW_SOLVE_CONVERGED) then
        fail_step=istep
        fail_status=result%status
        endpoint=state
        return
      end if
      storage1=sum(result%candidate_state%water_content*p%dz)+result%candidate_state%ponding_depth
      total_in=max(0.0_real64,-result%top_flux)*subdt+max(0.0_real64,result%bottom_flux)*subdt
      total_out=max(0.0_real64,result%top_flux)*subdt+max(0.0_real64,-result%bottom_flux)*subdt
      residual=storage1-storage0-(total_in-total_out)
      max_mass=max(max_mass,abs(residual))
      if (abs(residual)>hard_mass_gate) then
        fail_step=istep
        fail_status=-200
        endpoint=state
        return
      end if
      state=result%candidate_state
    end do
    endpoint=state
    ok=.true.
  end subroutine run_trajectory

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FVQ28B_REFERENCE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq28_transaction_shape_reference
