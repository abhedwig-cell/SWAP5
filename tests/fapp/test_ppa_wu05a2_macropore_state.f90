program test_ppa_wu05a2_macropore_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05a2_macropore_state
  implicit none

  type(ppa_wu05a2_macropore_committed_t) :: committed, roundtrip
  type(ppa_wu05a2_macropore_checkpoint_t) :: checkpoint
  type(ppa_wu05a2_macropore_candidate_t) :: candidate, stale_candidate, retry_candidate
  type(ppa_wu05a2_macropore_restart_t) :: restart, malformed_restart
  type(ppa_wu05a2_macropore_restart_t), allocatable :: optional_restart
  type(ppa_wu05a2_macropore_payload_t) :: original_payload
  logical :: accepted, exported, restored

  call ppa_wu05a2_initialize_payload(2, 4, committed%payload, accepted)
  call require(accepted, 'initialize full state layout')
  committed%lineage_id = 91_int64
  committed%revision = 7_int64
  call seed_state(committed%payload)
  original_payload = committed%payload

  call ppa_wu05a2_capture_checkpoint(committed, checkpoint, accepted)
  call require(accepted, 'capture committed checkpoint')
  committed%lineage_id = 92_int64
  call ppa_wu05a2_restore_checkpoint(checkpoint, committed, accepted)
  call require(.not. accepted .and. committed%lineage_id == 92_int64, 'foreign checkpoint cannot replace state owner')
  committed%lineage_id = 91_int64
  call ppa_wu05a2_begin_candidate(checkpoint, candidate, accepted)
  call require(accepted .and. candidate%valid, 'begin isolated candidate')
  call mutate_all_fields(candidate%payload)
  call require(payload_equal(committed%payload, original_payload), 'candidate writes do not leak to committed state')

  call ppa_wu05a2_restore_checkpoint(checkpoint, committed, accepted)
  call require(accepted .and. payload_equal(committed%payload, original_payload), &
       'rollback restores every continuation/history field')
  call ppa_wu05a2_discard_candidate(candidate)
  call require(.not. candidate%valid, 'rejected candidate is discarded')

  call ppa_wu05a2_begin_candidate(checkpoint, retry_candidate, accepted)
  call require(accepted .and. payload_equal(retry_candidate%payload, original_payload), 'retry starts from identical checkpoint')
  call ppa_wu05a2_begin_candidate(checkpoint, stale_candidate, accepted)
  call require(accepted, 'capture stale candidate for concurrency guard')
  retry_candidate%payload%domain_water_storage(1) = retry_candidate%payload%domain_water_storage(1) + 0.25_real64
  call ppa_wu05a2_commit_candidate(retry_candidate, committed, accepted)
  call require(accepted .and. committed%revision == 8_int64, 'accepted candidate advances revision once')
  call ppa_wu05a2_commit_candidate(stale_candidate, committed, accepted)
  call require(.not. accepted .and. committed%revision == 8_int64, 'stale candidate cannot overwrite successor')

  call ppa_wu05a2_export_restart(committed, restart, exported)
  call require(exported, 'export complete restart record')
  allocate(optional_restart)
  optional_restart = restart
  call require(ppa_wu05a2_optional_restart_complete(optional_restart, .true., 2, 4), &
       'export complete optional restart layout')
  call ppa_wu05a2_restore_restart(restart, roundtrip, restored)
  call require(restored .and. committed_equal(roundtrip, committed), 'restart roundtrip preserves full state and revision')
  call require(ppa_wu05a2_optional_restart_complete(optional_restart, .true., 2, 4), 'active route requires matching state layout')
  call require(.not. ppa_wu05a2_optional_restart_complete(optional_restart, .false., 2, 4), &
       'inactive route rejects incompatible optional state')
  deallocate(optional_restart)
  call require(ppa_wu05a2_optional_restart_complete(optional_restart, .false., 2, 4), 'inactive route accepts absent layout')
  call require(.not. ppa_wu05a2_optional_restart_complete(optional_restart, .true., 2, 4), 'active route rejects absent layout')
  restart%schema_version = PPA_WU05A2_SCHEMA_VERSION + 1
  call ppa_wu05a2_restore_restart(restart, roundtrip, restored)
  call require(.not. restored, 'unknown restart schema fails closed')
  restart%schema_version = PPA_WU05A2_SCHEMA_VERSION
  restart%committed%payload%n_compartments = 99
  allocate(optional_restart)
  optional_restart = restart
  call require(.not. ppa_wu05a2_optional_restart_complete(optional_restart, .true., 2, 4), &
       'restart shape mismatch fails closed')
  malformed_restart = restart
  malformed_restart%committed%payload%n_compartments = 4
  malformed_restart%committed%payload%domain_water_storage(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  optional_restart = malformed_restart
  call require(.not. ppa_wu05a2_optional_restart_complete(optional_restart, .true., 2, 4), &
       'non-finite restart payload fails closed')

  print '(a)', 'PPA_WU05A2_TYPED_CONTINUATION_LAYOUT=PASS'
  print '(a)', 'PPA_WU05A2_ALL_FIELD_ROLLBACK_AND_RETRY=PASS'
  print '(a)', 'PPA_WU05A2_CANDIDATE_REVISION_GUARD=PASS'
  print '(a)', 'PPA_WU05A2_OPTIONAL_RESTART_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU05A2_FOREIGN_LINEAGE_AND_NONFINITE_GUARDS=PASS'

contains

  subroutine seed_state(state)
    type(ppa_wu05a2_macropore_payload_t), intent(inout) :: state
    integer :: id, ic
    do id = 1, state%n_domains
      state%bottom_domain(id) = 3 + id - 1
      state%bottom_domain_previous(id) = 2 + id - 1
      state%domain_water_storage(id) = 0.4_real64 * id
      do ic = 1, state%n_compartments
        state%pore_volume(id,ic) = 0.1_real64 * (id + ic)
        state%pore_volume_previous(id,ic) = 0.09_real64 * (id + ic)
        state%pore_water(id,ic) = 0.03_real64 * (id + ic)
        state%pore_water_previous(id,ic) = 0.02_real64 * (id + ic)
        state%sorptivity_reference(id,ic) = 0.7_real64 + 0.01_real64 * (id + ic)
        state%sorptivity(id,ic) = 0.08_real64 * (id + ic)
        state%absorption_time(id,ic) = 0.5_real64 * (id + ic)
        state%sorptivity_event_ended(id,ic) = mod(id + ic, 2) == 0
      end do
    end do
  end subroutine seed_state

  subroutine mutate_all_fields(state)
    type(ppa_wu05a2_macropore_payload_t), intent(inout) :: state
    state%bottom_domain = 0
    state%bottom_domain_previous = 0
    state%domain_water_storage = -1.0_real64
    state%pore_volume = -2.0_real64
    state%pore_volume_previous = -3.0_real64
    state%pore_water = -4.0_real64
    state%pore_water_previous = -5.0_real64
    state%sorptivity_reference = -6.0_real64
    state%sorptivity = -7.0_real64
    state%absorption_time = -8.0_real64
    state%sorptivity_event_ended = .not. state%sorptivity_event_ended
  end subroutine mutate_all_fields

  pure logical function payload_equal(left, right)
    type(ppa_wu05a2_macropore_payload_t), intent(in) :: left, right
    payload_equal = left%ready() .and. right%ready()
    if (.not. payload_equal) return
    payload_equal = left%n_domains == right%n_domains .and. left%n_compartments == right%n_compartments .and. &
         all(left%bottom_domain == right%bottom_domain) .and. &
         all(left%bottom_domain_previous == right%bottom_domain_previous) .and. &
         real1_bits_equal(left%domain_water_storage, right%domain_water_storage) .and. &
         real2_bits_equal(left%pore_volume, right%pore_volume) .and. &
         real2_bits_equal(left%pore_volume_previous, right%pore_volume_previous) .and. &
         real2_bits_equal(left%pore_water, right%pore_water) .and. &
         real2_bits_equal(left%pore_water_previous, right%pore_water_previous) .and. &
         real2_bits_equal(left%sorptivity_reference, right%sorptivity_reference) .and. &
         real2_bits_equal(left%sorptivity, right%sorptivity) .and. &
         real2_bits_equal(left%absorption_time, right%absorption_time) .and. &
         all(left%sorptivity_event_ended .eqv. right%sorptivity_event_ended)
  end function payload_equal

  pure logical function real1_bits_equal(left, right)
    real(real64), intent(in) :: left(:), right(:)
    integer(int64) :: left_bits(size(left)), right_bits(size(right))
    real1_bits_equal = .false.
    if (size(left) /= size(right)) return
    left_bits = transfer(left, left_bits, size(left))
    right_bits = transfer(right, right_bits, size(right))
    real1_bits_equal = all(left_bits == right_bits)
  end function real1_bits_equal

  pure logical function real2_bits_equal(left, right)
    real(real64), intent(in) :: left(:,:), right(:,:)
    integer(int64) :: left_bits(size(left)), right_bits(size(right))
    real2_bits_equal = .false.
    if (any(shape(left) /= shape(right))) return
    left_bits = transfer(left, left_bits, size(left))
    right_bits = transfer(right, right_bits, size(right))
    real2_bits_equal = all(left_bits == right_bits)
  end function real2_bits_equal

  pure logical function committed_equal(left, right)
    type(ppa_wu05a2_macropore_committed_t), intent(in) :: left, right
    committed_equal = left%lineage_id == right%lineage_id .and. left%revision == right%revision .and. &
         payload_equal(left%payload, right%payload)
  end function committed_equal

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (condition) return
    write(*,'(a,1x,a)') 'PPA_WU05A2_FAIL', trim(label)
    error stop 1
  end subroutine require

end program test_ppa_wu05a2_macropore_state
