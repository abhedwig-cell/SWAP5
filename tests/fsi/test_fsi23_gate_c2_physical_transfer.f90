program test_fsi23_gate_c2_physical_transfer
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  integer, parameter :: nlevels = 10
  integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512]

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
  real(real64) :: conductivity0, capacity0(numnod), conductivity_nodes(numnod)
  real(real64) :: water0(numnod), dkdh0(numnod), heads0(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod), hdot_np1(numnod), observer(numnod)
  real(real64) :: eobs, e1_512, d128_256, d256_512, r512, floor_cm, max_mass
  logical :: ratio_available, finite_consistent
  integer :: ilevel

  call configure_problem(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       initial_state, drainage, subsurface, root_sink, cofgen, conductivity0)

  heads0 = initial_head_cm
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, total_dt)
  call constitutive%evaluate(heads0, water0, conductivity_nodes, capacity0, dkdh0)
  call require(all(ieee_is_finite(capacity0)) .and. all(capacity0 > 0.0_real64), &
       'bootstrap capacity finite positive')
  call require(all(ieee_is_finite(conductivity_nodes)) .and. all(conductivity_nodes > 0.0_real64), &
       'bootstrap conductivity finite positive')
  do ilevel = 2, numnod
    call require(transfer(conductivity_nodes(ilevel),0_int64) == transfer(conductivity_nodes(1),0_int64), &
         'uniform initial conductivity')
  end do

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity0 * (initial_head_cm-predictor_bottom_head_cm) / &
       (0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual / (capacity0*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite right-sided bootstrap derivative')
  call require(abs(hdot_n(numnod)) > 0.0_real64, 'nonzero prescribed-head bootstrap derivative')

  do ilevel = 1, nlevels
    call run_trajectory(nsteps(ilevel), parameters, hydraulic_parameters, constitutive, source_sink, &
         top_provider, solver, workspace, initial_state, conductivity0, endpoints(ilevel), &
         max_mass_residual(ilevel), max_solver_residual(ilevel))
  end do

  hdot_np1 = (endpoints(1)%pressure_head-initial_head_cm) / total_dt
  observer = 0.5_real64*total_dt*(hdot_np1-hdot_n)
  eobs = maxval(abs(observer))
  e1_512 = maxval(abs(endpoints(1)%pressure_head-endpoints(nlevels)%pressure_head))
  d128_256 = maxval(abs(endpoints(8)%pressure_head-endpoints(9)%pressure_head))
  d256_512 = maxval(abs(endpoints(9)%pressure_head-endpoints(10)%pressure_head))
  floor_cm = 128.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(initial_head_cm),abs(predictor_bottom_head_cm))
  max_mass = maxval(max_mass_residual)

  call require(ieee_is_finite(eobs) .and. eobs >= 0.0_real64, 'finite nonnegative EOBS')
  call require(ieee_is_finite(e1_512) .and. e1_512 >= 0.0_real64, 'finite nonnegative E1_512')
  call require(ieee_is_finite(d128_256) .and. d128_256 >= 0.0_real64, 'finite nonnegative D128_256')
  call require(ieee_is_finite(d256_512) .and. d256_512 >= 0.0_real64, 'finite nonnegative D256_512')
  call require(max_mass <= hard_mass_gate, 'hard mass gate over all trajectories')

  ratio_available = e1_512 > 0.0_real64
  if (ratio_available) then
    r512 = eobs/e1_512
    call require(ieee_is_finite(r512) .and. r512 >= 0.0_real64, 'finite nonnegative R512')
  else
    r512 = -1.0_real64
  end if
  finite_consistent = eobs >= e1_512

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,A,A,A,A,ES26.17E3,A,ES26.17E3)') &
       'FSI23_C2_ROW:H0=',initial_head_cm,':JUMP=',predictor_bottom_head_cm-initial_head_cm, &
       ':EOBS=',eobs,':E1_512=',e1_512,':D128_256=',d128_256,':D256_512=',d256_512, &
       ':FLOOR=',floor_cm,':RATIO_AVAILABLE=',yesno(ratio_available),':EOBS_GE_E1_512=',yesno(finite_consistent), &
       ':R512=',r512,':MAX_MASS=',max_mass
  write(*,'(A)') 'FSI23_C2_PHYSICAL_TRANSFER_CASE PASS'

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

    p%parameter_set_id = 230232_int64
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
    if (.not. same_type_as(tp,tp)) error stop 'F-SI23 C2 invalid top provider type'
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
    call require(subdt >= 1.0e-6_real64, 'trajectory substep above frozen dtmin')
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
      call require(result%status == SW_SOLVE_CONVERGED, 'C2 direct Richards solve converged')
      storage1 = sum(result%candidate_state%water_content * p%dz) + result%candidate_state%ponding_depth
      total_in = max(0.0_real64,-result%top_flux)*subdt + max(0.0_real64,result%bottom_flux)*subdt
      total_out = max(0.0_real64,result%top_flux)*subdt + max(0.0_real64,-result%bottom_flux)*subdt
      residual = storage1 - storage0 - (total_in-total_out)
      max_mass = max(max_mass,abs(residual))
      max_solver = max(max_solver,abs(result%unrounded_mass_balance_residual))
      call require(abs(residual) <= hard_mass_gate, 'hard C2 trajectory mass gate')
      state = result%candidate_state
    end do
    endpoint = state
  end subroutine run_trajectory

  pure function yesno(value) result(text)
    logical, intent(in) :: value
    character(len=3) :: text
    if (value) then
      text = 'YES'
    else
      text = 'NO '
    end if
  end function yesno

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI23_C2_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi23_gate_c2_physical_transfer
