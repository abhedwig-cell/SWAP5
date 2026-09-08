program test_fmr05_strict_acceptance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_CHECKPOINT_MISMATCH
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_serialized_column_result_t), allocatable :: ab(:), ba(:), a_after(:), bad(:)
  type(fmr_column_diagnostics_t), allocatable :: diag(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  type(fmr_serialized_batch_diagnostics_t) :: batchdiag
  type(kernel_committed_state_t), allocatable :: states(:)
  integer :: status, kind

  call run_case(2, .false., 0, ab, diag, aggregate, batchdiag, states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A/B dispatch')
  call validate_success_batch(ab, batchdiag, 2)
  call require(result_for_id(ab,505001_int64)%dispatch_ordinal == 1, 'A dispatch ordinal')
  call require(result_for_id(ab,505002_int64)%dispatch_ordinal == 2, 'B dispatch ordinal')
  write(*,'(A)') 'FMR05_TWO_COLUMN_A_B=PASS'

  call run_case(2, .true., 0, ba, diag, aggregate, batchdiag, states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'B/A dispatch')
  call validate_success_batch(ba, batchdiag, 2)
  call require(column_physics_identical(result_for_id(ab,505001_int64),result_for_id(ba,505001_int64)), 'A identity B/A')
  call require(column_physics_identical(result_for_id(ab,505002_int64),result_for_id(ba,505002_int64)), 'B identity B/A')
  write(*,'(A)') 'FMR05_B_A_COLUMN_ID_BINDING=PASS'

  call run_case(1, .false., 0, a_after, diag, aggregate, batchdiag, states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A after B dispatch')
  call validate_success_batch(a_after, batchdiag, 1)
  call require(column_physics_identical(result_for_id(ab,505001_int64),a_after(1)), 'A/B/A repeatability')
  write(*,'(A)') 'FMR05_A_B_A_REPEATABILITY=PASS'
  write(*,'(A)') 'FMR05_IMMUTABLE_PARAMETER_SHARING=PASS'

  do kind = 1, 4
    call run_case(2, .false., kind, bad, diag, aggregate, batchdiag, states, status)
    call require(status == FMR_SERIAL_DISPATCH_OK, 'unsupported dispatch remains per-column')
    call require(result_for_id(bad,505001_int64)%committed, 'valid neighbor committed')
    call require(.not. result_for_id(bad,505002_int64)%admitted, 'unsupported column not admitted')
    call require(.not. result_for_id(bad,505002_int64)%solver_executed, 'unsupported no physical solve')
    call require(.not. result_for_id(bad,505002_int64)%committed, 'unsupported no commit')
    call require(batchdiag%number_requested == 2 .and. batchdiag%number_admitted == 1, 'unsupported admission counts')
    call require(batchdiag%number_executed == 1 .and. batchdiag%number_committed == 1 .and. &
         batchdiag%number_rejected == 1, 'unsupported execution counts')
    call require(batchdiag%max_simultaneous_real_physical_solves == 1, 'unsupported serialized max')
    select case(kind)
    case(1); write(*,'(A)') 'FMR05_UNSUPPORTED_ROOT_EXTRACTION=PASS'
    case(2); write(*,'(A)') 'FMR05_UNSUPPORTED_MACROPORE=PASS'
    case(3); write(*,'(A)') 'FMR05_UNSUPPORTED_SNOW=PASS'
    case(4); write(*,'(A)') 'FMR05_UNSUPPORTED_SWKIMPL=PASS'
    end select
  end do

  call verify_checkpoint_and_transaction_isolation()
  write(*,'(A)') 'FMR05_CROSS_COLUMN_CHECKPOINT_REJECTION=PASS'
  write(*,'(A)') 'FMR05_STALE_CHECKPOINT_REJECTION=PASS'
  write(*,'(A)') 'FMR05_ROLLBACK_A_LEAVES_A_B_UNCHANGED=PASS'
  write(*,'(A)') 'FMR05_COMMIT_A_LEAVES_B_UNCHANGED=PASS'
  write(*,'(A)') 'FMR05_GENERIC_TIME_1000_125_TO_1000_625=PASS'
  write(*,'(A)') 'FMR05_STRICT_ACCEPTANCE_TEST PASS'

contains

  subroutine run_case(n, reverse_order, unsupported_kind, results, diagnostics, agg, rdiag, states, dispatch_status)
    integer, intent(in) :: n, unsupported_kind
    logical, intent(in) :: reverse_order
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: agg
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: rdiag
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer, intent(out) :: dispatch_status

    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(2)
    type(fmr_b110_physical_parameters_t) :: parameters(2), immutable_before
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: tmp
    real(real64) :: conductivity0
    logical :: ok
    integer :: i, left, right

    call configure_templates(templates)
    call configure_parameters(parameters(1), initial_state, conductivity0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 50502_int64
    select case(unsupported_kind)
    case(1); parameters(2)%root_extraction_active = .true.
    case(2); parameters(2)%macropore_active = .true.
    case(3); parameters(2)%snow_active = .true.
    case(4); parameters(2)%swkimpl = 1
    end select
    immutable_before = parameters(1)
    call configure_transaction(config)

    allocate(columns(n), forcings(n), states(n))
    do i = 1, n
      columns(i)%column_id = 505000_int64 + int(i,int64)
      columns(i)%template_id = templates(1+mod(i-1,2))%template_id
      columns(i)%parameter_ref = 1_int64
      if (unsupported_kind > 0 .and. i == 2) columns(i)%parameter_ref = 2_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = int(i,int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      call fmr_new_b110_committed_state(states(i), columns(i)%column_id, initial_state, t0, ok)
      call require(ok, 'committed initialization')
    end do

    if (reverse_order) then
      do left = 1, n/2
        right = n + 1 - left
        tmp = columns(left); columns(left) = columns(right); columns(right) = tmp
      end do
    end if

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, t1, max(1,n), results, diagnostics, agg, dispatch_status, rdiag)
    call require(parameters_identical(parameters(1), immutable_before), 'shared immutable parameter unchanged')
  end subroutine run_case

  subroutine validate_success_batch(results, rdiag, n)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: rdiag
    integer, intent(in) :: n
    type(canonical_mass_accounting_t) :: expected
    integer :: i

    call require(rdiag%number_requested == n, 'requested count')
    call require(rdiag%number_admitted == n, 'admitted count')
    call require(rdiag%number_executed == n, 'executed count')
    call require(rdiag%number_committed == n, 'committed count')
    call require(rdiag%number_rejected == 0, 'rejected count')
    call require(rdiag%physical_solve_count == n, 'physical solve count')
    call require(rdiag%max_simultaneous_real_physical_solves == 1, 'max simultaneous real physical solves')
    call require(rdiag%deterministic_collection, 'deterministic collection')
    call require(same_bits(rdiag%effective_t0,t0) .and. same_bits(rdiag%effective_t1,t1), 'effective generic interval')
    call require(rdiag%authoritative_aggregate_mass%complete, 'aggregate mass complete')
    call require(rdiag%authoritative_aggregate_mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'aggregate mask zero')
    call aggregate_expected(results, expected)
    call require(mass_terms_identical(rdiag%authoritative_aggregate_mass,expected), 'aggregate canonical mass terms')
    do i=1,size(results)
      call require(results(i)%admission_assessed .and. results(i)%admitted, 'column admitted')
      call require(results(i)%dispatch_ordinal >= 1 .and. results(i)%dispatch_ordinal <= n, 'dispatch ordinal')
      call require(same_bits(results(i)%requested_t0,t0) .and. same_bits(results(i)%requested_t1,t1), 'column interval')
      call require(results(i)%mass%complete .and. results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
           'column authoritative mass complete')
      call require(abs(results(i)%mass%residual) <= hard_mass_gate, 'column hard mass gate')
    end do
    write(*,'(A,I0)') 'FMR05_PHYSICAL_SOLVE_COUNT=',rdiag%physical_solve_count
    write(*,'(A,I0)') 'FMR05_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=',rdiag%max_simultaneous_real_physical_solves
  end subroutine validate_success_batch

  subroutine verify_checkpoint_and_transaction_isolation()
    type(fmr_template_t) :: templates(2)
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: state_a, state_b
    type(fmr_logical_column_t) :: column_a, column_b
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(fmr_serialized_reference_backend_t) :: backend
    type(canonical_numerical_config_t) :: config
    type(kernel_checkpoint_t) :: checkpoint_a
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: kdiag
    type(kernel_executor_t) :: tx
    real(real64) :: conductivity0
    integer(int64) :: a0, b0, b_after
    logical :: ok, did_commit
    integer :: commit_status

    call configure_templates(templates)
    call configure_parameters(parameters, initial_state, conductivity0)
    call configure_forcing(forcing_a, conductivity0, 1.01_real64)
    call configure_forcing(forcing_b, conductivity0, 1.02_real64)
    call configure_transaction(config)
    call fmr_new_b110_committed_state(state_a, 505001_int64, initial_state, t0, ok); call require(ok,'state A init')
    call fmr_new_b110_committed_state(state_b, 505002_int64, initial_state, t0, ok); call require(ok,'state B init')
    column_a%column_id=505001_int64; column_a%template_id=templates(1)%template_id; column_a%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column_b%column_id=505002_int64; column_b%template_id=templates(1)%template_id; column_b%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call backend%initialize(top_provider)
    a0 = committed_fingerprint(state_a); b0 = committed_fingerprint(state_b)
    call fmr_capture_checkpoint(state_a, checkpoint_a, ok); call require(ok,'checkpoint A capture')

    call backend%run_trial(column_b, templates(1), parameters, state_b, forcing_b, config, t0, t1, checkpoint_a, &
         result, candidate, kdiag)
    call require(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'cross-column checkpoint mismatch')
    call require(kdiag%checkpoint_lineage_rejections == 1, 'cross-column lineage rejection')
    call require(.not. candidate%ready(), 'cross-column no candidate')
    call require(committed_fingerprint(state_a)==a0 .and. committed_fingerprint(state_b)==b0, 'cross-column states unchanged')

    call backend%run_trial(column_a, templates(1), parameters, state_a, forcing_a, config, t0, t1, checkpoint_a, &
         result, candidate, kdiag)
    call require(result%completed .and. candidate%ready(), 'A trial for rollback')
    call fmr_discard_candidate(tx, candidate, kdiag)
    call require(state_a%current_revision()==0_int64, 'rollback A revision unchanged')
    call require(committed_fingerprint(state_a)==a0 .and. committed_fingerprint(state_b)==b0, 'rollback A/B unchanged')

    call backend%run_trial(column_a, templates(1), parameters, state_a, forcing_a, config, t0, t1, checkpoint_a, &
         result, candidate, kdiag)
    call require(result%completed .and. candidate%ready(), 'A trial for commit')
    call fmr_commit_candidate(tx, state_a, candidate, kdiag, did_commit, commit_status)
    call require(did_commit .and. state_a%current_revision()==1_int64, 'A commit')
    b_after = committed_fingerprint(state_b)
    call require(b_after==b0 .and. state_b%current_revision()==0_int64, 'commit A leaves B')

    call backend%run_trial(column_a, templates(1), parameters, state_a, forcing_a, config, t1, t1+(t1-t0), checkpoint_a, &
         result, candidate, kdiag)
    call require(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'stale checkpoint mismatch')
    call require(kdiag%checkpoint_revision_rejections == 1, 'stale revision rejection')
    call require(.not. candidate%ready(), 'stale checkpoint no candidate')
    call require(state_a%current_revision()==1_int64 .and. committed_fingerprint(state_b)==b0, 'stale no mutation')
  end subroutine verify_checkpoint_and_transaction_isolation

  subroutine configure_templates(templates)
    type(fmr_template_t), intent(out) :: templates(2)
    templates(1)%template_id=505_int64; templates(1)%physics_topology_id=50501_int64
    templates(1)%vertical_layout_id=50502_int64; templates(1)%state_layout_id=50503_int64
    templates(1)%solver_interface_id=50504_int64; templates(1)%optional_state_layout_id=0_int64
    templates(1)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    templates(2)=templates(1); templates(2)%template_id=506_int64
  end subroutine configure_templates

  subroutine configure_parameters(parameters, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i
    parameters%parameter_set_id=50501_int64; parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod); parameters%cofgen=0.0_real64
    do i=1,numnod
      parameters%cofgen(1,i)=0.032_real64; parameters%cofgen(2,i)=0.423_real64; parameters%cofgen(3,i)=4.75_real64
      parameters%cofgen(4,i)=0.0135_real64; parameters%cofgen(5,i)=0.365_real64; parameters%cofgen(6,i)=1.455_real64
      parameters%cofgen(7,i)=1.0_real64-1.0_real64/parameters%cofgen(6,i); parameters%cofgen(8,i)=parameters%cofgen(4,i)
      parameters%cofgen(9,i)=0.0_real64; parameters%cofgen(10,i)=parameters%cofgen(3,i); parameters%cofgen(11,i)=0.999_real64
      parameters%cofgen(12,i)=0.99_real64*parameters%cofgen(3,i); parameters%cofgen(22,i)=-1.0e6_real64
      parameters%cofgen(23,i)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.; parameters%elasticity_active=.false.
    parameters%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hyd_parameters,parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads=head0; call constitutive%evaluate(heads,water,conductivity,capacity,dkdh); conductivity0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: i
    forcing%top_flux=-conductivity0; forcing%top_head=head0; forcing%bottom_flux=-conductivity0; forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i=1,numnod
      forcing%drainage_flux_by_level(1,i)=scale*1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i)=-scale*2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i)=forcing%drainage_flux_by_level(1,i)+forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i)=0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance=0.0_real64; config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=2
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  logical function parameters_identical(a,b)
    type(fmr_b110_physical_parameters_t), intent(in) :: a,b
    parameters_identical = a%parameter_set_id==b%parameter_set_id .and. a%active_nodes==b%active_nodes .and. &
         a%bottom_mode==b%bottom_mode .and. a%swkimpl==b%swkimpl .and. a%swkmean==b%swkmean .and. a%swsophy==b%swsophy .and. &
         a%root_extraction_active .eqv. b%root_extraction_active
    if (parameters_identical) parameters_identical = all(a%z==b%z) .and. all(a%dz==b%dz) .and. &
         all(a%node_distance==b%node_distance) .and. all(a%cofgen==b%cofgen)
  end function parameters_identical

  subroutine aggregate_expected(results,mass)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(canonical_mass_accounting_t), intent(out) :: mass
    integer :: i
    mass=canonical_mass_accounting_t(); mass%interval_t0=t0; mass%interval_t1=t1
    mass%complete=.true.; mass%missing_contribution_mask=TX_MASS_MISSING_NONE
    do i=1,size(results)
      if (.not.results(i)%committed) cycle
      mass%accepted_transaction_count=mass%accepted_transaction_count+results(i)%mass%accepted_transaction_count
      mass%storage_start=mass%storage_start+results(i)%mass%storage_start
      mass%storage_end=mass%storage_end+results(i)%mass%storage_end
      mass%storage_change=mass%storage_change+results(i)%mass%storage_change
      mass%total_in=mass%total_in+results(i)%mass%total_in; mass%total_out=mass%total_out+results(i)%mass%total_out
      mass%residual=mass%residual+results(i)%mass%residual
    end do
  end subroutine aggregate_expected

  logical function mass_terms_identical(a,b)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    mass_terms_identical = a%complete .eqv. b%complete .and. a%missing_contribution_mask==b%missing_contribution_mask .and. &
         a%accepted_transaction_count==b%accepted_transaction_count .and. same_bits(a%interval_t0,b%interval_t0) .and. &
         same_bits(a%interval_t1,b%interval_t1) .and. same_bits(a%storage_start,b%storage_start) .and. &
         same_bits(a%storage_end,b%storage_end) .and. same_bits(a%storage_change,b%storage_change) .and. &
         same_bits(a%total_in,b%total_in) .and. same_bits(a%total_out,b%total_out) .and. same_bits(a%residual,b%residual)
  end function mass_terms_identical

  logical function column_physics_identical(a,b)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    column_physics_identical = a%column_id==b%column_id .and. a%committed .eqv. b%committed .and. &
         a%solver_executed .eqv. b%solver_executed .and. trim(a%solver_route)==trim(b%solver_route) .and. &
         a%solver_iterations==b%solver_iterations .and. a%final_revision==b%final_revision .and. &
         mass_terms_identical(a%mass,b%mass)
  end function column_physics_identical

  function result_for_id(results,id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    type(fmr_serialized_column_result_t) :: value
    integer :: i
    do i=1,size(results)
      if (results(i)%column_id==id) then; value=results(i); return; end if
    end do
    error stop 'F-MR05 result id missing'
  end function result_for_id

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i
    call state%snapshot(snapshot,got); call require(got,'snapshot')
    fp=1469598103934665603_int64
    select type(p=>snapshot)
    type is(fmr_b110_physical_state_t)
      fp=ieor(fp,int(p%active_nodes,int64))
      do i=1,p%active_nodes
        fp=ieor(fp,transfer(p%pressure_head(i),fp)); fp=ieor(fp,transfer(p%water_content(i),fp))
      end do
      fp=ieor(fp,transfer(p%ponding_depth,fp)); fp=ieor(fp,transfer(p%groundwater_level,fp))
    class default; error stop 'F-MR05 unexpected state'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then; write(*,'(A,1X,A)') 'FMR05_STRICT_FAIL',trim(label); error stop 1; end if
  end subroutine require
end program test_fmr05_strict_acceptance
