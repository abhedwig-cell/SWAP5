program test_m7_optional_state_allocation_census
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state
  use mod_soil_temperature_contract, only: soil_temperature_state_t, initialize_soil_temperature_state, SOIL_TEMP_OK
  implicit none

  type(fmr_b110_physical_state_t) :: inactive_state, active_payload_state
  type(kernel_committed_state_t) :: inactive_committed, active_committed
  type(soil_temperature_state_t) :: temperature_state
  class(transaction_state_t), allocatable :: snapshot
  logical :: ok, available
  integer :: temperature_status

  inactive_state%active_nodes = 2
  allocate(inactive_state%pressure_head(2), inactive_state%water_content(2))
  inactive_state%pressure_head = [-10.0_real64, -20.0_real64]
  inactive_state%water_content = [0.30_real64, 0.25_real64]
  call fmr_new_b110_committed_state(inactive_committed, 701_int64, inactive_state, 0.0_real64, ok)
  call require(ok, 'inactive base committed state initialized')
  call inactive_committed%snapshot(snapshot, available)
  call require(available, 'inactive base snapshot available')
  select type (state => snapshot)
  type is (fmr_b110_physical_state_t)
    call require(.not. allocated(state%snow), 'inactive snow payload absent')
    call require(.not. allocated(state%soil_temperature), 'inactive soil-temperature payload absent')
  class default
    call require(.false., 'inactive base layout remains base type')
  end select
  deallocate(snapshot)
  print '(a)', 'M7_OPTIONAL_STATE_INACTIVE_BASE_PAYLOADS_ABSENT=PASS'

  active_payload_state = inactive_state
  allocate(active_payload_state%snow, active_payload_state%soil_temperature)
  active_payload_state%snow%event_t0 = 0.25_real64
  call initialize_soil_temperature_state([10.0_real64, 11.0_real64], temperature_state, temperature_status)
  call require(temperature_status == SOIL_TEMP_OK, 'initialize optional soil-temperature payload')
  active_payload_state%soil_temperature = temperature_state
  call fmr_new_b110_committed_state(active_committed, 702_int64, active_payload_state, 0.0_real64, ok)
  call require(ok, 'active-payload committed state initialized')
  call active_committed%snapshot(snapshot, available)
  call require(available, 'active-payload snapshot available')
  select type (state => snapshot)
  type is (fmr_b110_physical_state_t)
    call require(allocated(state%snow), 'snow payload cloned only when present')
    call require(allocated(state%soil_temperature), 'soil-temperature payload cloned only when present')
    call require(state%snow%event_t0 == 0.25_real64, 'snow payload value preserved')
    call require(state%soil_temperature%ready() .and. state%soil_temperature%node_count() == 2, &
         'soil-temperature payload value preserved')
  class default
    call require(.false., 'active-payload layout remains base type')
  end select
  print '(a)', 'M7_OPTIONAL_STATE_ACTIVE_PAYLOAD_CLONE_IDENTITY=PASS'
  print '(a)', 'M7_OPTIONAL_STATE_ALLOCATION_CENSUS_TEST PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'M7_OPTIONAL_STATE_ALLOCATION_CENSUS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_m7_optional_state_allocation_census
