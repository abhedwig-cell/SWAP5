program test_fmr_b111_soil_n_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, soil_n_transfer_t, &
       initialize_soil_n_pool_state, SOIL_N_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, fmr_b111_soil_n_model_t, &
       initialize_fmr_b111_soil_n_state, configure_fmr_b111_soil_n_model, apply_fmr_b111_soil_n_management_event, &
       FMR_SOIL_N_OK, FMR_SOIL_N_EVENT_ALREADY_CONSUMED
  implicit none

  type(soil_n_inventory_parameters_t) :: params, snapshot_params
  type(soil_n_pool_state_t) :: inventory, snapshot
  type(soil_n_transfer_t) :: rate
  type(fmr_b111_soil_n_state_t) :: initial
  type(fmr_b111_soil_n_model_t) :: model
  class(transaction_state_t), allocatable :: committed
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: result
  type(soil_n_receipt_t) :: event_receipt
  logical :: available
  integer :: status

  params%depth_m = 0.5_real64
  params%nfrac_fom = [0.01_real64, 0.02_real64]
  params%nfrac_biomass = 0.03_real64
  params%nfrac_humus = 0.04_real64

  call initialize_soil_n_pool_state(params, [10.0_real64,20.0_real64], 5.0_real64, 40.0_real64, &
       2.0_real64, 3.0_real64, inventory, status)
  call check(status == SOIL_N_OK, 'inventory init')
  call initialize_fmr_b111_soil_n_state(params, inventory, initial, status)
  call check(status == FMR_SOIL_N_OK, 'transaction state init')

  allocate(rate%fom_delta_kg_m3(2))
  rate%fom_delta_kg_m3 = 0.0_real64
  rate%nitrate_n_delta_kg_m2 = 0.2_real64
  rate%external_n_input_kg_m2 = 0.2_real64
  call configure_fmr_b111_soil_n_model(params, rate, model, status)
  call check(status == FMR_SOIL_N_OK, 'model config')
  allocate(committed, source=initial)

  policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  policy%max_retries = 0
  policy%mass_tolerance = 1.0e-12_real64
  policy%temporal_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, result)
  call check(result%status == TX_STATUS_ACCEPTED, 'accepted interval')
  call check(result%commits == 1 .and. result%rollbacks == 0, 'single commit')
  call check(abs(result%accepted_total_in - 0.4_real64) < 1.0e-12_real64, 'mass input receipt')

  call snapshot_committed(committed, snapshot_params, snapshot, available)
  call check(available, 'accepted snapshot')
  call check(abs(snapshot%nitrate_n_kg_m2 - 3.4_real64) < 1.0e-12_real64, 'accepted nitrate')

  call initialize_fmr_b111_soil_n_state(snapshot_params, snapshot, initial, status)
  call check(status == FMR_SOIL_N_OK .and. initial%ready(), 'restart reconstruction')

  rate = soil_n_transfer_t()
  allocate(rate%fom_delta_kg_m3(2))
  rate%fom_delta_kg_m3 = 0.0_real64
  rate%nitrate_n_delta_kg_m2 = -100.0_real64
  rate%external_n_output_kg_m2 = 100.0_real64
  call configure_fmr_b111_soil_n_model(params, rate, model, status)
  call execute_reference_interval(model, committed, 2.0_real64, 3.0_real64, policy, result)
  call check(result%status == TX_STATUS_RETRY_EXHAUSTED, 'rejected overdraw')

  call snapshot_committed(committed, snapshot_params, snapshot, available)
  call check(available, 'post-reject snapshot')
  call check(abs(snapshot%nitrate_n_kg_m2 - 3.4_real64) < 1.0e-12_real64, 'rollback identity')

  ! Once-only management event state is part of the persistent owner.
  rate = soil_n_transfer_t()
  allocate(rate%fom_delta_kg_m3(2))
  rate%fom_delta_kg_m3 = 0.0_real64
  rate%ammonium_n_delta_kg_m2 = 0.1_real64
  rate%external_n_input_kg_m2 = 0.1_real64
  call apply_event_on_committed(committed, 42_8, rate, status, event_receipt)
  call check(status == FMR_SOIL_N_OK, 'management event accepted')
  call apply_event_on_committed(committed, 42_8, rate, status, event_receipt)
  call check(status == FMR_SOIL_N_EVENT_ALREADY_CONSUMED, 'duplicate event rejected')
  call snapshot_committed(committed, snapshot_params, snapshot, available)
  call check(available, 'event snapshot')
  call check(abs(snapshot%ammonium_n_kg_m2 - 2.1_real64) < 1.0e-12_real64, 'event applied once')

  call initialize_fmr_b111_soil_n_state(snapshot_params, snapshot, initial, status)
  call check(status == FMR_SOIL_N_OK, 'event restart inventory')
  ! Reconstructed inventory alone is insufficient to infer event lineage; production
  ! restart serializers must therefore carry the transaction state, not rebuild it
  ! only from nutrient concentrations.
  print '(A)', 'FMR_B111_SOIL_N_TRANSACTION_PASS'

contains

  subroutine snapshot_committed(state, p, s, ok)
    class(transaction_state_t), allocatable, intent(in) :: state
    type(soil_n_inventory_parameters_t), intent(out) :: p
    type(soil_n_pool_state_t), intent(out) :: s
    logical, intent(out) :: ok
    ok = .false.
    select type (state)
    type is (fmr_b111_soil_n_state_t)
      call state%snapshot(p, s, ok)
    class default
      p = soil_n_inventory_parameters_t()
      s = soil_n_pool_state_t()
    end select
  end subroutine

  subroutine apply_event_on_committed(state,event_id,transfer,status,receipt)
    class(transaction_state_t),allocatable,intent(inout)::state
    integer(kind=8),intent(in)::event_id
    type(soil_n_transfer_t),intent(in)::transfer
    integer,intent(out)::status
    type(soil_n_receipt_t),intent(out)::receipt
    status=FMR_SOIL_N_INVALID
    receipt=soil_n_receipt_t()
    select type(state)
    type is(fmr_b111_soil_n_state_t)
      call apply_fmr_b111_soil_n_management_event(state,event_id,transfer,status,receipt)
    end select
  end subroutine

  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if (.not. ok) then
      print '(A)', trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
