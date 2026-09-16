program test_m1_c4_output_serialization_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_result_t, CANONICAL_STATUS_COMPLETED
  use mod_canonical_result_text_adapter, only: serialize_canonical_result_text
  implicit none

  type(canonical_result_t) :: result
  character(len=:), allocatable :: text1, text2
  integer :: status_before, attempts_before, accepted_before
  integer(int64) :: lineage_before, revision_before
  logical :: completed_before, mass_complete_before, bottom_available_before
  integer(int64) :: t0_bits_before, t1_bits_before, storage_bits_before, bottom_bits_before

  result = canonical_result_t()
  result%status = CANONICAL_STATUS_COMPLETED
  result%completed = .true.
  result%requested_t0 = 1234.125_real64
  result%requested_t1 = 1234.625_real64
  result%completed_t = result%requested_t1
  result%mass%complete = .true.
  result%mass%interval_t0 = result%requested_t0
  result%mass%interval_t1 = result%requested_t1
  result%mass%origin_lineage_id = 991122_int64
  result%mass%origin_revision = 17_int64
  result%mass%accepted_transaction_count = 2
  result%mass%storage_start = 8.5_real64
  result%mass%storage_end = 8.625_real64
  result%mass%storage_change = 0.125_real64
  result%mass%total_in = 0.375_real64
  result%mass%total_out = 0.25_real64
  result%mass%residual = 0.0_real64
  result%diagnostics%attempts = 3
  result%diagnostics%committed_substeps = 2
  result%diagnostics%external_commits = 1
  result%accepted_trajectory_direction%requested = .true.
  result%accepted_trajectory_direction%available = .true.
  result%accepted_trajectory_direction%accepted_steps = 2
  result%accepted_trajectory_direction%origin_t0 = result%requested_t0
  result%accepted_trajectory_direction%accepted_t1 = result%requested_t1
  result%bottom_interface_exchange_available = .true.
  result%bottom_outward_exchange_native = -0.25_real64
  result%terminal_bottom_outward_flux_native = -0.5_real64

  status_before = result%status
  completed_before = result%completed
  mass_complete_before = result%mass%complete
  lineage_before = result%mass%origin_lineage_id
  revision_before = result%mass%origin_revision
  attempts_before = result%diagnostics%attempts
  accepted_before = result%accepted_trajectory_direction%accepted_steps
  bottom_available_before = result%bottom_interface_exchange_available
  t0_bits_before = transfer(result%requested_t0, 0_int64)
  t1_bits_before = transfer(result%requested_t1, 0_int64)
  storage_bits_before = transfer(result%mass%storage_end, 0_int64)
  bottom_bits_before = transfer(result%bottom_outward_exchange_native, 0_int64)

  call serialize_canonical_result_text(result, text1)
  call serialize_canonical_result_text(result, text2)

  call require(text1 == text2, 'repeat serialization must be byte-identical')
  call require(index(text1, 'SWAP5_CANONICAL_RESULT_SNAPSHOT') == 1, 'snapshot header')
  call require(index(text1, 'mass_origin_lineage_id=991122') > 0, 'lineage serialized')
  call require(index(text1, 'accepted_trajectory_direction_accepted_steps=2') > 0, 'accepted steps serialized')
  call require(index(text1, 'bottom_interface_exchange_available=true') > 0, 'bottom availability serialized')

  call require(result%status == status_before, 'status unchanged')
  call require(result%completed .eqv. completed_before, 'completed unchanged')
  call require(result%mass%complete .eqv. mass_complete_before, 'mass complete unchanged')
  call require(result%mass%origin_lineage_id == lineage_before, 'lineage unchanged')
  call require(result%mass%origin_revision == revision_before, 'revision unchanged')
  call require(result%diagnostics%attempts == attempts_before, 'attempt count unchanged')
  call require(result%accepted_trajectory_direction%accepted_steps == accepted_before, 'accepted steps unchanged')
  call require(result%bottom_interface_exchange_available .eqv. bottom_available_before, 'bottom availability unchanged')
  call require(transfer(result%requested_t0, 0_int64) == t0_bits_before, 'requested_t0 bit identity')
  call require(transfer(result%requested_t1, 0_int64) == t1_bits_before, 'requested_t1 bit identity')
  call require(transfer(result%mass%storage_end, 0_int64) == storage_bits_before, 'storage_end bit identity')
  call require(transfer(result%bottom_outward_exchange_native, 0_int64) == bottom_bits_before, 'bottom exchange bit identity')

  write(*,'(A)') 'M1_C4_INDEPENDENT_REPEAT_DETERMINISM=PASS'
  write(*,'(A)') 'M1_C4_INDEPENDENT_RESULT_IDENTITY=PASS'
  write(*,'(A)') 'M1_C4_INDEPENDENT_TYPED_READONLY_BOUNDARY=PASS'
  write(*,'(A)') 'M1_C4_INDEPENDENT_GATE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'M1_C4_INDEPENDENT_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_m1_c4_output_serialization_independent
