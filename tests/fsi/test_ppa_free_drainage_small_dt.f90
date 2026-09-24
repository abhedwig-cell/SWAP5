program test_ppa_free_drainage_small_dt
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, &
       SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_ppa_free_drainage_stiffness, only: evaluate_free_drainage_stiffness
  use mod_ppa_free_drainage_temporal_indicator, only: evaluate_free_drainage_temporal_indicator
  implicit none

  real(real64), parameter :: h0=-75.0_real64, hard_mass_gate=1.0e-12_real64
  integer :: exponent, accepted, rejected
  accepted=0
  rejected=0
  do exponent=0,19
    call diagnose_step(0.5_real64/2.0_real64**exponent,accepted,rejected)
  end do
  call require(accepted>0.and.rejected>0,'sweep covers both converged and rejected attempts')
  write(*,'(a)') 'FREE_DRAINAGE_SMALL_DT_DIAGNOSTIC=PASS'
contains
  subroutine diagnose_step(step_dt,accepted,rejected)
    real(real64), intent(in) :: step_dt
    integer, intent(inout) :: accepted,rejected
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_root_sink_provider_t), target :: root_provider
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace, comparison_workspace
    type(soil_water_solve_request_t) :: request, unsupported_request
    type(soil_water_solve_result_t) :: result, comparison_result
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator, unsupported
    real(real64), target :: drainage(1,numnod), irrigation(numnod), root_sink(numnod)
    real(real64), target :: no_root(numnod)
    real(real64) :: cofgen(24,numnod)
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: candidate_water(numnod), candidate_k(numnod), candidate_capacity(numnod), candidate_dkdh(numnod)
    real(real64) :: expected_raw, expected_defect, expected_bounded, expected_binf, wrong_binf
    real(real64) :: storage0, storage1, total_in, total_out, ledger_residual, solver_mass
    real(real64) :: head_snapshot(numnod), water_snapshot(numnod), top_snapshot, bottom_snapshot, mass_snapshot
    integer :: nonlinear_before, jacobian_before, linear_before, backtracking_before, retries_before, status_snapshot
    integer :: i

    call configure_parameters(parameters, cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, step_dt)

    heads = h0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)) .and. &
         all(ieee_is_finite(capacity)), 'finite base constitutive state')
    call require(all(conductivity > 0.0_real64) .and. all(capacity > 0.0_real64), &
         'positive base conductivity and capacity')

    drainage = 0.0_real64
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    no_root = 0.0_real64
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, no_root)
    call bind_b110_root_sink_provider(root_provider, root_sink)

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
    request%boundary%bottom_mode = 7
    request%boundary%top_flux = -0.24_real64
    request%boundary%top_head = heads(1)
    request%boundary%bottom_flux = -conductivity(numnod)
    request%boundary%bottom_head = 777777.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 40
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-12_real64
    request%numerical%compartment_balance_tolerance = hard_mass_gate
    request%numerical%total_balance_tolerance = hard_mass_gate
    request%numerical%head_abs_tolerance = hard_mass_gate
    request%numerical%head_rel_tolerance = hard_mass_gate
    request%numerical%ponding_tolerance = hard_mass_gate
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%root_sink => root_provider
    request%evaluation%top_boundary => top_provider

    call solver%solve(request,workspace,result)
    call require(all(ieee_is_finite(workspace%richards%residual)), 'finite retained equation residual')
    call require(all(request%base_state%pressure_head==heads),'base heads immutable')
    call require(all(request%base_state%water_content==water),'base water immutable')
    if(result%status==SW_SOLVE_CONVERGED) then
      call require(maxval(abs(workspace%richards%residual))<=hard_mass_gate,'native compartment balance gate')
      storage0=sum(water*parameters%dz)
      storage1=sum(result%candidate_state%water_content*parameters%dz)
      ledger_residual=storage1-storage0+step_dt*(result%top_flux-result%bottom_flux)
      call require(abs(ledger_residual)<=hard_mass_gate,'independent rounded-state ledger gate')
      accepted=accepted+1
    else
      rejected=rejected+1
    end if
    write(*,'(a,es13.5,a,i0,a,es13.5,a,es13.5,a,l1,a,l1)') &
         'SMALL_DT dt=',step_dt,':status=',result%status, &
         ':max_rate_residual=',maxval(abs(workspace%richards%residual)), &
         ':max_storage_ulp_rate=',maxval(spacing(water)*parameters%dz/step_dt), &
         ':balance_rejected=',any(workspace%richards%nonconverged_balance), &
         ':head_rejected=',any(workspace%richards%nonconverged_head)
  end subroutine
  subroutine configure_parameters(parameters, cofgen)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    real(real64), intent(out) :: cofgen(24,numnod)
    integer :: i

    parameters%parameter_set_id = 380038_int64
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
      write(*,'(A,1X,A)') 'FREE_DRAINAGE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_free_drainage_small_dt
