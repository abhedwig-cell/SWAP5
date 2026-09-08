program test_fvq14_b110_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: half_duration = 0.5_real64*(t1-t0)

  type(soil_water_parameter_set_t), target :: soil_parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: first_half, second_half
  type(soil_water_physical_state_t) :: initial_state
  real(real64) :: cofgen(24,numnod)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64), target :: drainage_flux_by_level(2,numnod)
  real(real64), target :: subsurface_irrigation_source(numnod), root_extraction_sink(numnod)
  real(real64) :: initial_storage, endpoint_storage
  logical :: ok
  integer :: i, level

  call configure_parameters(cofgen)
  soil_parameters%parameter_set_id = 40401_int64
  soil_parameters%active_nodes = numnod
  allocate(soil_parameters%z(numnod), soil_parameters%dz(numnod), soil_parameters%node_distance(numnod))
  soil_parameters%z = z
  soil_parameters%dz = dz
  soil_parameters%node_distance = disnod(1:numnod)

  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, t1-t0)
  heads = head0
  call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
  call require(all_bits_equal(conductivity), 'uniform conductivity in exact F-MR04 fixture')

  initial_state%active_nodes = numnod
  allocate(initial_state%pressure_head(numnod), initial_state%water_content(numnod))
  initial_state%pressure_head = heads
  initial_state%water_content = water
  initial_state%ponding_depth = 0.0_real64
  initial_state%groundwater_level = -2.0_real64
  initial_storage = sum(dz*water)

  do i = 1, numnod
    drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
    drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
    subsurface_irrigation_source(i) = drainage_flux_by_level(1,i) + drainage_flux_by_level(2,i)
    root_extraction_sink(i) = 0.0_real64
  end do
  call bind_b110_source_sink_provider(source_sink, drainage_flux_by_level, &
       subsurface_irrigation_source, root_extraction_sink)

  request%parameters => soil_parameters
  request%evaluation%constitutive => constitutive
  request%evaluation%source_sink => source_sink
  request%evaluation%top_boundary => top_provider
  request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode = 7
  request%boundary%top_flux = -conductivity(1)
  request%boundary%top_head = head0
  request%boundary%bottom_flux = -conductivity(1)
  request%boundary%bottom_head = -100.0_real64
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

  ! Deliberately poison legacy process arrays exactly as the F-MR04 fixture does.
  ! The admitted provider route must make these irrelevant except qrot, which must stay zero.
  legacy_qdra = 12345.0_real64
  legacy_qssdi = -54321.0_real64
  legacy_qrot = 0.0_real64
  swmacro = 0
  melt = 0.0_real64

  ! F-KT accepts the two-half route for the exact zero-temporal-error fixture.
  ! Reproduce that numerical decomposition independently, but without F-MR or F-KT.
  request%step_duration = half_duration
  request%base_state = initial_state
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_duration)
  call bind_b110_serialized_legacy_context(request, ok)
  call require(ok, 'first-half corrected B1.10 context binding')
  call solver%solve(request, workspace, first_half)
  call require(first_half%status == SW_SOLVE_CONVERGED, 'first-half corrected B1.10 solve')
  call require(trim(first_half%diagnostics%route) == 'legacy-reference-bound', 'first-half real HeadCalc route')

  request%base_state = first_half%candidate_state
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, half_duration)
  call bind_b110_serialized_legacy_context(request, ok)
  call require(ok, 'second-half corrected B1.10 context binding')
  call solver%solve(request, workspace, second_half)
  call require(second_half%status == SW_SOLVE_CONVERGED, 'second-half corrected B1.10 solve')
  call require(trim(second_half%diagnostics%route) == 'legacy-reference-bound', 'second-half real HeadCalc route')

  endpoint_storage = sum(dz*second_half%candidate_state%water_content) + second_half%candidate_state%ponding_depth

  write(*,'(A,I0)') 'VQ14_ORACLE_ACTIVE_NODES=', second_half%candidate_state%active_nodes
  do i = 1, numnod
    write(*,'(A,I0,A,I0)') 'VQ14_ORACLE_HEAD_BITS_', i, '=', &
         transfer(second_half%candidate_state%pressure_head(i),0_int64)
    write(*,'(A,I0,A,I0)') 'VQ14_ORACLE_THETA_BITS_', i, '=', &
         transfer(second_half%candidate_state%water_content(i),0_int64)
  end do
  write(*,'(A,I0)') 'VQ14_ORACLE_POND_BITS=', transfer(second_half%candidate_state%ponding_depth,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_GWL_BITS=', transfer(second_half%candidate_state%groundwater_level,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_TOP_FLUX_BITS=', transfer(second_half%top_flux,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_BOTTOM_FLUX_BITS=', transfer(second_half%bottom_flux,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_INITIAL_STORAGE_BITS=', transfer(initial_storage,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_ENDPOINT_STORAGE_BITS=', transfer(endpoint_storage,0_int64)
  write(*,'(A,I0)') 'VQ14_ORACLE_SOLVER_STATUS=', second_half%status
  write(*,'(A,A)') 'VQ14_ORACLE_SOLVER_ROUTE=', trim(second_half%diagnostics%route)
  write(*,'(A,I0)') 'VQ14_ORACLE_NONLINEAR_ITERATIONS=', second_half%diagnostics%nonlinear_iterations
  write(*,'(A,I0)') 'VQ14_ORACLE_JACOBIAN_BUILDS=', second_half%diagnostics%jacobian_builds
  write(*,'(A,I0)') 'VQ14_ORACLE_LINEAR_SOLVES=', second_half%diagnostics%linear_solves
  write(*,'(A,I0)') 'VQ14_ORACLE_BACKTRACKING_ATTEMPTS=', second_half%diagnostics%backtracking_attempts
  write(*,'(A,I0)') 'VQ14_ORACLE_INTERNAL_RETRIES=', second_half%diagnostics%internal_retries
  write(*,'(A,I0)') 'VQ14_ORACLE_ALT_SOLVER_CALLS=', second_half%diagnostics%alternative_solver_calls
  do i = 1, numnod
    write(*,'(A,I0,A,I0)') 'VQ14_ORACLE_QSSDI_BITS_', i, '=', transfer(subsurface_irrigation_source(i),0_int64)
    write(*,'(A,I0,A,I0)') 'VQ14_ORACLE_QROT_BITS_', i, '=', transfer(root_extraction_sink(i),0_int64)
  end do
  do level = 1, 2
    do i = 1, numnod
      write(*,'(A,I0,A,I0,A,I0)') 'VQ14_ORACLE_QDRA_BITS_', level, '_', i, '=', &
           transfer(drainage_flux_by_level(level,i),0_int64)
    end do
  end do
  write(*,'(A,F0.12)') 'VQ14_ORACLE_T0=', t0
  write(*,'(A,F0.12)') 'VQ14_ORACLE_T1=', t1
  write(*,'(A,F0.12)') 'VQ14_ORACLE_ACCEPTED_SUBSTEP_DURATION=', half_duration
  write(*,'(A)') 'VQ14_ORACLE_REAL_HEADCALC_EXECUTED=TRUE'
  write(*,'(A)') 'VQ14_ORACLE_ROUTE=CORRECTED_B110_BOUND_FSI_TWO_HALF'
  write(*,'(A)') 'VQ14_ORACLE PASS'

contains

  subroutine configure_parameters(values)
    real(real64), intent(out) :: values(24,numnod)
    integer :: node
    values = 0.0_real64
    do node = 1, numnod
      values(1,node) = 0.032_real64
      values(2,node) = 0.423_real64
      values(3,node) = 4.75_real64
      values(4,node) = 0.0135_real64
      values(5,node) = 0.365_real64
      values(6,node) = 1.455_real64
      values(7,node) = 1.0_real64 - 1.0_real64/values(6,node)
      values(8,node) = values(4,node)
      values(9,node) = 0.0_real64
      values(10,node) = values(3,node)
      values(11,node) = 0.999_real64
      values(12,node) = 0.99_real64*values(3,node)
      values(22,node) = -1.0e6_real64
      values(23,node) = 1.0e-12_real64
    end do
  end subroutine configure_parameters

  logical function all_bits_equal(values)
    real(real64), intent(in) :: values(:)
    integer :: node
    all_bits_equal = .true.
    do node = 2, size(values)
      if (transfer(values(node),0_int64) /= transfer(values(1),0_int64)) all_bits_equal = .false.
    end do
  end function all_bits_equal

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'VQ14_ORACLE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq14_b110_reference
