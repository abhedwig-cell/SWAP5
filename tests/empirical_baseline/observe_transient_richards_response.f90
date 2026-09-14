program observe_transient_richards_response
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

  real(real64), parameter :: total_dt = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: nonlinear_head_tol = 1.0e-12_real64
  real(real64), parameter :: h0 = -110.0_real64
  real(real64), parameter :: head_jump = 0.05_real64
  integer, parameter :: nsteps = 4

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial, endpoint_a, endpoint_b
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: k0, storage0
  real(real64) :: in_a, out_a, residual_a, max_step_mass_a, max_solver_a
  real(real64) :: in_b, out_b, residual_b, max_step_mass_b, max_solver_b
  integer :: max_niter_a, max_nback_a, max_niter_b, max_nback_b
  integer(int64) :: fingerprint_a, fingerprint_b

  call configure_shared(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       drainage, subsurface, root_sink, cofgen, initial, k0, storage0)

  call run_trajectory(nsteps, parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       solver, workspace, initial, k0, endpoint_a, in_a, out_a, residual_a, max_step_mass_a, max_solver_a, &
       max_niter_a, max_nback_a)
  fingerprint_a = state_fingerprint(endpoint_a)

  call run_trajectory(nsteps, parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       solver, workspace, initial, k0, endpoint_b, in_b, out_b, residual_b, max_step_mass_b, max_solver_b, &
       max_niter_b, max_nback_b)
  fingerprint_b = state_fingerprint(endpoint_b)

  call require(fingerprint_a == fingerprint_b, 'same-input trajectory replay fingerprint')
  call require(same_real(in_a,in_b) .and. same_real(out_a,out_b) .and. same_real(residual_a,residual_b), &
       'same-input trajectory replay ledger')
  call require(abs(final_storage(endpoint_a,parameters)-storage0) > 1.0e-12_real64, &
       'transient trajectory has nonzero storage response')
  call require(abs(residual_a) <= hard_mass_gate, 'full trajectory mass closure')
  call require(max_step_mass_a <= hard_mass_gate, 'every accepted step mass closure')
  call require(max_niter_a >= 1, 'nonlinear solver executed')

  write(*,'(A)') 'case_id,nsteps,total_dt,h0,hbot,storage_start,storage_end,storage_change,total_in,total_out,residual,max_step_mass,max_solver_res,max_niter,max_nback,max_abs_head_change,endpoint_fingerprint'
  write(*,'(A,",",I0,",",4(ES25.17E3,","),9(ES25.17E3,","),I0,",",I0,",",ES25.17E3,",",I0)') &
       'fvq28_h0_m110_jump_p0p05', nsteps, total_dt, h0, h0+head_jump, storage0, &
       final_storage(endpoint_a,parameters), final_storage(endpoint_a,parameters)-storage0, &
       in_a, out_a, residual_a, max_step_mass_a, max_solver_a, max_niter_a, max_nback_a, &
       maxval(abs(endpoint_a%pressure_head-initial%pressure_head)), fingerprint_a
  write(*,'(A)') 'EB_R05_TRANSIENT_STORAGE_RESPONSE_NONZERO=PASS'
  write(*,'(A)') 'EB_R05_TRAJECTORY_MASS_CLOSURE=PASS'
  write(*,'(A)') 'EB_R05_SAME_INPUT_REPLAY_IDENTITY=PASS'
  write(*,'(A)') 'EB_R05_CURRENT_CANONICAL_TRANSIENT_RICHARDS_OBSERVATION PASS'

contains

  subroutine configure_shared(p, hp, cp, sp, tp, qdra, qssdi, qrot, c, initial_state, k_initial, storage_initial)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    type(soil_water_physical_state_t), intent(out) :: initial_state
    real(real64), intent(out) :: k_initial, storage_initial
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 205001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp, c)
    call bind_b110_default_mvg_provider(cp, hp, total_dt)

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp, qdra, qssdi, qrot)
    if (.not. same_type_as(tp,tp)) error stop 'unreachable top provider type'

    heads = h0
    call cp%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
           'uniform initial conductivity')
    end do
    k_initial = conductivity(1)

    initial_state%active_nodes = numnod
    allocate(initial_state%pressure_head(numnod), initial_state%water_content(numnod))
    initial_state%pressure_head = heads
    initial_state%water_content = water
    initial_state%ponding_depth = 0.0_real64
    initial_state%groundwater_level = -2.0_real64
    storage_initial = final_storage(initial_state,p)
  end subroutine configure_shared

  subroutine run_trajectory(ns, p, hp, cp, sp, tp, s, ws, initial_state, k_initial, endpoint, &
       total_in, total_out, residual, max_step_mass, max_solver, max_niter, max_nback)
    integer, intent(in) :: ns
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t), intent(in) :: initial_state
    real(real64), intent(in) :: k_initial
    type(soil_water_physical_state_t), intent(out) :: endpoint
    real(real64), intent(out) :: total_in, total_out, residual, max_step_mass, max_solver
    integer, intent(out) :: max_niter, max_nback
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: subdt, storage_start, storage_end, step_in, step_out, step_residual
    integer :: istep

    subdt = total_dt/real(ns,real64)
    call require(subdt >= 1.0e-6_real64, 'trajectory above exact F-GC02 dtmin')
    state = initial_state
    total_in = 0.0_real64
    total_out = 0.0_real64
    max_step_mass = 0.0_real64
    max_solver = 0.0_real64
    max_niter = 0
    max_nback = 0

    do istep = 1, ns
      call bind_b110_default_mvg_provider(cp, hp, subdt)
      request = soil_water_solve_request_t()
      request%parameters => p
      request%base_state = state
      request%step_duration = subdt
      request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%bottom_mode = 5
      request%boundary%top_flux = -k_initial
      request%boundary%top_head = h0
      request%boundary%bottom_flux = 12345.678_real64
      request%boundary%bottom_head = h0 + head_jump
      request%physical%macropore_active = .false.
      request%numerical%max_iterations = 8
      request%numerical%max_backtracking = 4
      request%numerical%conductivity_implicit_mode = 0
      request%numerical%conductivity_mean_method = 1
      request%numerical%min_step_duration = 1.0e-6_real64
      request%numerical%compartment_balance_tolerance = hard_mass_gate
      request%numerical%total_balance_tolerance = hard_mass_gate
      request%numerical%head_abs_tolerance = nonlinear_head_tol
      request%numerical%head_rel_tolerance = nonlinear_head_tol
      request%numerical%ponding_tolerance = nonlinear_head_tol
      request%evaluation%constitutive => cp
      request%evaluation%source_sink => sp
      request%evaluation%top_boundary => tp

      storage_start = final_storage(state,p)
      call s%solve(request, ws, result)
      call require(result%status == SW_SOLVE_CONVERGED, 'direct Richards solve converged')
      storage_end = final_storage(result%candidate_state,p)
      step_in = max(0.0_real64,-result%top_flux)*subdt + max(0.0_real64,result%bottom_flux)*subdt
      step_out = max(0.0_real64,result%top_flux)*subdt + max(0.0_real64,-result%bottom_flux)*subdt
      step_residual = storage_end-storage_start-(step_in-step_out)
      call require(abs(step_residual) <= hard_mass_gate, 'hard step mass gate')
      total_in = total_in + step_in
      total_out = total_out + step_out
      max_step_mass = max(max_step_mass,abs(step_residual))
      max_solver = max(max_solver,abs(result%unrounded_mass_balance_residual))
      max_niter = max(max_niter,result%diagnostics%nonlinear_iterations)
      max_nback = max(max_nback,result%diagnostics%backtracking_attempts)
      state = result%candidate_state
    end do

    endpoint = state
    residual = final_storage(endpoint,p)-final_storage(initial_state,p)-(total_in-total_out)
  end subroutine run_trajectory

  real(real64) function final_storage(state,p) result(storage)
    type(soil_water_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), intent(in) :: p
    storage = sum(state%water_content*p%dz) + state%ponding_depth
  end function final_storage

  integer(int64) function state_fingerprint(state) result(fp)
    type(soil_water_physical_state_t), intent(in) :: state
    integer(int64) :: word
    integer :: k
    fp = int(z'CBF29CE484222325',int64)
    do k = 1, size(state%pressure_head)
      word = transfer(state%pressure_head(k),word)
      fp = ieor(fp,word)
      fp = fp * int(z'00000100000001B3',int64)
      word = transfer(state%water_content(k),word)
      fp = ieor(fp,word)
      fp = fp * int(z'00000100000001B3',int64)
    end do
    word = transfer(state%ponding_depth,word)
    fp = ieor(fp,word)
    fp = fp * int(z'00000100000001B3',int64)
  end function state_fingerprint

  logical function same_real(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_real

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_R05_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program observe_transient_richards_response
