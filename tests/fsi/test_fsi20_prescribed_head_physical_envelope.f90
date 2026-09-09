program test_fsi20_prescribed_head_physical_envelope
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
  integer, parameter :: nh = 3, nd = 5, nref = 128
  real(real64), parameter :: initial_heads(nh) = [-25.0_real64, -75.0_real64, -250.0_real64]
  real(real64), parameter :: head_jumps(nd) = [-0.1_real64, -0.01_real64, 0.001_real64, 0.01_real64, 0.1_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  integer :: ih, id, case_id

  call configure_shared(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       drainage, subsurface, root_sink, cofgen)

  write(*,'(A,ES26.17E3,A,I0,A,ES26.17E3)') &
       'FSI20_ENVELOPE_BEGIN:TOTAL_DT=', total_dt, ':NREF=', nref, ':MASS_TOL=', hard_mass_gate
  write(*,'(A,I0,A,I0,A,ES26.17E3)') &
       'FSI20_ENVELOPE_NUMERICS:MAXIT=', 8, ':MAXBACK=', 4, ':DTMIN=', 1.0e-6_real64

  case_id = 0
  do ih = 1, nh
    do id = 1, nd
      case_id = case_id + 1
      call characterize_case(case_id, initial_heads(ih), head_jumps(id), parameters, hydraulic_parameters, &
           constitutive, source_sink, top_provider, solver, workspace)
    end do
  end do

  write(*,'(A)') 'FSI20_PRESCRIBED_HEAD_PHYSICAL_ENVELOPE_DRIVER PASS'

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

    p%parameter_set_id = 202022_int64
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
  end subroutine configure_shared

  subroutine characterize_case(cid, h0, jump, p, hp, cp, sp, tp, s, ws)
    integer, intent(in) :: cid
    real(real64), intent(in) :: h0, jump
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t) :: initial, e1, e2, eref
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: k0, hbot, mass1, mass2, massref, solver1, solver2, solverref
    real(real64) :: dhead, dtheta, e1h, e2h, e1theta, e2theta, ratio, signed_storage
    integer :: k

    call bind_b110_default_mvg_provider(cp, hp, total_dt)
    heads = h0
    call cp%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
           'uniform initial conductivity in envelope case')
    end do
    k0 = conductivity(1)
    hbot = h0 + jump

    initial%active_nodes = numnod
    allocate(initial%pressure_head(numnod), initial%water_content(numnod))
    initial%pressure_head = heads
    initial%water_content = water
    initial%ponding_depth = 0.0_real64
    initial%groundwater_level = -2.0_real64

    call run_trajectory(1, h0, hbot, k0, p, hp, cp, sp, tp, s, ws, initial, e1, mass1, solver1)
    call run_trajectory(2, h0, hbot, k0, p, hp, cp, sp, tp, s, ws, initial, e2, mass2, solver2)
    call run_trajectory(nref, h0, hbot, k0, p, hp, cp, sp, tp, s, ws, initial, eref, massref, solverref)

    dhead = maxval(abs(e1%pressure_head-e2%pressure_head))
    dtheta = maxval(abs(e1%water_content-e2%water_content))
    e1h = maxval(abs(e1%pressure_head-eref%pressure_head))
    e2h = maxval(abs(e2%pressure_head-eref%pressure_head))
    e1theta = maxval(abs(e1%water_content-eref%water_content))
    e2theta = maxval(abs(e2%water_content-eref%water_content))
    signed_storage = sum(p%dz*(e2%water_content-eref%water_content)) + e2%ponding_depth-eref%ponding_depth
    if (e2h > 0.0_real64) then
      ratio = dhead/e2h
    else
      ratio = huge(0.0_real64)
    end if

    write(*,'(A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'FSI20_ENVELOPE_CASE=', cid, ':H0=', h0, ':JUMP=', jump, ':HBOT=', hbot, &
         ':DHEAD=', dhead, ':DTHETA=', dtheta, ':EHEAD_N1_REF=', e1h, ':EHEAD_N2_REF=', e2h, &
         ':ETHETA_N1_REF=', e1theta, ':ETHETA_N2_REF=', e2theta, ':DHEAD_OVER_E2=', ratio, &
         ':SIGNED_STORAGE_N2_REF=', signed_storage, ':MAX_MASS=', max(mass1,mass2,massref), &
         ':MAX_SOLVER_RES=', max(solver1,solver2,solverref)
  end subroutine characterize_case

  subroutine run_trajectory(ns, h0, hbot, k0, p, hp, cp, sp, tp, s, ws, initial, endpoint, max_mass, max_solver)
    integer, intent(in) :: ns
    real(real64), intent(in) :: h0, hbot, k0
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t), intent(in) :: initial
    type(soil_water_physical_state_t), intent(out) :: endpoint
    real(real64), intent(out) :: max_mass, max_solver
    type(soil_water_physical_state_t) :: state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: subdt, storage0, storage1, total_in, total_out, residual
    integer :: istep

    call require(ns > 0, 'positive trajectory step count')
    subdt = total_dt/real(ns,real64)
    call require(subdt >= 1.0e-6_real64, 'envelope trajectory above exact F-GC02 dtmin')
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
      request%boundary%top_head = h0
      request%boundary%bottom_flux = 12345.678_real64
      request%boundary%bottom_head = hbot
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

      storage0 = sum(state%water_content*p%dz) + state%ponding_depth
      call s%solve(request, ws, result)
      call require(result%status == SW_SOLVE_CONVERGED, 'envelope direct Richards solve converged')
      storage1 = sum(result%candidate_state%water_content*p%dz) + result%candidate_state%ponding_depth
      total_in = max(0.0_real64,-result%top_flux)*subdt + max(0.0_real64,result%bottom_flux)*subdt
      total_out = max(0.0_real64,result%top_flux)*subdt + max(0.0_real64,-result%bottom_flux)*subdt
      residual = storage1-storage0-(total_in-total_out)
      max_mass = max(max_mass,abs(residual))
      max_solver = max(max_solver,abs(result%unrounded_mass_balance_residual))
      call require(abs(residual) <= hard_mass_gate, 'hard envelope trajectory mass gate')
      state = result%candidate_state
    end do
    endpoint = state
  end subroutine run_trajectory

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI20_ENVELOPE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi20_prescribed_head_physical_envelope
