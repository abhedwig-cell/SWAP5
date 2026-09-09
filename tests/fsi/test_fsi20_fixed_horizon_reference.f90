program test_fsi20_fixed_horizon_reference
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
  real(real64), parameter :: initial_head_cm = -75.0_real64
  real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: nlevels = 11
  integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512,1024]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_physical_state_t) :: endpoints(nlevels)
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: max_mass_residual(nlevels), max_solver_residual(nlevels)
  real(real64) :: conductivity0
  real(real64) :: dhead, dtheta, endpoint_head_error, endpoint_theta_error
  real(real64) :: refined_head_error, refined_theta_error, signed_storage_error
  integer :: ilevel

  call configure_problem(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       initial_state, drainage, subsurface, root_sink, cofgen, conductivity0)

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
       'FSI20_FIXED_BEGIN:TOTAL_DT=', total_dt, ':H0=', initial_head_cm, &
       ':HBOT=', predictor_bottom_head_cm
  write(*,'(A,I0,A,I0,A,ES26.17E3)') &
       'FSI20_FIXED_NUMERICS:MAXIT=', 8, ':MAXBACK=', 4, ':DTMIN=', 1.0e-6_real64

  do ilevel = 1, nlevels
    call run_trajectory(nsteps(ilevel), parameters, hydraulic_parameters, constitutive, source_sink, &
         top_provider, solver, workspace, initial_state, conductivity0, endpoints(ilevel), &
         max_mass_residual(ilevel), max_solver_residual(ilevel))
    write(*,'(A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'FSI20_FIXED_ENDPOINT:N=', nsteps(ilevel), ':SUB_DT=', total_dt/real(nsteps(ilevel),real64), &
         ':MAX_MASS_RESIDUAL=', max_mass_residual(ilevel), &
         ':MAX_SOLVER_RESIDUAL=', max_solver_residual(ilevel)
  end do

  do ilevel = 1, nlevels-1
    dhead = maxval(abs(endpoints(ilevel)%pressure_head - endpoints(ilevel+1)%pressure_head))
    dtheta = maxval(abs(endpoints(ilevel)%water_content - endpoints(ilevel+1)%water_content))
    endpoint_head_error = maxval(abs(endpoints(ilevel)%pressure_head - endpoints(nlevels)%pressure_head))
    endpoint_theta_error = maxval(abs(endpoints(ilevel)%water_content - endpoints(nlevels)%water_content))
    refined_head_error = maxval(abs(endpoints(ilevel+1)%pressure_head - endpoints(nlevels)%pressure_head))
    refined_theta_error = maxval(abs(endpoints(ilevel+1)%water_content - endpoints(nlevels)%water_content))
    signed_storage_error = sum(dz(1:numnod) * &
         (endpoints(ilevel)%water_content - endpoints(nlevels)%water_content)) + &
         endpoints(ilevel)%ponding_depth - endpoints(nlevels)%ponding_depth
    write(*,'(A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'FSI20_FIXED_COMPARE:N=', nsteps(ilevel), ':N2=', nsteps(ilevel+1), &
         ':DHEAD_N_N2=', dhead, ':DTHETA_N_N2=', dtheta, &
         ':EHEAD_N_REF=', endpoint_head_error, ':ETHETA_N_REF=', endpoint_theta_error, &
         ':EHEAD_N2_REF=', refined_head_error, ':ETHETA_N2_REF=', refined_theta_error, &
         ':SIGNED_STORAGE_N_REF=', signed_storage_error
  end do

  write(*,'(A)') 'FSI20_FIXED_HORIZON_REFERENCE_DRIVER PASS'

contains

  subroutine configure_problem(p, hp, cp, sp, tp, state, qdra, qssdi, qrot, c, k0)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 202020_int64
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

    heads = initial_head_cm
    call cp%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
           'uniform initial conductivity')
    end do
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp, qdra, qssdi, qrot)
    if (.not. same_type_as(tp,tp)) error stop 'unreachable top provider type'
  end subroutine configure_problem

  subroutine run_trajectory(ns, p, hp, cp, sp, tp, s, ws, initial, k0, endpoint, max_mass, max_solver)
    integer, intent(in) :: ns
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t), intent(in) :: initial
    real(real64), intent(in) :: k0
    type(soil_water_physical_state_t), intent(out) :: endpoint
    real(real64), intent(out) :: max_mass, max_solver
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: subdt, storage0, storage1, total_in, total_out, residual
    integer :: istep

    call require(ns > 0, 'positive trajectory step count')
    subdt = total_dt / real(ns,real64)
    call require(subdt >= 1.0e-6_real64, 'trajectory substep above exact F-GC02 dtmin')
    state = initial
    max_mass = 0.0_real64
    max_solver = 0.0_real64

    do istep = 1, ns
      call bind_b110_default_mvg_provider(cp, hp, subdt)
      request = soil_water_solve_request_t()
      request%parameters => p
      request%base_state = state
      request%step_duration = subdt
      request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%bottom_mode = 5
      request%boundary%top_flux = -k0
      request%boundary%top_head = initial_head_cm
      request%boundary%bottom_flux = 12345.678_real64
      request%boundary%bottom_head = predictor_bottom_head_cm
      request%physical%macropore_active = .false.
      request%numerical%max_iterations = 8
      request%numerical%max_backtracking = 4
      request%numerical%conductivity_implicit_mode = 0
      request%numerical%conductivity_mean_method = 1
      request%numerical%min_step_duration = 1.0e-6_real64
      request%numerical%compartment_balance_tolerance = hard_mass_gate
      request%numerical%total_balance_tolerance = hard_mass_gate
      request%numerical%head_abs_tolerance = 1.0e-12_real64
      request%numerical%head_rel_tolerance = 1.0e-12_real64
      request%numerical%ponding_tolerance = 1.0e-12_real64
      request%evaluation%constitutive => cp
      request%evaluation%source_sink => sp
      request%evaluation%top_boundary => tp

      storage0 = sum(state%water_content * p%dz) + state%ponding_depth
      call s%solve(request, ws, result)
      call require(result%status == SW_SOLVE_CONVERGED, 'fixed-horizon direct Richards solve converged')
      storage1 = sum(result%candidate_state%water_content * p%dz) + result%candidate_state%ponding_depth
      total_in = max(0.0_real64,-result%top_flux)*subdt + max(0.0_real64,result%bottom_flux)*subdt
      total_out = max(0.0_real64,result%top_flux)*subdt + max(0.0_real64,-result%bottom_flux)*subdt
      residual = storage1 - storage0 - (total_in-total_out)
      max_mass = max(max_mass,abs(residual))
      max_solver = max(max_solver,abs(result%unrounded_mass_balance_residual))
      call require(abs(residual) <= hard_mass_gate, 'hard trajectory mass gate')
      state = result%candidate_state
    end do
    endpoint = state
  end subroutine run_trajectory

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI20_FIXED_REFERENCE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi20_fixed_horizon_reference
