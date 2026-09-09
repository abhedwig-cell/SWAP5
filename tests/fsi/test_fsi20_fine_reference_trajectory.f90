program test_fsi20_fine_reference_trajectory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: base_dt = 0.25_real64
  real(real64), parameter :: initial_head_cm = -75.0_real64
  real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: nonlinear_tolerance = 1.0e-14_real64
  integer, parameter :: nlevels = 7
  integer, parameter :: nref_coarse = 128
  integer, parameter :: nref_fine = 256

  type endpoint_t
    real(real64), allocatable :: h(:)
    real(real64), allocatable :: theta(:)
    real(real64) :: pond = 0.0_real64
    real(real64) :: gwl = 0.0_real64
  end type endpoint_t

  type(endpoint_t) :: local_half(nlevels), ref128(nlevels), ref256(nlevels)
  real(real64) :: dt_values(nlevels)
  real(real64) :: err_h, err_theta, err_storage, ref_h, ref_theta, ref_storage
  integer :: k, i

  do k = 1, nlevels
    dt_values(k) = base_dt / real(2**(k-1), real64)
    call run_single_transaction(dt_values(k), 3000000_int64 + int(k,int64), local_half(k))
  end do

  call run_reference_trajectory(nref_coarse, 3100000_int64, dt_values, ref128)
  call run_reference_trajectory(nref_fine, 3200000_int64, dt_values, ref256)

  do k = 1, nlevels
    err_h = maxval(abs(local_half(k)%h-ref256(k)%h))
    err_theta = maxval(abs(local_half(k)%theta-ref256(k)%theta))
    err_storage = sum(dz*(local_half(k)%theta-ref256(k)%theta))
    ref_h = maxval(abs(ref128(k)%h-ref256(k)%h))
    ref_theta = maxval(abs(ref128(k)%theta-ref256(k)%theta))
    ref_storage = sum(dz*(ref128(k)%theta-ref256(k)%theta))
    write(*,'(A,1X,ES26.17E3,6(1X,ES26.17E3))') 'FSI20_FINE_REFERENCE_SUMMARY', dt_values(k), &
         err_h, err_theta, err_storage, ref_h, ref_theta, ref_storage
    do i = 1, numnod
      write(*,'(A,1X,ES26.17E3,1X,I0,4(1X,ES26.17E3))') 'FSI20_FINE_REFERENCE_NODE', dt_values(k), i, &
           local_half(k)%h(i)-ref256(k)%h(i), local_half(k)%theta(i)-ref256(k)%theta(i), &
           ref128(k)%h(i)-ref256(k)%h(i), ref128(k)%theta(i)-ref256(k)%theta(i)
    end do
  end do

  write(*,'(A)') 'FSI20_FINE_REFERENCE_TRAJECTORY_DRIVER PASS'

contains

  subroutine run_single_transaction(step_dt, lineage, endpoint)
    real(real64), intent(in) :: step_dt
    integer(int64), intent(in) :: lineage
    type(endpoint_t), intent(out) :: endpoint
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: conductivity0
    logical :: ok

    call configure_column(column, template, lineage)
    call configure_case(parameters, initial_state, forcing, conductivity0)
    call configure_reference_policy(config)
    call fmr_new_b110_committed_state(committed, lineage, initial_state, t0, ok)
    call require(ok, 'single transaction committed initialization')
    call backend%initialize(top_provider)
    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok, 'single transaction checkpoint')
    call poison_legacy_bottom_context()
    call backend%run_trial(column, template, parameters, committed, forcing, config, &
         t0, t0+step_dt, checkpoint, result, candidate, diagnostics)
    call require(result%completed .and. candidate%ready(), 'single transaction candidate')
    call require(result%mass%complete, 'single transaction mass complete')
    call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'single transaction mass mask')
    call require(abs(result%mass%residual) <= hard_mass_gate, 'single transaction hard mass')
    call require(diagnostics%solver_rejections == 0 .and. diagnostics%mass_rejections == 0, &
         'single transaction no solver or mass rejection')
    call snapshot_candidate(candidate, endpoint)
    call require(committed%current_revision() == 0_int64, 'single transaction remains uncommitted')
  end subroutine run_single_transaction

  subroutine run_reference_trajectory(nsegments, lineage, targets, endpoints)
    integer, intent(in) :: nsegments
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: targets(:)
    type(endpoint_t), intent(out) :: endpoints(:)
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(kernel_executor_t) :: commit_executor
    real(real64) :: conductivity0, segment_dt, ta, tb
    integer :: j, target_index, commit_status
    logical :: ok, did_commit

    call require(size(targets) == size(endpoints), 'reference target shape')
    call configure_column(column, template, lineage)
    call configure_case(parameters, initial_state, forcing, conductivity0)
    call configure_reference_policy(config)
    call fmr_new_b110_committed_state(committed, lineage, initial_state, t0, ok)
    call require(ok, 'reference committed initialization')
    call backend%initialize(top_provider)
    segment_dt = base_dt / real(nsegments,real64)

    do j = 1, nsegments
      ta = t0 + real(j-1,real64)*segment_dt
      tb = t0 + real(j,real64)*segment_dt
      call fmr_capture_checkpoint(committed, checkpoint, ok)
      call require(ok, 'reference checkpoint')
      call poison_legacy_bottom_context()
      call backend%run_trial(column, template, parameters, committed, forcing, config, &
           ta, tb, checkpoint, result, candidate, diagnostics)
      call require(result%completed .and. candidate%ready(), 'reference candidate')
      call require(result%mass%complete, 'reference mass complete')
      call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'reference mass mask')
      call require(abs(result%mass%residual) <= hard_mass_gate, 'reference hard mass')
      call require(diagnostics%solver_rejections == 0 .and. diagnostics%mass_rejections == 0, &
           'reference no solver or mass rejection')
      call fmr_commit_candidate(commit_executor, committed, candidate, diagnostics, did_commit, commit_status)
      call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'reference commit')
      do target_index = 1, size(targets)
        if (j == nint(targets(target_index)/segment_dt)) then
          call snapshot_committed(committed, endpoints(target_index))
        end if
      end do
    end do
    call require(committed%current_revision() == int(nsegments,int64), 'reference revision count')
    do target_index = 1, size(endpoints)
      call require(allocated(endpoints(target_index)%h), 'reference endpoint captured')
    end do
  end subroutine run_reference_trajectory

  subroutine snapshot_candidate(candidate, endpoint)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(endpoint_t), intent(out) :: endpoint
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call candidate%snapshot(snapshot, available)
    call require(available, 'candidate snapshot available')
    call copy_physical_snapshot(snapshot, endpoint)
  end subroutine snapshot_candidate

  subroutine snapshot_committed(committed, endpoint)
    type(kernel_committed_state_t), intent(in) :: committed
    type(endpoint_t), intent(out) :: endpoint
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot, available)
    call require(available, 'committed snapshot available')
    call copy_physical_snapshot(snapshot, endpoint)
  end subroutine snapshot_committed

  subroutine copy_physical_snapshot(snapshot, endpoint)
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    type(endpoint_t), intent(out) :: endpoint
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      allocate(endpoint%h(physical%active_nodes), endpoint%theta(physical%active_nodes))
      endpoint%h = physical%pressure_head
      endpoint%theta = physical%water_content
      endpoint%pond = physical%ponding_depth
      endpoint%gwl = physical%groundwater_level
    class default
      call require(.false., 'unexpected snapshot type')
    end select
  end subroutine copy_physical_snapshot

  subroutine configure_column(c, templ, lineage)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: templ
    integer(int64), intent(in) :: lineage
    templ%template_id = 2020_int64
    templ%physics_topology_id = 202001_int64
    templ%vertical_layout_id = 202002_int64
    templ%state_layout_id = 202003_int64
    templ%solver_interface_id = 202004_int64
    templ%optional_state_layout_id = 202005_int64
    templ%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = lineage
    c%template_id = templ%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_case(p, state, forcing, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), conductivity(numnod), water(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 202001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = nonlinear_tolerance
    p%head_rel_tolerance = nonlinear_tolerance
    p%ponding_tolerance = nonlinear_tolerance

    heads = initial_head_cm
    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, base_dt)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity_reference = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity_reference
    forcing%top_head = initial_head_cm
    forcing%bottom_flux = 12345.678_real64
    forcing%bottom_head = predictor_bottom_head_cm
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine configure_case

  subroutine configure_reference_policy(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = huge(1.0_real64)
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 0
    cfg%max_committed_substeps = 1
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_reference_policy

  subroutine poison_legacy_bottom_context()
    swmacro = 0
    legacy_melt = 0.0_real64
    legacy_qdra = 24680.0_real64
    legacy_qssdi = -13579.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 99999.0_real64
    legacy_qbot = -99999.0_real64
  end subroutine poison_legacy_bottom_context

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FSI20_FINE_REFERENCE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fsi20_fine_reference_trajectory
