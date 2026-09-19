program test_ppa_root_hyd01_sink_equivalence
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: ROOT_TOTAL = 2.0e-2_real64
  real(real64), parameter :: MASS_TOL = 1.0e-12_real64
  real(real64), parameter :: DURATIONS(5) = [1.0e-4_real64, 1.0e-3_real64, 1.0e-2_real64, 1.0e-1_real64, 1.0_real64]
  integer(int64), parameter :: COLUMN_ID = 591001_int64

  type(fmr_b110_physical_parameters_t) :: base_parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  real(real64) :: qref
  integer :: i

  call initialize_parameters(base_parameters)
  call initialize_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, base_parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, 1.0_real64)
  call derive_equilibrium_flux(constitutive, qref)
  call initialize_committed_state(committed, constitutive)

  write(*,'(a,es24.16)') 'PPA_ROOT_HYD01_QREF=', qref
  do i = 1, size(DURATIONS)
    call compare_routes(DURATIONS(i))
  end do
  write(*,'(a)') 'PPA_ROOT_HYD01_D1_SWEEP_COMPLETE=PASS'
  call diagnose_model_certificate_routes()
  write(*,'(a)') 'PPA_ROOT_HYD01_D2_TEMPORAL_DIAG_COMPLETE=PASS'

contains

  subroutine diagnose_model_certificate_routes()
    type(kernel_result_t) :: root_result, generic_result
    type(kernel_candidate_state_t) :: root_candidate, generic_candidate
    type(kernel_diagnostics_t) :: root_diag, generic_diag
    type(fmr_serialized_physical_observation_t) :: root_obs, generic_obs

    call run_certificate_case(.true., root_result, root_candidate, root_diag, root_obs)
    call run_certificate_case(.false., generic_result, generic_candidate, generic_diag, generic_obs)

    write(*,'(a,l1,a,i0,a,i0,a,a,a,l1,a,es24.16,a,a)') &
         'PPA_ROOT_HYD01_D2_ROOT completed=', root_result%completed, ' status=', root_result%status, &
         ' certificate_unavailable_rejections=', root_diag%temporal_certificate_unavailable_rejections, &
         ' indicator_route=', trim(root_obs%temporal_indicator_route), ' cert_available=', &
         root_obs%temporal_certificate_available, ' normalized_indicator=', root_obs%temporal_normalized_indicator, &
         ' reason=', trim(root_obs%temporal_certificate_unavailable_reason)

    write(*,'(a,l1,a,i0,a,i0,a,a,a,l1,a,es24.16,a,a)') &
         'PPA_ROOT_HYD01_D2_GENERIC completed=', generic_result%completed, ' status=', generic_result%status, &
         ' certificate_unavailable_rejections=', generic_diag%temporal_certificate_unavailable_rejections, &
         ' indicator_route=', trim(generic_obs%temporal_indicator_route), ' cert_available=', &
         generic_obs%temporal_certificate_available, ' normalized_indicator=', generic_obs%temporal_normalized_indicator, &
         ' reason=', trim(generic_obs%temporal_certificate_unavailable_reason)

    call require(trim(root_obs%temporal_indicator_route) == 'root-sink-envelope-deferred', &
         'D2 root route did not expose root-sink-envelope-deferred')
    call require(.not. root_obs%temporal_certificate_available, 'D2 root certificate unexpectedly available')
    call require(trim(generic_obs%temporal_indicator_route) /= 'root-sink-envelope-deferred', &
         'D2 generic route incorrectly hit root-sink policy')
  end subroutine diagnose_model_certificate_routes

  subroutine run_certificate_case(root_route, result, candidate, diagnostics, obs)
    logical, intent(in) :: root_route
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(fmr_serialized_physical_observation_t), intent(out) :: obs
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_committed_state_t) :: temporal_committed
    type(kernel_checkpoint_t) :: checkpoint
    type(canonical_numerical_config_t) :: numerical
    type(fmr_template_t) :: temporal_template
    real(real64) :: previous_derivative(numnod)
    integer :: rooted
    logical :: ok

    parameters = base_parameters
    parameters%root_extraction_active = root_route
    call initialize_forcing(forcing, qref)
    rooted = min(4, numnod)
    if (root_route) then
      forcing%root_extraction_sink(1:rooted) = ROOT_TOTAL / real(rooted, real64)
    else
      forcing%drainage_flux_by_level(1,1:rooted) = ROOT_TOTAL / real(rooted, real64)
    end if

    temporal_template = template
    temporal_template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    previous_derivative = 0.0_real64
    call initialize_temporal_committed_state(temporal_committed, previous_derivative)

    numerical = numerical_config()
    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%max_retries = 0
    numerical%model_temporal_indicator_budget_available = .true.
    numerical%model_temporal_indicator_budget = 1.0e-5_real64

    call fmr_capture_checkpoint(temporal_committed, checkpoint, ok)
    call require(ok, 'D2 temporal checkpoint capture')
    call backend%initialize(top)
    call backend%run_trial(column, temporal_template, parameters, temporal_committed, forcing, numerical, &
         0.0_real64, 1.0e-1_real64, checkpoint, result, candidate, diagnostics)
    obs = backend%observation()
  end subroutine run_certificate_case

  subroutine initialize_temporal_committed_state(state, previous_derivative)
    type(kernel_committed_state_t), intent(out) :: state
    real(real64), intent(in) :: previous_derivative(:)
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok

    heads = H0_CM
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state, COLUMN_ID, physical, 0.0_real64, ok, previous_derivative)
    call require(ok, 'D2 temporal committed state initialization')
  end subroutine initialize_temporal_committed_state

  subroutine compare_routes(duration)
    real(real64), intent(in) :: duration
    type(kernel_result_t) :: root_result, generic_result
    type(kernel_candidate_state_t) :: root_candidate, generic_candidate
    type(kernel_diagnostics_t) :: root_diag, generic_diag
    real(real64) :: head_diff, theta_diff
    logical :: states_compared

    call run_case(duration, .true., root_result, root_candidate, root_diag)
    call run_case(duration, .false., generic_result, generic_candidate, generic_diag)

    write(*,'(a,es12.4,a,l1,a,i0,a,i0,a,i0,a,i0,a,i0)') 'PPA_ROOT_HYD01_ROOT duration=', duration, &
         ' completed=', root_result%completed, ' status=', root_result%status, ' retries=', root_diag%retries, &
         ' solver_rejections=', root_diag%solver_rejections, ' temporal_rejections=', root_diag%temporal_rejections, &
         ' mass_rejections=', root_diag%mass_rejections
    write(*,'(a,es12.4,a,l1,a,i0,a,i0,a,i0,a,i0,a,i0)') 'PPA_ROOT_HYD01_GENERIC duration=', duration, &
         ' completed=', generic_result%completed, ' status=', generic_result%status, ' retries=', generic_diag%retries, &
         ' solver_rejections=', generic_diag%solver_rejections, ' temporal_rejections=', generic_diag%temporal_rejections, &
         ' mass_rejections=', generic_diag%mass_rejections

    states_compared = .false.
    head_diff = 0.0_real64
    theta_diff = 0.0_real64
    if (root_result%completed .and. generic_result%completed .and. root_candidate%ready() .and. generic_candidate%ready()) then
      call compare_candidate_states(root_candidate, generic_candidate, head_diff, theta_diff)
      states_compared = .true.
      call require(root_result%mass%complete .and. generic_result%mass%complete, 'completed route mass incomplete')
      call require(abs(root_result%mass%residual) <= MASS_TOL, 'root route hard mass')
      call require(abs(generic_result%mass%residual) <= MASS_TOL, 'generic route hard mass')
    end if
    write(*,'(a,es12.4,a,l1,a,es24.16,a,es24.16)') 'PPA_ROOT_HYD01_PAIR duration=', duration, &
         ' states_compared=', states_compared, ' max_head_diff=', head_diff, ' max_theta_diff=', theta_diff
  end subroutine compare_routes

  subroutine run_case(duration, root_route, result, candidate, diagnostics)
    real(real64), intent(in) :: duration
    logical, intent(in) :: root_route
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_checkpoint_t) :: checkpoint
    type(canonical_numerical_config_t) :: numerical
    integer :: rooted
    logical :: ok

    parameters = base_parameters
    parameters%root_extraction_active = root_route
    call initialize_forcing(forcing, qref)
    rooted = min(4, numnod)
    if (root_route) then
      forcing%root_extraction_sink(1:rooted) = ROOT_TOTAL / real(rooted, real64)
    else
      forcing%drainage_flux_by_level(1,1:rooted) = ROOT_TOTAL / real(rooted, real64)
    end if

    numerical = numerical_config()
    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok, 'checkpoint capture')
    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, committed, forcing, numerical, 0.0_real64, duration, &
         checkpoint, result, candidate, diagnostics)
    call require(ieee_is_finite(result%completed_t), 'nonfinite completed time')
  end subroutine run_case

  function numerical_config() result(cfg)
    type(canonical_numerical_config_t) :: cfg
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = 1.0e-6_real64
    cfg%transaction%mass_tolerance = MASS_TOL
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 8
    cfg%max_committed_substeps = 32
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .false.
    cfg%model_temporal_indicator_budget = 0.0_real64
    cfg%accepted_trajectory_direction%requested = .false.
  end function numerical_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 591010_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = MASS_TOL
    p%total_balance_tolerance = MASS_TOL
    p%head_abs_tolerance = MASS_TOL
    p%head_rel_tolerance = MASS_TOL
    p%ponding_tolerance = MASS_TOL
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f, flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: flux

    f%top_flux = flux
    f%top_head = H0_CM
    f%bottom_flux = flux
    f%bottom_head = H0_CM
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t

    t%template_id = 591020_int64
    t%physics_topology_id = 591021_int64
    t%vertical_layout_id = 591022_int64
    t%state_layout_id = 591023_int64
    t%solver_interface_id = 591024_int64
    t%optional_state_layout_id = 0_int64
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = COLUMN_ID
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine derive_equilibrium_flux(provider, flux)
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(out) :: flux
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = H0_CM
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    flux = -conductivity(1)
    call require(ieee_is_finite(flux), 'equilibrium flux finite')
  end subroutine derive_equilibrium_flux

  subroutine initialize_committed_state(state, provider)
    type(kernel_committed_state_t), intent(out) :: state
    type(b110_default_mvg_provider_t), intent(in) :: provider
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok

    heads = H0_CM
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(state, COLUMN_ID, physical, 0.0_real64, ok)
    call require(ok, 'committed state initialization')
  end subroutine initialize_committed_state

  subroutine compare_candidate_states(a, b, max_head_diff, max_theta_diff)
    type(kernel_candidate_state_t), intent(in) :: a, b
    real(real64), intent(out) :: max_head_diff, max_theta_diff
    class(transaction_state_t), allocatable :: sa, sb
    logical :: oka, okb

    max_head_diff = huge(0.0_real64)
    max_theta_diff = huge(0.0_real64)
    call a%snapshot(sa, oka)
    call b%snapshot(sb, okb)
    call require(oka .and. okb .and. allocated(sa) .and. allocated(sb), 'candidate snapshots')
    select type (ta => sa)
    class is (fmr_b110_physical_state_t)
      select type (tb => sb)
      class is (fmr_b110_physical_state_t)
        call require(ta%active_nodes == tb%active_nodes, 'candidate node count')
        max_head_diff = maxval(abs(ta%pressure_head - tb%pressure_head))
        max_theta_diff = maxval(abs(ta%water_content - tb%water_content))
      class default
        call require(.false., 'generic candidate state type')
      end select
    class default
      call require(.false., 'root candidate state type')
    end select
  end subroutine compare_candidate_states

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_ROOT_HYD01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_root_hyd01_sink_equivalence
