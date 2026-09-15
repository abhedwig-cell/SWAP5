module mod_fgc25_fail_on_fourth_materialization
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_kernel_transactions, only: kernel_parameters_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, &
       GW_SWAP_FORCING_OK, GW_SWAP_FORCING_INVALID_HEAD, GW_SWAP_FORCING_NOT_READY
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_forcing_t, dummy_parameters_t
  implicit none
  private

  integer :: materialize_calls = 0

  type, extends(groundwater_swap_forcing_materializer_t), public :: fail_on_fourth_materializer_t
  contains
    procedure :: profile_admitted => fail_profile_admitted
    procedure :: materialize => fail_materialize
  end type fail_on_fourth_materializer_t

  public :: reset_fail_materializer

contains

  subroutine reset_fail_materializer()
    materialize_calls = 0
  end subroutine reset_fail_materializer

  logical function fail_profile_admitted(self, parameters) result(admitted)
    class(fail_on_fourth_materializer_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    admitted = same_type_as(self, self)
    select type (typed_parameters => parameters)
    type is (dummy_parameters_t)
      admitted = admitted .and. typed_parameters%admitted
    class default
      admitted = .false.
    end select
  end function fail_profile_admitted

  subroutine fail_materialize(self, interface_head_m, datum, forcing, status)
    class(fail_on_fourth_materializer_t), intent(in) :: self
    real(real64), intent(in) :: interface_head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    class(canonical_forcing_t), allocatable, intent(out) :: forcing
    integer, intent(out) :: status

    if (allocated(forcing)) deallocate(forcing)
    status = GW_SWAP_FORCING_INVALID_HEAD
    if (.not. same_type_as(self, self)) return
    if (.not. ieee_is_finite(interface_head_m)) return
    if (.not. datum%valid()) return

    materialize_calls = materialize_calls + 1
    if (materialize_calls == 4) then
      status = GW_SWAP_FORCING_NOT_READY
      return
    end if

    allocate(dummy_forcing_t :: forcing)
    select type (typed_forcing => forcing)
    type is (dummy_forcing_t)
      typed_forcing%interface_head_m = interface_head_m
      status = GW_SWAP_FORCING_OK
    class default
      status = GW_SWAP_FORCING_NOT_READY
    end select
  end subroutine fail_materialize

end module mod_fgc25_fail_on_fourth_materialization

program test_fgc25_corrector_tile_fail_closed
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_CORRECTOR_FORCING_FAILED
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_groundwater_service_t, check
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  use mod_fgc25_fail_on_fourth_materialization, only: fail_on_fourth_materializer_t, reset_fail_materializer
  implicit none

  integer :: failures, status, i
  type(kernel_executor_t) :: executor
  type(kernel_committed_state_t) :: committed(2)
  type(dummy_model_t), target :: model
  type(dummy_parameters_t) :: parameters(2)
  type(fail_on_fourth_materializer_t) :: materializer
  type(dummy_groundwater_service_t) :: groundwater
  type(groundwater_interface_mass_ledger_t) :: ledgers(2)
  type(groundwater_interface_mass_snapshot_t) :: snap
  type(groundwater_head_datum_t) :: datum
  type(groundwater_head_convergence_policy_t) :: policy
  type(groundwater_coupling_window_t) :: window
  type(groundwater_coupling_origin_t) :: origins(2)
  type(groundwater_direct_tile_binding_t) :: bindings(2)
  type(groundwater_multiswap_result_t) :: result
  type(canonical_numerical_config_t) :: numerical

  failures = 0
  call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
       numerical, committed, bindings, status)
  call check(status == GW_MASS_LEDGER_OK, 'partial-corrector-fail: setup', failures)
  call reset_fail_materializer()

  call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
       numerical, groundwater, ledgers, datum, policy, window, origins, result)

  call check(result%status == GW_MULTI_CORRECTOR_FORCING_FAILED, &
       'partial-corrector-fail: explicit status', failures)
  call check(result%request_smaller_window .and. .not. result%committed .and. .not. result%completed, &
       'partial-corrector-fail: fail closed', failures)
  call check(result%diagnostics%failing_tile_index == 2, &
       'partial-corrector-fail: second canonical tile identified', failures)
  call check(model%advance_count == 3, &
       'partial-corrector-fail: both predictor tiles and first corrector tile executed', failures)
  call check(groundwater%trial_count == 1 .and. groundwater%discard_count == 1, &
       'partial-corrector-fail: predictor groundwater trial discarded', failures)
  call check(groundwater%revision == 0_int64 .and. groundwater%commit_count == 0 .and. &
       groundwater%prepare_count == 0, 'partial-corrector-fail: groundwater unmodified', failures)
  call check(result%diagnostics%corrector_swap(1)%candidate_rollbacks == 1, &
       'partial-corrector-fail: first corrector candidate rolled back', failures)
  call check(result%diagnostics%corrector_swap(2)%committed_state_mutations == 0, &
       'partial-corrector-fail: failing tile never committed', failures)

  do i = 1, 2
    call check(committed(i)%current_revision() == 0_int64, &
         'partial-corrector-fail: SWAP committed revision unchanged', failures)
    call check(origins(i)%swap_revision == 0_int64 .and. origins(i)%groundwater_revision == 0_int64, &
         'partial-corrector-fail: coupling origins unchanged', failures)
    call ledgers(i)%snapshot(snap)
    call check(snap%committed_exchange_count == 0 .and. .not. snap%trial_active .and. .not. snap%prepared_active, &
         'partial-corrector-fail: tile ledger untouched', failures)
  end do

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 PARTIAL CORRECTOR FAIL-CLOSED FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 PARTIAL CORRECTOR FAIL-CLOSED PASS'
end program test_fgc25_corrector_tile_fail_closed
