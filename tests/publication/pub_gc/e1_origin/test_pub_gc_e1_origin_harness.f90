program test_pub_gc_e1_origin_harness
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  integer(int64), parameter :: origin_lineage = 931001_int64
  integer(int64), parameter :: history_lineage = 931002_int64
  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: head_a = -75.0_real64
  real(real64), parameter :: head_b = -74.5_real64
  real(real64), parameter :: duration = 1.0e-4_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(kernel_committed_state_t) :: committed, history_committed
  type(kernel_checkpoint_t) :: origin_checkpoint, history_checkpoint
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
  type(canonical_numerical_config_t) :: config
  type(kernel_result_t) :: result_a1, result_b_same, result_a2, result_a_history, result_b_history
  type(kernel_candidate_state_t) :: candidate_a1, candidate_b_same, candidate_a2, candidate_a_history, candidate_b_history
  type(kernel_diagnostics_t) :: diag_a1, diag_b_same, diag_a2, diag_a_history, diag_b_history
  class(transaction_state_t), allocatable :: origin_before, origin_after, endpoint_a1, endpoint_a2, history_seed
  integer(int64) :: revision_before, revision_after, lineage_before, lineage_after
  real(real64) :: time_before, time_after
  logical :: ok, available, time_available_before, time_available_after

  call initialize_parameters(parameters)
  call initialize_committed(committed, parameters, ok)
  call require(ok, 'accepted origin initialization')
  call initialize_column_template(column, template)
  call initialize_forcing(forcing_a, head_a)
  call initialize_forcing(forcing_b, head_b)
  call initialize_config(config)
  call backend%initialize(top)

  revision_before = committed%current_revision()
  lineage_before = committed%current_lineage_id()
  call committed%current_time(time_before, time_available_before)
  call committed%snapshot(origin_before, available)
  call require(available .and. time_available_before, 'accepted origin snapshot')
  call require(revision_before == 0_int64 .and. lineage_before == origin_lineage, 'accepted origin provenance')
  call require(same_bits(time_before, 0.0_real64), 'accepted origin nominal time')
  call committed%capture_checkpoint(origin_checkpoint, available)
  call require(available .and. origin_checkpoint%ready(), 'accepted origin checkpoint')

  ! GC-ORIGIN-SAME: A, B, A all originate from the same accepted checkpoint.
  call backend%run_trial(column, template, parameters, committed, forcing_a, config, 0.0_real64, duration, &
       origin_checkpoint, result_a1, candidate_a1, diag_a1)
  call require_completed(result_a1, candidate_a1, 'SAME A1')
  call candidate_a1%snapshot(endpoint_a1, available)
  call require(available, 'SAME A1 endpoint snapshot')

  call backend%run_trial(column, template, parameters, committed, forcing_b, config, 0.0_real64, duration, &
       origin_checkpoint, result_b_same, candidate_b_same, diag_b_same)
  call require_completed(result_b_same, candidate_b_same, 'SAME B')

  call backend%run_trial(column, template, parameters, committed, forcing_a, config, 0.0_real64, duration, &
       origin_checkpoint, result_a2, candidate_a2, diag_a2)
  call require_completed(result_a2, candidate_a2, 'SAME A2')
  call candidate_a2%snapshot(endpoint_a2, available)
  call require(available, 'SAME A2 endpoint snapshot')

  call require(same_bits(result_a1%bottom_outward_exchange_native, result_a2%bottom_outward_exchange_native), &
       'SAME A replay integrated exchange bit identity')
  call require(same_bits(result_a1%terminal_bottom_outward_flux_native, result_a2%terminal_bottom_outward_flux_native), &
       'SAME A replay terminal flux bit identity')
  call require_physical_identity(endpoint_a1, endpoint_a2, 'SAME A replay endpoint')

  call committed%snapshot(origin_after, available)
  call require(available, 'accepted origin post-SAME snapshot')
  revision_after = committed%current_revision()
  lineage_after = committed%current_lineage_id()
  call committed%current_time(time_after, time_available_after)
  call require(time_available_after, 'accepted origin post-SAME time')
  call require(revision_after == revision_before .and. lineage_after == lineage_before, &
       'SAME trials do not publish accepted provenance')
  call require(same_bits(time_after, time_before), 'SAME trials do not publish accepted time')
  call require_physical_identity(origin_before, origin_after, 'SAME accepted origin unchanged')

  ! GC-ORIGIN-HISTORY-DIAG: seed a NEW research lineage from an A candidate
  ! endpoint while retaining the same nominal t0. This is deliberately not a
  ! production algorithm and deliberately does not mutate the accepted origin.
  call backend%run_trial(column, template, parameters, committed, forcing_a, config, 0.0_real64, duration, &
       origin_checkpoint, result_a_history, candidate_a_history, diag_a_history)
  call require_completed(result_a_history, candidate_a_history, 'HISTORY A seed')
  call candidate_a_history%snapshot(history_seed, available)
  call require(available, 'HISTORY A physical seed snapshot')
  call history_committed%initialize(history_lineage, history_seed, ok, 0.0_real64)
  call require(ok .and. history_committed%ready(), 'HISTORY synthetic lineage initialization')
  call require(history_committed%current_lineage_id() == history_lineage, 'HISTORY distinct research lineage')
  call history_committed%capture_checkpoint(history_checkpoint, available)
  call require(available .and. history_checkpoint%ready(), 'HISTORY synthetic checkpoint')

  call backend%run_trial(column, template, parameters, history_committed, forcing_b, config, 0.0_real64, duration, &
       history_checkpoint, result_b_history, candidate_b_history, diag_b_history)
  call require_completed(result_b_history, candidate_b_history, 'HISTORY B')

  call committed%snapshot(origin_after, available)
  call require(available, 'accepted origin post-HISTORY snapshot')
  call require(committed%current_revision() == revision_before, 'HISTORY diagnostic leaves accepted revision unchanged')
  call require(committed%current_lineage_id() == lineage_before, 'HISTORY diagnostic leaves accepted lineage unchanged')
  call committed%current_time(time_after, time_available_after)
  call require(time_available_after .and. same_bits(time_after, time_before), &
       'HISTORY diagnostic leaves accepted time unchanged')
  call require_physical_identity(origin_before, origin_after, 'HISTORY accepted origin unchanged')

  ! Qualification records both whole-window and terminal observables as available,
  ! but intentionally makes no SAME-vs-HISTORY effect-size assertion.
  call require(result_a1%bottom_interface_exchange_available .and. result_b_same%bottom_interface_exchange_available .and. &
       result_a2%bottom_interface_exchange_available .and. result_a_history%bottom_interface_exchange_available .and. &
       result_b_history%bottom_interface_exchange_available, 'whole-window interface exchange available')

  write(*,'(A,ES26.17E3)') 'PUB_GC_E1_A_REPLAY_WHOLE_WINDOW_EXCHANGE=', result_a1%bottom_outward_exchange_native
  write(*,'(A,ES26.17E3)') 'PUB_GC_E1_A_REPLAY_TERMINAL_FLUX=', result_a1%terminal_bottom_outward_flux_native
  write(*,'(A)') 'PUB_GC_E1_REAL_B110_MODE5=PASS'
  write(*,'(A)') 'PUB_GC_E1_SAME_ORIGIN_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'PUB_GC_E1_SAME_ORIGIN_ENDPOINT_IDENTITY=PASS'
  write(*,'(A)') 'PUB_GC_E1_HISTORY_DIAG_PUBLIC_SNAPSHOT_INITIALIZE=PASS'
  write(*,'(A)') 'PUB_GC_E1_ACCEPTED_ORIGIN_NONPUBLICATION=PASS'
  write(*,'(A)') 'PUB_GC_E1_WHOLE_WINDOW_AND_TERMINAL_OBSERVABLES=PASS'
  write(*,'(A)') 'PUB_GC_E1_ORIGIN_HARNESS_ORACLE=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 931001_int64
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
    p%swkimpl = 0; p%swkmean = 1; p%swsophy = 0
    p%max_iterations = 16; p%max_backtracking = 8; p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = hard_mass_gate; p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = hard_mass_gate; p%head_rel_tolerance = hard_mass_gate; p%ponding_tolerance = hard_mass_gate
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_committed(state_carrier, p, initialized)
    type(kernel_committed_state_t), intent(out) :: state_carrier
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: m, se, theta
    m = p%cofgen(7,1)
    se = (1.0_real64 + abs(p%cofgen(4,1)*h0)**p%cofgen(6,1))**(-m)
    theta = p%cofgen(1,1) + (p%cofgen(2,1)-p%cofgen(1,1))*se
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = h0
    physical%water_content = theta
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(state_carrier, origin_lineage, physical, 0.0_real64, initialized)
  end subroutine initialize_committed

  subroutine initialize_forcing(f, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: bottom_head
    f%top_flux = 0.0_real64
    f%top_head = h0
    f%bottom_flux = 0.0_real64
    f%bottom_head = bottom_head
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=931001_int64; t%physics_topology_id=931002_int64; t%vertical_layout_id=931003_int64
    t%state_layout_id=931004_int64; t%solver_interface_id=931005_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=origin_lineage; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg = canonical_numerical_config_t()
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = 1.0e-6_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 8
    cfg%max_committed_substeps = 32
    cfg%progress_tolerance = 0.0_real64
  end subroutine initialize_config

  subroutine require_completed(result, candidate, label)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    character(len=*), intent(in) :: label
    call require(result%completed, trim(label)//' completed')
    call require(candidate%ready(), trim(label)//' candidate available')
    call require(result%bottom_interface_exchange_available, trim(label)//' interface exchange available')
  end subroutine require_completed

  subroutine require_physical_identity(left_state, right_state, label)
    class(transaction_state_t), allocatable, intent(in) :: left_state, right_state
    character(len=*), intent(in) :: label
    select type (left => left_state)
    type is (fmr_b110_physical_state_t)
      select type (right => right_state)
      type is (fmr_b110_physical_state_t)
        call require(left%active_nodes==right%active_nodes, trim(label)//' active-node identity')
        call require(allocated(left%pressure_head).and.allocated(right%pressure_head), trim(label)//' heads allocated')
        call require(allocated(left%water_content).and.allocated(right%water_content), trim(label)//' water allocated')
        call require(size(left%pressure_head)==size(right%pressure_head), trim(label)//' head shape')
        call require(size(left%water_content)==size(right%water_content), trim(label)//' water shape')
        call require(all(transfer(left%pressure_head,0_int64,size(left%pressure_head)) == &
             transfer(right%pressure_head,0_int64,size(right%pressure_head))), trim(label)//' head bit identity')
        call require(all(transfer(left%water_content,0_int64,size(left%water_content)) == &
             transfer(right%water_content,0_int64,size(right%water_content))), trim(label)//' water bit identity')
        call require(same_bits(left%ponding_depth,right%ponding_depth), trim(label)//' ponding bit identity')
        call require(same_bits(left%groundwater_level,right%groundwater_level), trim(label)//' groundwater bit identity')
      class default
        call require(.false., trim(label)//' right type')
      end select
    class default
      call require(.false., trim(label)//' left type')
    end select
  end subroutine require_physical_identity

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_GC_E1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_gc_e1_origin_harness
