module mod_fgc25_multiswap_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, &
       GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_model_t, &
       dummy_parameters_t, dummy_groundwater_service_t
  implicit none
  private

  public :: setup_fgc25_two_tiles
  public :: setup_fgc25_one_tile

contains

  subroutine setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
       numerical, committed, bindings, status)
    type(kernel_executor_t), intent(out) :: executor
    type(dummy_model_t), target, intent(out) :: model
    type(dummy_parameters_t), intent(out) :: parameters(2)
    type(dummy_groundwater_service_t), intent(out) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledgers(2)
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_coupling_origin_t), intent(out) :: origins(2)
    type(canonical_numerical_config_t), intent(out) :: numerical
    type(kernel_committed_state_t), intent(out) :: committed(2)
    type(groundwater_direct_tile_binding_t), intent(out) :: bindings(2)
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    integer :: i, ledger_status
    real(real64), parameter :: T0 = 123.375_real64, T1 = 123.625_real64

    executor = kernel_executor_t()
    model = dummy_model_t()
    groundwater = dummy_groundwater_service_t()
    datum = groundwater_head_datum_t()
    policy = groundwater_head_convergence_policy_t()
    window = groundwater_coupling_window_t()
    numerical = canonical_numerical_config_t()
    call executor%bind_model(model)

    do i = 1, 2
      parameters(i) = dummy_parameters_t()
      committed(i) = kernel_committed_state_t()
      allocate(dummy_state_t :: initial_state)
      select type (typed_initial => initial_state)
      type is (dummy_state_t)
        typed_initial%storage = 10.0_real64 + real(i-1, real64)
      end select
      call committed(i)%initialize(900_int64 + int(i, int64), initial_state, initialized, initial_time=T0)
      if (.not. initialized) then
        status = -100
        return
      end if
      deallocate(initial_state)

      ledgers(i) = groundwater_interface_mass_ledger_t()
      call ledgers(i)%bind_identity(1000_int64 + int(i, int64), ledger_status)
      if (ledger_status /= GW_MASS_LEDGER_OK) then
        status = ledger_status
        return
      end if

      origins(i) = groundwater_coupling_origin_t()
      origins(i)%initialized = .true.
      origins(i)%coupling_id = 10001_int64
      origins(i)%accepted_h_groundwater_m = 0.4_real64
      origins(i)%accepted_time = T0
      origins(i)%swap_lineage_id = 900_int64 + int(i, int64)
      origins(i)%swap_revision = 0_int64
      origins(i)%groundwater_service_id = groundwater%service_id_value
      origins(i)%groundwater_lineage_id = groundwater%lineage_id_value
      origins(i)%groundwater_revision = 0_int64

      bindings(i)%groundwater_cell_id = 7001_int64
      bindings(i)%tile_id = 200_int64 + int(i, int64)
    end do
    bindings(1)%area_fraction = 0.25_real64
    bindings(2)%area_fraction = 0.75_real64

    groundwater%current_time = T0
    call fill_common(datum, policy, window, numerical, T0, T1)
    status = GW_MASS_LEDGER_OK
  end subroutine setup_fgc25_two_tiles

  subroutine setup_fgc25_one_tile(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
       numerical, committed, bindings, status)
    type(kernel_executor_t), intent(out) :: executor
    type(dummy_model_t), target, intent(out) :: model
    type(dummy_parameters_t), intent(out) :: parameters(1)
    type(dummy_groundwater_service_t), intent(out) :: groundwater
    type(groundwater_interface_mass_ledger_t), intent(out) :: ledgers(1)
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_coupling_origin_t), intent(out) :: origins(1)
    type(canonical_numerical_config_t), intent(out) :: numerical
    type(kernel_committed_state_t), intent(out) :: committed(1)
    type(groundwater_direct_tile_binding_t), intent(out) :: bindings(1)
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    real(real64), parameter :: T0 = 123.375_real64, T1 = 123.625_real64

    executor = kernel_executor_t()
    model = dummy_model_t()
    parameters(1) = dummy_parameters_t()
    groundwater = dummy_groundwater_service_t()
    ledgers(1) = groundwater_interface_mass_ledger_t()
    datum = groundwater_head_datum_t()
    policy = groundwater_head_convergence_policy_t()
    window = groundwater_coupling_window_t()
    numerical = canonical_numerical_config_t()
    committed(1) = kernel_committed_state_t()
    call executor%bind_model(model)

    allocate(dummy_state_t :: initial_state)
    select type (typed_initial => initial_state)
    type is (dummy_state_t)
      typed_initial%storage = 10.0_real64
    end select
    call committed(1)%initialize(901_int64, initial_state, initialized, initial_time=T0)
    if (.not. initialized) then
      status = -100
      return
    end if
    deallocate(initial_state)
    call ledgers(1)%bind_identity(1001_int64, status)
    if (status /= GW_MASS_LEDGER_OK) return

    groundwater%current_time = T0
    call fill_common(datum, policy, window, numerical, T0, T1)
    origins(1)%initialized = .true.
    origins(1)%coupling_id = 10001_int64
    origins(1)%accepted_h_groundwater_m = 0.4_real64
    origins(1)%accepted_time = T0
    origins(1)%swap_lineage_id = 901_int64
    origins(1)%swap_revision = 0_int64
    origins(1)%groundwater_service_id = groundwater%service_id_value
    origins(1)%groundwater_lineage_id = groundwater%lineage_id_value
    origins(1)%groundwater_revision = 0_int64
    bindings(1)%groundwater_cell_id = 7001_int64
    bindings(1)%tile_id = 201_int64
    bindings(1)%area_fraction = 1.0_real64
  end subroutine setup_fgc25_one_tile

  subroutine fill_common(datum, policy, window, numerical, t0, t1)
    type(groundwater_head_datum_t), intent(out) :: datum
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_coupling_window_t), intent(out) :: window
    type(canonical_numerical_config_t), intent(out) :: numerical
    real(real64), intent(in) :: t0, t1

    datum = groundwater_head_datum_t()
    datum%available = .true.
    datum%datum_id = 501_int64
    datum%bottom_boundary_elevation_m = -2.0_real64

    policy = groundwater_head_convergence_policy_t()
    policy%available = .true.
    policy%policy_id = 601_int64
    policy%policy_version = 1
    policy%provenance_class = GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
    policy%provenance_id = 602_int64
    policy%provenance_qualified = .true.
    policy%head_tolerance_m = 0.01_real64

    window = groundwater_coupling_window_t()
    window%t0 = t0
    window%t1 = t1

    numerical = canonical_numerical_config_t()
    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%temporal_tolerance = 1.0e-12_real64
    numerical%transaction%mass_tolerance = 1.0e-12_real64
    numerical%transaction%retry_scale = 0.5_real64
    numerical%transaction%max_retries = 2
    numerical%max_committed_substeps = 4
    numerical%progress_tolerance = 0.0_real64
  end subroutine fill_common

end module mod_fgc25_multiswap_fixture
