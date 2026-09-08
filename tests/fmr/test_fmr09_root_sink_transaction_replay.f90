program test_fmr09_root_sink_transaction_replay
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 2100.375_real64
  real(real64), parameter :: t1 = 2100.875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result_a1, result_b, result_a2
  type(kernel_candidate_state_t) :: candidate_a1, candidate_b, candidate_a2
  type(kernel_diagnostics_t) :: diag_a1, diag_b, diag_a2
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: conductivity0, distinction_tolerance
  integer(int64) :: committed_before, candidate_a1_fp, candidate_a2_fp
  integer :: k
  logical :: ok

  call configure_parameters(parameters, initial_state, conductivity0)
  parameters%root_extraction_active = .true.
  call configure_column(column, template)
  call configure_forcing(forcing_a, conductivity0)
  forcing_b = forcing_a

  do k = 1, numnod
    forcing_a%root_extraction_sink(k) = 0.004_real64 + 0.0002_real64*real(k,real64)
    forcing_b%root_extraction_sink(k) = 0.008_real64 + 0.0004_real64*real(k,real64)
  end do
  forcing_a%subsurface_irrigation_source = forcing_a%root_extraction_sink
  forcing_b%subsurface_irrigation_source = forcing_b%root_extraction_sink
  call require(maxval(forcing_a%root_extraction_sink) > minval(forcing_a%root_extraction_sink), &
       'A root sink is heterogeneous')
  call require(maxval(forcing_b%root_extraction_sink) > minval(forcing_b%root_extraction_sink), &
       'B root sink is heterogeneous')

  call configure_transaction(config)
  call fmr_new_b110_committed_state(committed, column%column_id, initial_state, t0, ok)
  call require(ok, 'committed init')
  committed_before = committed_fingerprint(committed)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok, 'capture checkpoint')
  call backend%initialize(top_provider)

  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, forcing_a, config, t0, t1, checkpoint, &
       result_a1, candidate_a1, diag_a1)
  call require_admitted(result_a1, candidate_a1, 'A1')
  call require(committed_fingerprint(committed) == committed_before, 'A1 trial leaves committed unchanged')
  candidate_a1_fp = candidate_fingerprint(candidate_a1)
  call fmr_discard_candidate(transaction_control, candidate_a1, diag_a1)
  call require(.not. candidate_a1%ready(), 'A1 discard invalidates candidate')
  call require(committed_fingerprint(committed) == committed_before, 'A1 rollback leaves committed unchanged')

  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, forcing_b, config, t0, t1, checkpoint, &
       result_b, candidate_b, diag_b)
  call require_admitted(result_b, candidate_b, 'B')
  call require(committed_fingerprint(committed) == committed_before, 'B trial leaves committed unchanged')
  distinction_tolerance = 256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(result_b%mass%total_out))
  call require(abs(result_b%mass%total_out-result_a1%mass%total_out) > distinction_tolerance, &
       'B forcing produces distinct authoritative root outflow')
  call fmr_discard_candidate(transaction_control, candidate_b, diag_b)
  call require(.not. candidate_b%ready(), 'B discard invalidates candidate')
  call require(committed_fingerprint(committed) == committed_before, 'B rollback leaves committed unchanged')

  call reset_globals()
  call backend%run_trial(column, template, parameters, committed, forcing_a, config, t0, t1, checkpoint, &
       result_a2, candidate_a2, diag_a2)
  call require_admitted(result_a2, candidate_a2, 'A2')
  call require(committed_fingerprint(committed) == committed_before, 'A2 trial leaves committed unchanged')
  candidate_a2_fp = candidate_fingerprint(candidate_a2)
  call require(candidate_a2_fp == candidate_a1_fp, 'A replay candidate bitwise identity after B')
  call require(mass_identical(result_a1, result_a2), 'A replay authoritative mass identity after B')
  call fmr_discard_candidate(transaction_control, candidate_a2, diag_a2)
  call require(.not. candidate_a2%ready(), 'A2 discard invalidates candidate')
  call require(committed_fingerprint(committed) == committed_before, 'A2 rollback leaves committed unchanged')

  write(*,'(A)') 'FMR09_HETEROGENEOUS_ROOT_TRANSACTION_FIXTURE=PASS'
  write(*,'(A)') 'FMR09_ROOT_ROLLBACK_REPLAY=PASS'
  write(*,'(A)') 'FMR09_ROOT_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FMR09_ROOT_TRANSACTION_HARD_MASS=PASS'
  write(*,'(A)') 'FMR09_ROOT_TRANSACTION_REPLAY_TEST PASS'

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
    integer :: i
    p%parameter_set_id=90901_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.032_real64; p%cofgen(2,i)=0.423_real64; p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64; p%cofgen(5,i)=0.365_real64; p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i); p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64; p%cofgen(10,i)=p%cofgen(3,i); p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i); p%cofgen(22,i)=-1.0e6_real64; p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%root_extraction_active=.false.
    p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
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
    cfg%transaction%temporal_tolerance=0.0_real64; cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64; cfg%transaction%max_retries=0
    cfg%max_committed_substeps=8; cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64; legacy_qrot=-99999.0_real64
    swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_globals

  subroutine require_admitted(result,candidate,label)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    character(len=*), intent(in) :: label
    call require(result%completed, trim(label)//' completed')
    call require(candidate%ready(), trim(label)//' candidate ready')
    call require(result%mass%complete, trim(label)//' authoritative mass complete')
    call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, trim(label)//' mass mask zero')
    call require(abs(result%mass%residual) <= hard_mass_gate, trim(label)//' hard mass gate')
  end subroutine require_admitted

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot,got)
    call require(got,'committed snapshot available')
    fp=physical_fingerprint(snapshot)
  end function committed_fingerprint

  integer(int64) function candidate_fingerprint(state) result(fp)
    type(kernel_candidate_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot,got)
    call require(got,'candidate snapshot available')
    fp=physical_fingerprint(snapshot)
  end function candidate_fingerprint

  integer(int64) function physical_fingerprint(snapshot) result(fp)
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    integer :: i
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do i=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(i),fp))
        fp=ieor(fp,transfer(physical%water_content(i),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp))
      fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR09 unexpected physical state type'
    end select
  end function physical_fingerprint

  logical function mass_identical(a,b)
    type(kernel_result_t), intent(in) :: a,b
    mass_identical=a%mass%complete .eqv. b%mass%complete
    if (.not. mass_identical) return
    mass_identical=a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         a%mass%origin_lineage_id == b%mass%origin_lineage_id .and. &
         a%mass%origin_revision == b%mass%origin_revision .and. &
         a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
         same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
         same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
         same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function mass_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR09_ROOT_TRANSACTION_REPLAY_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr09_root_sink_transaction_replay
