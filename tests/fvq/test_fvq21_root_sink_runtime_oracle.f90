program test_fvq21_root_sink_runtime_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 2400.125_real64
  real(real64), parameter :: t1 = 2400.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1), column
  type(fmr_template_t) :: templates(1), template
  type(fmr_b110_physical_parameters_t) :: parameters(1), tx_parameters, inactive_parameters
  type(fmr_b110_physical_forcing_t) :: forcing_control(1), forcing_pair(1)
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b, inactive_forcing, negative_forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: state_control(1), state_pair(1), committed
  type(fmr_serialized_column_result_t), allocatable :: result_control(:), result_pair(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_control(:), diag_pair(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_control, aggregate_pair
  type(fmr_serialized_batch_diagnostics_t) :: run_control, run_pair
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: tx_result_a1, tx_result_b, tx_result_a2, reject_result
  type(kernel_candidate_state_t) :: candidate_a1, candidate_b, candidate_a2, reject_candidate
  type(kernel_diagnostics_t) :: tx_diag_a1, tx_diag_b, tx_diag_a2, reject_diag
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_serialized_physical_observation_t) :: observation
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: snapshot_a1, snapshot_a2
  real(real64) :: conductivity0, expected_amount, in_delta, out_delta, tolerance
  integer(int64) :: revision0
  integer :: dispatch_control, dispatch_pair, i
  logical :: ok

  call configure_parameters(parameters(1), initial_state, conductivity0)
  parameters(1)%root_extraction_active = .true.
  call configure_column(columns(1), templates(1))
  call configure_forcing(forcing_control(1), conductivity0)
  forcing_pair(1) = forcing_control(1)
  do i = 1, numnod
    forcing_pair(1)%root_extraction_sink(i) = 0.006_real64 + 0.003_real64*real(i,real64)
  end do
  forcing_pair(1)%subsurface_irrigation_source = forcing_pair(1)%root_extraction_sink
  expected_amount = sum(forcing_pair(1)%root_extraction_sink)*(t1-t0)
  tolerance = 512.0_real64*epsilon(1.0_real64)*max(1.0_real64,expected_amount)
  call require(maxval(forcing_pair(1)%root_extraction_sink) > minval(forcing_pair(1)%root_extraction_sink), &
       'heterogeneous nodewise root fixture')
  call configure_transaction(config)

  call fmr_new_b110_committed_state(state_control(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok,'control committed init')
  call fmr_new_b110_committed_state(state_pair(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok,'paired committed init')

  call poison_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_control, state_control, config, &
       top_provider, t0, t1, 1, result_control, diag_control, aggregate_control, dispatch_control, run_control)
  call poison_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_pair, state_pair, config, &
       top_provider, t0, t1, 1, result_pair, diag_pair, aggregate_pair, dispatch_pair, run_pair)

  call require(dispatch_control == FMR_SERIAL_DISPATCH_OK .and. dispatch_pair == FMR_SERIAL_DISPATCH_OK, &
       'serialized runtime dispatch')
  call require(result_control(1)%completed .and. result_control(1)%committed, 'control accepted')
  call require(result_pair(1)%completed .and. result_pair(1)%committed, 'paired accepted')
  call require(result_control(1)%mass%complete .and. result_pair(1)%mass%complete, 'authoritative mass complete')
  call require(result_control(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
       result_pair(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'authoritative mass mask')
  call require(abs(result_control(1)%mass%residual) <= hard_mass_gate .and. &
       abs(result_pair(1)%mass%residual) <= hard_mass_gate, 'hard mass residual')
  call require(committed_physics_identical(state_control(1),state_pair(1)), &
       'nodewise equal root sink and qssdi cancel hydraulically')

  in_delta = result_pair(1)%mass%total_in-result_control(1)%mass%total_in
  out_delta = result_pair(1)%mass%total_out-result_control(1)%mass%total_out
  call require(abs(in_delta-expected_amount) <= tolerance, 'independent qssdi total_in equation')
  call require(abs(out_delta-expected_amount) <= tolerance, 'independent qrot total_out equation')
  call require(abs(aggregate_pair%aggregate_unrounded_mass_residual) <= hard_mass_gate, 'aggregate hard mass residual')
  call require(abs(run_pair%authoritative_aggregate_mass%total_in-result_pair(1)%mass%total_in) <= tolerance, &
       'aggregate total_in exactly once')
  call require(abs(run_pair%authoritative_aggregate_mass%total_out-result_pair(1)%mass%total_out) <= tolerance, &
       'aggregate total_out exactly once')

  write(*,'(A,1X,ES24.16)') 'FVQ21_EXPECTED_ROOT_AMOUNT=', expected_amount
  write(*,'(A,1X,ES24.16)') 'FVQ21_OBSERVED_TOTAL_IN_DELTA=', in_delta
  write(*,'(A,1X,ES24.16)') 'FVQ21_OBSERVED_TOTAL_OUT_DELTA=', out_delta
  write(*,'(A)') 'FVQ21_NODEWISE_ROOT_QSSDI_HYDRAULIC_CANCELLATION=PASS'
  write(*,'(A)') 'FVQ21_ROOT_AUTHORITATIVE_TOTAL_OUT_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ21_QSSDI_AUTHORITATIVE_TOTAL_IN_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ21_HARD_MASS_CONSERVATION=PASS'

  column = columns(1)
  template = templates(1)
  tx_parameters = parameters(1)
  forcing_a = forcing_pair(1)
  forcing_b = forcing_pair(1)
  do i = 1, numnod
    forcing_b%root_extraction_sink(i) = 0.013_real64 + 0.004_real64*real(i,real64)
  end do
  forcing_b%subsurface_irrigation_source = forcing_b%root_extraction_sink

  call fmr_new_b110_committed_state(committed, column%column_id, initial_state, t0, ok)
  call require(ok,'transaction committed init')
  call committed%capture_checkpoint(checkpoint,ok)
  call require(ok,'transaction checkpoint')
  revision0 = committed%current_revision()
  call backend%initialize(top_provider)

  call poison_legacy_globals()
  call backend%run_trial(column,template,tx_parameters,committed,forcing_a,config,t0,t1,checkpoint, &
       tx_result_a1,candidate_a1,tx_diag_a1)
  call require_trial_admitted(tx_result_a1,candidate_a1,'A1')
  call candidate_a1%snapshot(snapshot_a1,ok)
  call require(ok,'A1 snapshot')
  call fmr_discard_candidate(transaction_control,candidate_a1,tx_diag_a1)
  call require(.not. candidate_a1%ready() .and. committed%current_revision()==revision0,'A1 discard rollback')

  call poison_legacy_globals()
  call backend%run_trial(column,template,tx_parameters,committed,forcing_b,config,t0,t1,checkpoint, &
       tx_result_b,candidate_b,tx_diag_b)
  call require_trial_admitted(tx_result_b,candidate_b,'B')
  call require(.not. same_bits(tx_result_b%mass%total_out,tx_result_a1%mass%total_out),'B mass distinct from A')
  call fmr_discard_candidate(transaction_control,candidate_b,tx_diag_b)
  call require(.not. candidate_b%ready() .and. committed%current_revision()==revision0,'B discard rollback')

  call poison_legacy_globals()
  call backend%run_trial(column,template,tx_parameters,committed,forcing_a,config,t0,t1,checkpoint, &
       tx_result_a2,candidate_a2,tx_diag_a2)
  call require_trial_admitted(tx_result_a2,candidate_a2,'A2')
  call candidate_a2%snapshot(snapshot_a2,ok)
  call require(ok,'A2 snapshot')
  call require(physical_snapshot_identical(snapshot_a1,snapshot_a2),'A/B/A physical candidate identity')
  call require(result_mass_identical(tx_result_a1,tx_result_a2),'A/B/A authoritative mass identity')
  call fmr_discard_candidate(transaction_control,candidate_a2,tx_diag_a2)
  call require(.not. candidate_a2%ready() .and. committed%current_revision()==revision0,'A2 discard rollback')

  write(*,'(A)') 'FVQ21_ROOT_ROLLBACK_REPLAY=PASS'
  write(*,'(A)') 'FVQ21_ROOT_A_B_A_IDENTITY=PASS'

  inactive_parameters = tx_parameters
  inactive_parameters%root_extraction_active = .false.
  inactive_forcing = forcing_a
  inactive_forcing%subsurface_irrigation_source = 0.0_real64
  call poison_legacy_globals()
  call backend%run_trial(column,template,inactive_parameters,committed,inactive_forcing,config,t0,t1,checkpoint, &
       reject_result,reject_candidate,reject_diag)
  observation = backend%observation()
  call require(reject_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. .not. reject_result%completed, &
       'inactive nonzero root rejected')
  call require(.not. observation%solver_executed,'inactive nonzero root rejected before solver')
  write(*,'(A)') 'FVQ21_INACTIVE_NONZERO_ROOT_FAIL_CLOSED=PASS'

  negative_forcing = forcing_a
  negative_forcing%root_extraction_sink = -abs(negative_forcing%root_extraction_sink)
  negative_forcing%subsurface_irrigation_source = 0.0_real64
  call poison_legacy_globals()
  call backend%run_trial(column,template,tx_parameters,committed,negative_forcing,config,t0,t1,checkpoint, &
       reject_result,reject_candidate,reject_diag)
  observation = backend%observation()
  call require(reject_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. .not. reject_result%completed, &
       'negative root rejected')
  call require(.not. observation%solver_executed,'negative root rejected before solver')
  write(*,'(A)') 'FVQ21_NEGATIVE_ROOT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ21_ROOT_SINK_RUNTIME_SCIENTIFIC_ORACLE PASS'

contains

  subroutine configure_column(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=921_int64
    t%physics_topology_id=92101_int64
    t%vertical_layout_id=92102_int64
    t%state_layout_id=92103_int64
    t%solver_interface_id=92104_int64
    t%optional_state_layout_id=92105_int64
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=921001_int64
    c%template_id=t%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k
    p%parameter_set_id=92101_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z
    p%dz=dz
    p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
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
    p%bottom_mode=7
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux=-k0
    f%top_head=head0
    f%bottom_flux=-k0
    f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine configure_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=0
    cfg%max_committed_substeps=8
    cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine poison_legacy_globals()
    legacy_qdra=12345.0_real64
    legacy_qssdi=-54321.0_real64
    legacy_qrot=-99999.0_real64
    swmacro=0
    legacy_melt=0.0_real64
  end subroutine poison_legacy_globals

  subroutine require_trial_admitted(result,candidate,label)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    character(len=*), intent(in) :: label
    call require(result%completed,trim(label)//' completed')
    call require(candidate%ready(),trim(label)//' candidate ready')
    call require(result%mass%complete,trim(label)//' mass complete')
    call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE,trim(label)//' mass mask')
    call require(abs(result%mass%residual) <= hard_mass_gate,trim(label)//' hard mass residual')
  end subroutine require_trial_admitted

  logical function committed_physics_identical(a,b) result(equal)
    type(kernel_committed_state_t), intent(in) :: a,b
    class(transaction_state_t), allocatable :: sa,sb
    logical :: oka,okb
    equal=.false.
    call a%snapshot(sa,oka)
    call b%snapshot(sb,okb)
    if (.not. oka .or. .not. okb) return
    equal=physical_snapshot_identical(sa,sb)
  end function committed_physics_identical

  logical function physical_snapshot_identical(a,b) result(equal)
    class(transaction_state_t), intent(in) :: a,b
    integer :: k
    equal=.false.
    select type (pa=>a)
    type is (fmr_b110_physical_state_t)
      select type (pb=>b)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head)) return
        if (size(pa%water_content) /= size(pb%water_content)) return
        do k=1,pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        equal=.true.
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
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ21_ROOT_SINK_ORACLE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq21_root_sink_runtime_oracle
