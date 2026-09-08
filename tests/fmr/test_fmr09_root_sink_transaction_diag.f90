program test_fmr09_root_sink_transaction_diag
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 2100.375_real64, t1 = 2100.875_real64, head0 = -75.0_real64
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters, inactive_parameters
  type(fmr_b110_physical_forcing_t) :: forcing, forcing_b, inactive_forcing, negative_forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result, result_b, replay_result
  type(kernel_candidate_state_t) :: candidate, candidate_b, replay_candidate
  type(kernel_diagnostics_t) :: diag, diag_b, replay_diag
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_serialized_physical_observation_t) :: obs
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: snapshot_a, snapshot_replay
  real(real64) :: conductivity0
  integer(int64) :: revision0
  integer :: i
  logical :: ok

  call configure_parameters(parameters, initial_state, conductivity0)
  parameters%root_extraction_active = .true.
  call configure_column(column, template)
  call configure_forcing(forcing, conductivity0)
  ! Heterogeneous precomputed qrot while preserving the already allocated numnod shape.
  do i = 1, numnod
    forcing%root_extraction_sink(i) = 0.01_real64 * real(i, real64)
  end do
  forcing%subsurface_irrigation_source = forcing%root_extraction_sink
  if (maxval(forcing%root_extraction_sink) <= minval(forcing%root_extraction_sink)) &
       error stop 'FMR09_DIAG root fixture is not heterogeneous'
  call configure_transaction(config)
  call fmr_new_b110_committed_state(committed, column%column_id, initial_state, t0, ok)
  if (.not. ok) error stop 'FMR09_DIAG committed init'
  call committed%capture_checkpoint(checkpoint, ok)
  if (.not. ok) error stop 'FMR09_DIAG checkpoint'
  revision0 = committed%current_revision()

  ! A1: positive heterogeneous route with poisoned legacy globals. The explicit
  ! provider must be authoritative and the first transaction must complete.
  call reset_globals()
  call backend%initialize(top_provider)
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       result, candidate, diag)
  obs = backend%observation()

  write(*,'(A,1X,I0,1X,L1,1X,ES24.16)') 'FMR09_DIAG_RESULT=', result%status, result%completed, result%completed_t
  write(*,'(A,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0)') 'FMR09_DIAG_TX=', diag%transaction_calls, &
       diag%attempts, diag%retries, diag%solver_rejections, diag%temporal_rejections, diag%mass_rejections
  write(*,'(A,1X,ES24.16)') 'FMR09_DIAG_MAX_MASS_RESIDUAL=', diag%max_abs_step_mass_residual
  write(*,'(A,1X,L1,1X,I0,1X,A,1X,I0)') 'FMR09_DIAG_OBS=', obs%solver_executed, obs%solver_status, &
       trim(obs%solver_diagnostics%route), obs%solver_diagnostics%nonlinear_iterations
  if (.not. result%completed .or. diag%solver_rejections /= 0 .or. .not. obs%solver_executed) &
       error stop 'FMR09_DIAG positive explicit root route failed'
  if (.not. candidate%ready()) error stop 'FMR09_DIAG A1 candidate not ready'
  call candidate%snapshot(snapshot_a, ok)
  if (.not. ok) error stop 'FMR09_DIAG A1 snapshot unavailable'
  write(*,'(A)') 'FMR09_HETEROGENEOUS_ROOT_ROUTE=PASS'
  write(*,'(A)') 'FMR09_EXPLICIT_ROOT_LEGACY_QROT_POISON_IMMUNITY=PASS'

  ! Discard A1 and prove the externally committed revision is untouched.
  call fmr_discard_candidate(transaction_control, candidate, diag)
  if (candidate%ready() .or. committed%current_revision() /= revision0) &
       error stop 'FMR09_DIAG root rollback mutated committed state'
  write(*,'(A)') 'FMR09_ROOT_ROLLBACK=PASS'

  ! B: a distinct heterogeneous balanced root/source pattern. It must execute
  ! successfully but have a different authoritative water amount from A.
  forcing_b = forcing
  do i = 1, numnod
    forcing_b%root_extraction_sink(i) = 0.02_real64 * real(i, real64)
  end do
  forcing_b%subsurface_irrigation_source = forcing_b%root_extraction_sink
  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, forcing_b, config, t0, t1, checkpoint, &
       result_b, candidate_b, diag_b)
  if (.not. result_b%completed .or. .not. candidate_b%ready()) error stop 'FMR09_DIAG B trial failed'
  if (same_bits(result_b%mass%total_out, result%mass%total_out)) error stop 'FMR09_DIAG B not distinct from A'
  call fmr_discard_candidate(transaction_control, candidate_b, diag_b)
  if (committed%current_revision() /= revision0) error stop 'FMR09_DIAG B mutated committed state'

  ! A2: exact replay from the original checkpoint after B. Candidate and
  ! authoritative mass must reproduce A1 bitwise.
  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       replay_result, replay_candidate, replay_diag)
  if (.not. replay_result%completed .or. .not. replay_candidate%ready()) error stop 'FMR09_DIAG A2 replay failed'
  call replay_candidate%snapshot(snapshot_replay, ok)
  if (.not. ok) error stop 'FMR09_DIAG A2 snapshot unavailable'
  if (.not. physical_snapshot_identical(snapshot_a, snapshot_replay)) &
       error stop 'FMR09_DIAG A1/A2 candidate mismatch'
  if (.not. result_mass_identical(result, replay_result)) error stop 'FMR09_DIAG A1/A2 mass mismatch'
  call fmr_discard_candidate(transaction_control, replay_candidate, replay_diag)
  if (committed%current_revision() /= revision0) error stop 'FMR09_DIAG replay mutated committed state'
  write(*,'(A)') 'FMR09_ROOT_REPLAY_BITWISE=PASS'
  write(*,'(A)') 'FMR09_ROOT_A_B_A=PASS'

  ! Fail closed if nonzero root forcing is supplied while the physical option is inactive.
  inactive_parameters = parameters
  inactive_parameters%root_extraction_active = .false.
  inactive_forcing = forcing
  inactive_forcing%root_extraction_sink = 0.01_real64
  inactive_forcing%subsurface_irrigation_source = 0.0_real64
  call reset_globals()
  call backend%run_trial(column, template, inactive_parameters, committed, inactive_forcing, config, t0, t1, checkpoint, &
       result, candidate, diag)
  obs = backend%observation()
  if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED .or. result%completed .or. &
      diag%solver_rejections /= 1 .or. obs%solver_executed) &
       error stop 'FMR09_DIAG inactive nonzero root did not fail closed'
  write(*,'(A)') 'FMR09_INACTIVE_NONZERO_ROOT_FAIL_CLOSED=PASS'

  ! The admitted root-extraction sign convention is nonnegative extraction.
  negative_forcing = forcing
  negative_forcing%root_extraction_sink = -0.01_real64
  negative_forcing%subsurface_irrigation_source = 0.0_real64
  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, negative_forcing, config, t0, t1, checkpoint, &
       result, candidate, diag)
  obs = backend%observation()
  if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED .or. result%completed .or. &
      diag%solver_rejections /= 1 .or. obs%solver_executed) &
       error stop 'FMR09_DIAG negative root did not fail closed'
  write(*,'(A)') 'FMR09_NEGATIVE_ROOT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR09_ROOT_TRANSACTION_DIAGNOSTIC COMPLETE'

contains

  subroutine configure_column(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=909_int64; t%physics_topology_id=90901_int64; t%vertical_layout_id=90902_int64
    t%state_layout_id=90903_int64; t%solver_interface_id=90904_int64; t%optional_state_layout_id=90905_int64
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=909001_int64; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k
    p%parameter_set_id=90901_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux=-k0; f%top_head=head0; f%bottom_flux=-k0; f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine configure_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64; cfg%transaction%mass_tolerance=1.0e-12_real64
    cfg%transaction%retry_scale=0.5_real64; cfg%transaction%max_retries=0
    cfg%max_committed_substeps=8; cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64; legacy_qrot=-99999.0_real64
    swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_globals

  logical function physical_snapshot_identical(a,b) result(equal)
    class(transaction_state_t), intent(in) :: a,b
    integer :: k
    equal = .false.
    select type (pa => a)
    type is (fmr_b110_physical_state_t)
      select type (pb => b)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head) .or. size(pa%water_content) /= size(pb%water_content)) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        equal = .true.
      end select
    end select
  end function physical_snapshot_identical

  logical function result_mass_identical(a,b) result(equal)
    type(kernel_result_t), intent(in) :: a,b
    equal = a%status == b%status .and. a%completed .eqv. b%completed .and. &
         a%mass%complete .eqv. b%mass%complete .and. &
         a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
         same_bits(a%mass%storage_start,b%mass%storage_start) .and. &
         same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change,b%mass%storage_change) .and. &
         same_bits(a%mass%total_in,b%mass%total_in) .and. &
         same_bits(a%mass%total_out,b%mass%total_out) .and. &
         same_bits(a%mass%residual,b%mass%residual)
  end function result_mass_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits
end program test_fmr09_root_sink_transaction_diag
