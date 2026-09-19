program test_hydro_memory_acc01_f1_temporal_feasibility
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: ROOT_TOTAL = 2.0e-2_real64
  real(real64), parameter :: MASS_TOL = 1.0e-12_real64
  real(real64), parameter :: H_TEMPORAL_CM = 1.0e-1_real64
  real(real64), parameter :: INTERVAL_DAY = 1.0e-1_real64
  integer(int64), parameter :: COLUMN_ID = 592001_int64

  type(fmr_b110_physical_parameters_t) :: base_parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: temporal_committed
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(kernel_result_t) :: root_result, generic_result
  type(kernel_candidate_state_t) :: root_candidate, generic_candidate
  type(kernel_diagnostics_t) :: root_diag, generic_diag
  type(fmr_serialized_physical_observation_t) :: root_obs, generic_obs
  real(real64) :: qref, max_head_diff, max_theta_diff, max_state_change
  real(real64) :: previous_derivative(numnod)

  call initialize_parameters(base_parameters)
  call initialize_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, base_parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, INTERVAL_DAY)
  call derive_equilibrium_flux(constitutive, qref)
  previous_derivative = 0.0_real64
  call initialize_temporal_committed_state(temporal_committed, previous_derivative)

  call run_case(.true., root_result, root_candidate, root_diag, root_obs)
  call run_case(.false., generic_result, generic_candidate, generic_diag, generic_obs)

  call require(root_result%status == CANONICAL_STATUS_COMPLETED .and. root_result%completed, &
       'ROOT did not complete governed interval')
  call require(generic_result%status == CANONICAL_STATUS_COMPLETED .and. generic_result%completed, &
       'GENERIC did not complete governed interval')
  call require(root_candidate%ready() .and. generic_candidate%ready(), 'candidate not ready')
  call require(close_real(root_result%completed_t, INTERVAL_DAY) .and. &
       close_real(generic_result%completed_t, INTERVAL_DAY), 'requested interval not covered')

  call require(root_result%mass%complete .and. generic_result%mass%complete, 'hard mass ledger incomplete')
  call require(abs(root_result%mass%residual) <= MASS_TOL, 'ROOT hard mass residual')
  call require(abs(generic_result%mass%residual) <= MASS_TOL, 'GENERIC hard mass residual')
  call require(root_diag%max_abs_step_mass_residual <= MASS_TOL, 'ROOT step mass residual')
  call require(generic_diag%max_abs_step_mass_residual <= MASS_TOL, 'GENERIC step mass residual')

  call require(root_diag%temporal_certificate_unavailable_rejections == 0, 'ROOT certificate unavailable')
  call require(generic_diag%temporal_certificate_unavailable_rejections == 0, 'GENERIC certificate unavailable')
  call require(root_diag%max_temporal_indicator <= 1.0_real64 + 64.0_real64*epsilon(1.0_real64), &
       'ROOT accepted temporal indicator exceeds governed budget')
  call require(generic_diag%max_temporal_indicator <= 1.0_real64 + 64.0_real64*epsilon(1.0_real64), &
       'GENERIC accepted temporal indicator exceeds governed budget')
  call require(root_diag%accepted_substeps > 0 .and. generic_diag%accepted_substeps > 0, &
       'no accepted substeps')

  call require(root_obs%temporal_certificate_available, 'ROOT final temporal certificate unavailable')
  call require(generic_obs%temporal_certificate_available, 'GENERIC final temporal certificate unavailable')
  call require(trim(root_obs%temporal_indicator_route) == 'reference-richards-raw-bound', &
       'ROOT final temporal route drift')
  call require(trim(generic_obs%temporal_indicator_route) == 'reference-richards-raw-bound', &
       'GENERIC final temporal route drift')

  call compare_candidate_states(root_candidate, generic_candidate, max_head_diff, max_theta_diff, max_state_change)
  call require(max_head_diff <= 64.0_real64*epsilon(1.0_real64)*max(1.0_real64, abs(H0_CM)), &
       'ROOT/GENERIC final pressure-head divergence')
  call require(max_theta_diff <= 64.0_real64*epsilon(1.0_real64), &
       'ROOT/GENERIC final water-content divergence')
  call require(max_state_change > 1024.0_real64*epsilon(1.0_real64)*max(1.0_real64, abs(H0_CM)), &
       'accepted state did not change from equilibrium')

  call require(root_diag%retries == generic_diag%retries, 'ROOT/GENERIC retry-count divergence')
  call require(root_diag%solver_rejections == generic_diag%solver_rejections, &
       'ROOT/GENERIC solver-rejection divergence')
  call require(root_diag%temporal_rejections == generic_diag%temporal_rejections, &
       'ROOT/GENERIC temporal-rejection divergence')
  call require(root_diag%accepted_substeps == generic_diag%accepted_substeps, &
       'ROOT/GENERIC accepted-substep divergence')

  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_QREF=', qref
  write(*,'(a,i0)') 'HYDRO_MEMORY_ACC01_F1_ROOT_ACCEPTED_SUBSTEPS=', root_diag%accepted_substeps
  write(*,'(a,i0)') 'HYDRO_MEMORY_ACC01_F1_ROOT_RETRIES=', root_diag%retries
  write(*,'(a,i0)') 'HYDRO_MEMORY_ACC01_F1_ROOT_SOLVER_REJECTIONS=', root_diag%solver_rejections
  write(*,'(a,i0)') 'HYDRO_MEMORY_ACC01_F1_ROOT_TEMPORAL_REJECTIONS=', root_diag%temporal_rejections
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_ROOT_MAX_TEMPORAL_INDICATOR=', root_diag%max_temporal_indicator
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_ROOT_MIN_ACCEPTED_DT_DAY=', root_diag%min_accepted_substep_duration
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_ROOT_MAX_ACCEPTED_DT_DAY=', root_diag%max_accepted_substep_duration
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_MAX_HEAD_CHANGE_CM=', max_state_change
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_MAX_ROOT_GENERIC_HEAD_DIFF_CM=', max_head_diff
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_F1_MAX_ROOT_GENERIC_THETA_DIFF=', max_theta_diff
  write(*,'(a)') 'HYDRO_MEMORY_ACC01_F1_ROOT_STATE_CHANGING=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_ACC01_F1_ROOT_GENERIC_EQUIVALENCE=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_ACC01_F1_HARD_MASS=PASS'
  write(*,'(a)') 'ACC01_F1_PASS_GOVERNED_TEMPORAL_ROUTE'

contains

  subroutine run_case(root_route, result, candidate, diagnostics, obs)
    logical, intent(in) :: root_route
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(fmr_serialized_physical_observation_t), intent(out) :: obs
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
    call fmr_capture_checkpoint(temporal_committed, checkpoint, ok)
    call require(ok, 'checkpoint capture')
    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, temporal_committed, forcing, numerical, &
         0.0_real64, INTERVAL_DAY, checkpoint, result, candidate, diagnostics)
    obs = backend%observation()
  end subroutine run_case

  function numerical_config() result(cfg)
    type(canonical_numerical_config_t) :: cfg
    cfg%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = MASS_TOL
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 8
    cfg%max_committed_substeps = 32
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
    cfg%model_temporal_indicator_budget = H_TEMPORAL_CM
    cfg%accepted_trajectory_direction%requested = .false.
  end function numerical_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 592010_int64
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

    t%template_id = 592020_int64
    t%physics_topology_id = 592021_int64
    t%vertical_layout_id = 592022_int64
    t%state_layout_id = 592023_int64
    t%solver_interface_id = 592024_int64
    t%optional_state_layout_id = 0_int64
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
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
    call require(ok, 'temporal committed state initialization')
  end subroutine initialize_temporal_committed_state

  subroutine compare_candidate_states(a, b, max_head_diff, max_theta_diff, max_state_change)
    type(kernel_candidate_state_t), intent(in) :: a, b
    real(real64), intent(out) :: max_head_diff, max_theta_diff, max_state_change
    class(transaction_state_t), allocatable :: sa, sb
    logical :: oka, okb

    max_head_diff = huge(0.0_real64)
    max_theta_diff = huge(0.0_real64)
    max_state_change = 0.0_real64
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
        max_state_change = maxval(abs(ta%pressure_head - H0_CM))
      class default
        call require(.false., 'GENERIC candidate state type')
      end select
    class default
      call require(.false., 'ROOT candidate state type')
    end select
  end subroutine compare_candidate_states

  pure logical function close_real(a, b) result(close)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    close = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function close_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'HYDRO_MEMORY_ACC01_F1_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_hydro_memory_acc01_f1_temporal_feasibility
