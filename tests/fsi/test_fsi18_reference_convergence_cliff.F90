program test_fsi18_reference_convergence_cliff
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use variables, only: fldtmin
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  implicit none

  integer, parameter :: ncases = 5
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: step_duration = 1.0_real64
  real(real64), parameter :: perturbation(ncases) = [0.0_real64, 3.0e-12_real64, -3.0e-12_real64, &
       1.0e-11_real64, -1.0e-11_real64]
  character(len=20), parameter :: case_name(ncases) = [character(len=20) :: &
       'baseline', 'plus_3e-12', 'minus_3e-12', 'plus_1e-11', 'minus_1e-11']

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_root_sink_provider_t), target :: root_sink
  real(real64), target :: qdra(2,numnod), qssdi(numnod), zero_root(numnod)
  real(real64) :: water0(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: heads(numnod), cofgen(24,numnod), k0
  integer :: i, node

  if (numnod /= 4) error stop 'F-SI18 requires exact four-node qualified B1.10 test grid'
  swmacro = 0
  fldtmin = .false.

  parameters%parameter_set_id = 18001
  parameters%active_nodes = numnod
  allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
  parameters%z = z
  parameters%dz = dz
  parameters%node_distance = disnod(1:numnod)

  cofgen = 0.0_real64
  do node = 1, numnod
    cofgen(1,node) = 0.032_real64
    cofgen(2,node) = 0.423_real64
    cofgen(3,node) = 4.75_real64
    cofgen(4,node) = 0.0135_real64
    cofgen(5,node) = 0.365_real64
    cofgen(6,node) = 1.455_real64
    cofgen(7,node) = 1.0_real64 - 1.0_real64/cofgen(6,node)
    cofgen(8,node) = cofgen(4,node)
    cofgen(9,node) = 0.0_real64
    cofgen(10,node) = cofgen(3,node)
    cofgen(11,node) = 0.999_real64
    cofgen(12,node) = 0.99_real64*cofgen(3,node)
    cofgen(22,node) = -1.0e6_real64
    cofgen(23,node) = 1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, step_duration)
  heads = head0
  call constitutive%evaluate(heads, water0, conductivity, capacity, dkdh)
  k0 = conductivity(1)
  do node = 2, numnod
    if (conductivity(node) /= k0) error stop 'F-SI18 requires uniform equilibrium conductivity'
  end do

  do node = 1, numnod
    qdra(1,node) = 1.0e-5_real64*real(node,real64)
    qdra(2,node) = -2.0e-6_real64*real(node+1,real64)
    qssdi(node) = qdra(1,node) + qdra(2,node)
    zero_root(node) = 0.0_real64
  end do
  call bind_b110_source_sink_provider(source_sink, qdra, qssdi, zero_root)
  call bind_b110_root_sink_provider(root_sink, zero_root)

  write(*,'(A,ES26.17E3)') 'FSI18_K0=', k0
  do i = 1, ncases
    call run_case(i, perturbation(i))
  end do
  write(*,'(A)') 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS'

contains

  subroutine run_case(case_id, delta)
    integer, intent(in) :: case_id
    real(real64), intent(in) :: delta
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(fsi07_flux_top_provider_t), target :: top_provider
    real(real64) :: requested_top_flux

    requested_top_flux = -(1.0_real64 + delta)*k0
    top_provider%fixed_flux = requested_top_flux
    top_provider%surface_tracks_head = .true.

    request%parameters => parameters
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%root_sink => root_sink
    request%evaluation%top_boundary => top_provider
    request%step_duration = step_duration
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 7
    request%boundary%top_flux = requested_top_flux
    request%boundary%top_head = head0
    request%boundary%bottom_flux = -k0
    request%boundary%bottom_head = -100.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 8
    request%numerical%max_backtracking = 4
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-6_real64
    request%numerical%compartment_balance_tolerance = 1.0e-12_real64
    request%numerical%total_balance_tolerance = 1.0e-12_real64
    request%numerical%head_abs_tolerance = 1.0e-12_real64
    request%numerical%head_rel_tolerance = 1.0e-12_real64
    request%numerical%ponding_tolerance = 1.0e-12_real64
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = head0
    request%base_state%water_content = water0
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -2.0_real64

    call solver%solve(request, workspace, result)
    if (case_id == 1 .and. result%status /= SW_SOLVE_CONVERGED) &
         error stop 'F-SI18 exact equilibrium baseline must converge'
    if (result%status /= SW_SOLVE_CONVERGED .and. result%status /= SW_SOLVE_RETRY_ADVISED) &
         error stop 'F-SI18 unexpected solver status'

    write(*,'(A,I0,A,A)') 'FSI18_CASE_', case_id, '_NAME=', trim(case_name(case_id))
    write(*,'(A,I0,A,ES26.17E3)') 'FSI18_CASE_', case_id, '_DELTA=', delta
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_STATUS=', result%status
    write(*,'(A,I0,A,L1)') 'FSI18_CASE_', case_id, '_CONVERGED=', result%status == SW_SOLVE_CONVERGED
    write(*,'(A,I0,A,L1)') 'FSI18_CASE_', case_id, '_RETRY_ADVISED=', result%status == SW_SOLVE_RETRY_ADVISED
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_NONLINEAR_ITERATIONS=', result%diagnostics%nonlinear_iterations
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_INTERNAL_RETRIES=', result%diagnostics%internal_retries
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_JACOBIAN_BUILDS=', result%diagnostics%jacobian_builds
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_LINEAR_SOLVES=', result%diagnostics%linear_solves
    write(*,'(A,I0,A,I0)') 'FSI18_CASE_', case_id, '_BACKTRACKING_ATTEMPTS=', result%diagnostics%backtracking_attempts
    write(*,'(A,I0,A,A)') 'FSI18_CASE_', case_id, '_ROUTE=', trim(result%diagnostics%route)
  end subroutine run_case
end program test_fsi18_reference_convergence_cliff
