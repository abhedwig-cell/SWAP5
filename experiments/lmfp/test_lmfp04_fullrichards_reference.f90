program test_lmfp04_fullrichards_reference
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use MOD_drain, only: qdra
  use MOD_irrigation, only: qssdi
  use variables
  use mod_soil_water_solver_contract
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  type(soil_water_parameter_set_t), target :: kernel_params
  type(b110_default_mvg_parameters_t), target :: hydraulic_params
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fsi08_source_sink_provider_t), target :: source_sink
  type(fsi07_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  real(real64), parameter :: dzx(4) = [10.0_real64, 10.0_real64, 20.0_real64, 20.0_real64]
  real(real64), parameter :: zx(4) = [-5.0_real64, -15.0_real64, -30.0_real64, -50.0_real64]
  real(real64), parameter :: dx(4) = [5.0_real64, 10.0_real64, 15.0_real64, 20.0_real64]
  integer :: case_id, refinement, failures

  if (numnod /= 4) error stop 'F-LMFP04 fixture requires four nodes'
  failures = 0
  call seed_shared_fixture()
  call configure_geometry()
  do case_id = 1, 6
     do refinement = 1, 2
        call run_case(case_id, refinement, failures)
     end do
  end do
  if (failures /= 0) then
     write(*,'(A,1X,I0)') 'F-LMFP04_FULLRICHARDS_REFERENCE_FAIL', failures
     error stop 1
  end if
  write(*,'(A)') 'F-LMFP04_FULLRICHARDS_REFERENCE_PASS'

contains

  subroutine configure_geometry()
    kernel_params%parameter_set_id = 43104
    kernel_params%active_nodes = numnod
    allocate(kernel_params%z(numnod), kernel_params%dz(numnod), kernel_params%node_distance(numnod))
    kernel_params%z = zx
    kernel_params%dz = dzx
    kernel_params%node_distance = dx
  end subroutine configure_geometry

  subroutine seed_shared_fixture()
    swmacro = 0
    swbotb = 7
    swkimpl = 0
    swkmean = 1
    fldtmin = .false.
    fldaystart = .false.
    maxit = 30
    maxbacktr = 12
    dtmin = 1.0e-8_real64
    CritDevBalCp = 1.0e-10_real64
    CritDevBalTot = 1.0e-10_real64
    critdevh2cp = 1.0e-8_real64
    critdevh1cp = 1.0e-8_real64
    critdevponddt = 1.0e-10_real64
    q0 = 0.0_real64
    hsurf = 0.0_real64
    flrunoff = .false.
    ftoph = .false.
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    pond = 0.0_real64
    pondm1 = 0.0_real64
    gwl = -999.0_real64
    gwlm1 = -999.0_real64
    fllowgwl = .false.
    fldecdt = .false.
    itnumb = 0
    numbit = 0
  end subroutine seed_shared_fixture

  subroutine fill_material(code, input, node)
    integer, intent(in) :: code, node
    real(real64), intent(inout) :: input(24,numnod)
    real(real64) :: tr, ts, ks, alpha, lambda, nn, mm
    select case(code)
    case(1)
       tr = 0.045_real64; ts = 0.430_real64; ks = 20.0_real64
       alpha = 0.040_real64; lambda = 0.50_real64; nn = 1.80_real64
    case(2)
       tr = 0.080_real64; ts = 0.500_real64; ks = 0.20_real64
       alpha = 0.010_real64; lambda = 0.50_real64; nn = 1.30_real64
    case default
       error stop 'unknown F-LMFP04 material code'
    end select
    mm = 1.0_real64 - 1.0_real64/nn
    input(1,node) = tr
    input(2,node) = ts
    input(3,node) = ks
    input(4,node) = alpha
    input(5,node) = lambda
    input(6,node) = nn
    input(7,node) = mm
    input(8,node) = alpha
    input(9,node) = 0.0_real64
    input(10,node) = ks
    input(11,node) = 0.999_real64
    input(12,node) = 0.99_real64*ks
    input(22,node) = -1.0e6_real64
    input(23,node) = 1.0e-12_real64
  end subroutine fill_material

  subroutine configure_provider(codes, step_dt)
    integer, intent(in) :: codes(numnod)
    real(real64), intent(in) :: step_dt
    real(real64) :: input(24,numnod)
    integer :: i
    input = 0.0_real64
    do i = 1, numnod
       call fill_material(codes(i), input, i)
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_params, input)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_params, step_dt)
  end subroutine configure_provider

  subroutine case_definition(case_id, codes, heads, duration, base_dt, top_down, name)
    integer, intent(in) :: case_id
    integer, intent(out) :: codes(numnod)
    real(real64), intent(out) :: heads(numnod), duration, base_dt, top_down
    character(len=*), intent(out) :: name
    select case(case_id)
    case(1)
       name = 'steady_sand'
       codes = [1,1,1,1]
       heads = -100.0_real64
       duration = 0.20_real64; base_dt = 0.02_real64; top_down = -1.0_real64
    case(2)
       name = 'redistribution_sand'
       codes = [1,1,1,1]
       heads = [-200.0_real64,-120.0_real64,-60.0_real64,-30.0_real64]
       duration = 0.20_real64; base_dt = 0.005_real64; top_down = 0.0_real64
    case(3)
       name = 'infiltration_sand'
       codes = [1,1,1,1]
       heads = -200.0_real64
       duration = 0.20_real64; base_dt = 0.005_real64; top_down = 0.10_real64
    case(4)
       name = 'infiltration_clay'
       codes = [2,2,2,2]
       heads = -200.0_real64
       duration = 0.50_real64; base_dt = 0.01_real64; top_down = 0.01_real64
    case(5)
       name = 'sand_over_clay'
       codes = [1,1,2,2]
       heads = [-150.0_real64,-100.0_real64,-70.0_real64,-50.0_real64]
       duration = 0.20_real64; base_dt = 0.005_real64; top_down = 0.0_real64
    case(6)
       name = 'clay_over_sand'
       codes = [2,2,1,1]
       heads = [-150.0_real64,-100.0_real64,-70.0_real64,-50.0_real64]
       duration = 0.20_real64; base_dt = 0.005_real64; top_down = 0.0_real64
    case default
       error stop 'unknown F-LMFP04 case'
    end select
  end subroutine case_definition

  subroutine initialize_request(request, heads, top_down, step_dt)
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64), intent(in) :: heads(numnod), top_down, step_dt
    real(real64) :: water(numnod), kval(numnod), cap(numnod), dk(numnod)
    call constitutive%evaluate(heads, water, kval, cap, dk)
    request%parameters => kernel_params
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_provider
    request%step_duration = step_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 7
    request%boundary%top_flux = -top_down
    request%boundary%top_head = heads(1)
    request%boundary%bottom_flux = 0.0_real64
    request%boundary%bottom_head = 0.0_real64
    request%numerical%max_iterations = 30
    request%numerical%max_backtracking = 12
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-8_real64
    request%numerical%compartment_balance_tolerance = 1.0e-10_real64
    request%numerical%total_balance_tolerance = 1.0e-10_real64
    request%numerical%head_abs_tolerance = 1.0e-8_real64
    request%numerical%head_rel_tolerance = 1.0e-8_real64
    request%numerical%ponding_tolerance = 1.0e-10_real64
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = heads
    request%base_state%water_content = water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -999.0_real64
  end subroutine initialize_request

  subroutine prepare_workspace(ws)
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    call initialize_reference_workspace(ws%richards, numnod)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes = 0
    ws%legacy_worker%worker_id = 43104
  end subroutine prepare_workspace

  subroutine run_case(case_id, refinement, fails)
    integer, intent(in) :: case_id, refinement
    integer, intent(inout) :: fails
    integer :: codes(numnod), step, nsteps, i, iter_total, iter_max
    real(real64) :: heads(numnod), duration, base_dt, top_down, step_dt
    real(real64) :: water(numnod), kval(numnod), cap(numnod), dk(numnod)
    real(real64) :: delta_storage, residual, max_mass, initial_storage, final_storage
    character(len=32) :: name
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_workspace_t) :: ws

    call case_definition(case_id, codes, heads, duration, base_dt, top_down, name)
    step_dt = base_dt / real(refinement,real64)
    nsteps = nint(duration / step_dt)
    call configure_provider(codes, step_dt)
    call constitutive%evaluate(heads, water, kval, cap, dk)
    if (case_id == 1) top_down = kval(1)
    top_provider%fixed_flux = -top_down
    top_provider%surface_tracks_head = .true.
    source_sink%source_value = 0.0_real64
    source_sink%sink_value = 0.0_real64
    call initialize_request(request, heads, top_down, step_dt)
    initial_storage = sum(dzx * request%base_state%water_content)
    max_mass = 0.0_real64
    iter_total = 0
    iter_max = 0

    do step = 1, nsteps
       call prepare_workspace(ws)
       call solver%solve(request, ws, result)
       if (result%status /= SW_SOLVE_CONVERGED) then
          fails = fails + 1
          write(*,'(A,1X,I0,1X,I0,1X,I0,1X,A)') 'RETRY_OR_FAIL', case_id, refinement, step, trim(result%diagnostics%route)
          return
       end if
       if (result%diagnostics%alternative_solver_calls /= 0) then
          fails = fails + 1
          write(*,'(A,1X,I0,1X,I0,1X,I0)') 'BANDED_FALLBACK_USED', case_id, refinement, step
          return
       end if
       if (.not. all(ieee_is_finite(result%candidate_state%pressure_head)) .or. &
           .not. all(ieee_is_finite(result%candidate_state%water_content))) then
          fails = fails + 1
          return
       end if
       delta_storage = sum(dzx * (result%candidate_state%water_content - request%base_state%water_content))
       residual = delta_storage + step_dt * (result%top_flux - result%bottom_flux)
       max_mass = max(max_mass, abs(residual))
       iter_total = iter_total + result%diagnostics%nonlinear_iterations
       iter_max = max(iter_max, result%diagnostics%nonlinear_iterations)
       request%base_state%pressure_head = result%candidate_state%pressure_head
       request%base_state%water_content = result%candidate_state%water_content
       request%base_state%ponding_depth = result%candidate_state%ponding_depth
       request%base_state%groundwater_level = result%candidate_state%groundwater_level
    end do

    final_storage = sum(dzx * request%base_state%water_content)
    write(*,'(A,1X,I0,1X,I0,1X,A,1X,ES24.16,1X,I0,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0)') &
         'SUMMARY', case_id, refinement, trim(name), step_dt, nsteps, top_down, -result%bottom_flux, &
         initial_storage, final_storage, iter_total, iter_max
    write(*,'(A,1X,I0,1X,I0,1X,ES24.16)') 'MASS', case_id, refinement, max_mass
    do i = 1, numnod
       write(*,'(A,1X,I0,1X,I0,1X,I0,1X,ES24.16,1X,ES24.16)') &
            'NODE', case_id, refinement, i, request%base_state%pressure_head(i), request%base_state%water_content(i)
    end do
  end subroutine run_case
end program test_lmfp04_fullrichards_reference
