program test_fmr44_direct_qbot_envelope
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: internal_tolerance = 1.0e-12_real64
  real(real64), parameter :: q_values(5) = [-1.0e-6_real64, -1.0e-10_real64, 0.0_real64, &
                                             1.0e-10_real64,  1.0e-6_real64]
  real(real64), parameter :: dt_values(4) = [1.0e-2_real64, 1.0e-4_real64, 1.0e-6_real64, 1.0e-8_real64]
  integer :: iq, idt, converged_positive, converged_zero, converged_negative

  converged_positive = 0
  converged_zero = 0
  converged_negative = 0
  do idt = 1, size(dt_values)
    do iq = 1, size(q_values)
      call run_case(q_values(iq), dt_values(idt), converged_positive, converged_zero, converged_negative)
    end do
  end do

  write(*,'(A,I0)') 'FMR44_DIRECT_NEGATIVE_CONVERGED=', converged_negative
  write(*,'(A,I0)') 'FMR44_DIRECT_ZERO_CONVERGED=', converged_zero
  write(*,'(A,I0)') 'FMR44_DIRECT_POSITIVE_CONVERGED=', converged_positive
  write(*,'(A)') 'FMR44_DIRECT_REAL_MVG_QBOT_ENVELOPE_COMPLETE=PASS'

contains

  subroutine run_case(q, step_dt, npos, nzero, nneg)
    real(real64), intent(in) :: q, step_dt
    integer, intent(inout) :: npos, nzero, nneg
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64), target :: drainage(1,numnod), irrigation(numnod), root_sink(numnod)
    real(real64) :: cofgen(24,numnod)
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: storage0, storage1, total_in, total_out, ledger_residual
    integer :: i

    call configure_parameters(parameters, cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, step_dt)

    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
      call require(abs((heads(i-1)-heads(i))/parameters%node_distance(i)+1.0_real64) <= &
           16.0_real64*epsilon(1.0_real64), 'hydrostatic gradient construction')
    end do
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)), &
         'finite initial real-MVG state')
    call require(all(conductivity > 0.0_real64) .and. all(capacity > 0.0_real64), &
         'positive real-MVG conductivity and capacity')

    drainage = 0.0_real64
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = heads
    request%base_state%water_content = water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -2.0_real64
    request%step_duration = step_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 2
    request%boundary%top_flux = q
    request%boundary%top_head = heads(1)
    request%boundary%bottom_flux = q
    request%boundary%bottom_head = 777777.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 16
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-12_real64
    request%numerical%compartment_balance_tolerance = internal_tolerance
    request%numerical%total_balance_tolerance = internal_tolerance
    request%numerical%head_abs_tolerance = internal_tolerance
    request%numerical%head_rel_tolerance = internal_tolerance
    request%numerical%ponding_tolerance = internal_tolerance
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_provider

    call solver%solve(request, workspace, result)

    ledger_residual = huge(0.0_real64)
    if (result%status == SW_SOLVE_CONVERGED) then
      storage0 = sum(request%base_state%water_content*parameters%dz) + request%base_state%ponding_depth
      storage1 = sum(result%candidate_state%water_content*parameters%dz) + result%candidate_state%ponding_depth
      total_in = max(0.0_real64,-result%top_flux)*step_dt + max(0.0_real64,result%bottom_flux)*step_dt
      total_out = max(0.0_real64,result%top_flux)*step_dt + max(0.0_real64,-result%bottom_flux)*step_dt
      ledger_residual = storage1-storage0-(total_in-total_out)
      call require(transfer(result%bottom_flux,0_int64) == transfer(q,0_int64), &
           'converged direct qbot identity')
      if (q > 0.0_real64) then
        npos = npos + 1
      else if (q < 0.0_real64) then
        nneg = nneg + 1
      else
        nzero = nzero + 1
      end if
    end if

    write(*,'(A,ES16.8E3,A,ES16.8E3,A,I0,A,A)') 'FMR44_DIRECT_CASE q=',q,':dt=',step_dt, &
         ':status=',result%status,':route=',trim(result%diagnostics%route)
    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0)') 'FMR44_DIRECT_COST nonlinear=',result%diagnostics%nonlinear_iterations, &
         ':jacobian=',result%diagnostics%jacobian_builds,':linear=',result%diagnostics%linear_solves, &
         ':backtracking=',result%diagnostics%backtracking_attempts,':internal_retries=',result%diagnostics%internal_retries
    write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') 'FMR44_DIRECT_FLUX top=',result%top_flux, &
         ':bottom=',result%bottom_flux,':solver_mass=',result%unrounded_mass_balance_residual
    if (result%status == SW_SOLVE_CONVERGED) then
      write(*,'(A,ES26.17E3,A,4(1X,ES16.8E3))') 'FMR44_DIRECT_ACCEPTED ledger_mass=',ledger_residual, &
           ':heads=',result%candidate_state%pressure_head
    end if
  end subroutine run_case

  subroutine configure_parameters(parameters, cofgen)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    real(real64), intent(out) :: cofgen(24,numnod)
    integer :: i

    parameters%parameter_set_id = 440044_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    cofgen = 0.0_real64
    do i = 1, numnod
      cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64; cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i); cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    end do
  end subroutine configure_parameters

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR44_DIRECT_DIAGNOSTIC_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr44_direct_qbot_envelope
