program test_fkt13_trusted_reconstruction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reconstruct_committed_state_trusted, &
       KERNEL_TRUSTED_RECONSTRUCTION_OK, KERNEL_TRUSTED_RECONSTRUCTION_TARGET_INITIALIZED
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       KERNEL_PERSISTENCE_SCHEMA_VERSION, KERNEL_PERSISTENCE_OK, KERNEL_PERSISTENCE_SCHEMA_MISMATCH, &
       KERNEL_PERSISTENCE_INVALID_LAYOUT, KERNEL_PERSISTENCE_INVALID_PROVENANCE, &
       KERNEL_PERSISTENCE_INVALID_PHYSICAL_STATE, KERNEL_PERSISTENCE_INVALID_TIME, &
       KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED, reconstruct_kernel_persistence_snapshot_trusted, &
       restore_kernel_committed_state
  use mod_fkt13_process_support, only: fkt13_new_physical, FKT13_LAYOUT_ID, FKT13_LINEAGE_ID, FKT13_T1
  implicit none

  class(transaction_state_t), allocatable :: physical, missing_physical
  type(kernel_persistence_snapshot_t) :: snapshot
  type(kernel_committed_state_t) :: restored, initialized_target
  logical :: ok
  integer :: status

  call fkt13_new_physical(physical, 0.95_real64)

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, FKT13_LAYOUT_ID, &
       FKT13_LINEAGE_ID, 1_int64, FKT13_T1, .true., physical, snapshot, ok, status)
  if (.not. ok .or. status /= KERNEL_PERSISTENCE_OK) error stop 'FKT13 valid trusted reconstruction rejected'
  if (.not. snapshot%ready()) error stop 'FKT13 valid reconstructed snapshot not ready'
  if (snapshot%current_revision() /= 1_int64) error stop 'FKT13 valid reconstructed revision mismatch'
  if (snapshot%current_lineage_id() /= FKT13_LINEAGE_ID) error stop 'FKT13 valid reconstructed lineage mismatch'

  call restore_kernel_committed_state(snapshot, FKT13_LAYOUT_ID, restored, ok, status)
  if (.not. ok .or. status /= KERNEL_PERSISTENCE_OK) error stop 'FKT13 valid reconstructed snapshot restore failed'
  call restore_kernel_committed_state(snapshot, FKT13_LAYOUT_ID, restored, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED) &
       error stop 'FKT13 initialized restore target did not fail closed'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION + 1, FKT13_LAYOUT_ID, &
       FKT13_LINEAGE_ID, 1_int64, FKT13_T1, .true., physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_SCHEMA_MISMATCH) error stop 'FKT13 wrong schema not rejected'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, 0_int64, &
       FKT13_LINEAGE_ID, 1_int64, FKT13_T1, .true., physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_INVALID_LAYOUT) error stop 'FKT13 invalid layout not rejected'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, FKT13_LAYOUT_ID, &
       0_int64, 1_int64, FKT13_T1, .true., physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_INVALID_PROVENANCE) error stop 'FKT13 invalid lineage not rejected'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, FKT13_LAYOUT_ID, &
       FKT13_LINEAGE_ID, -1_int64, FKT13_T1, .true., physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_INVALID_PROVENANCE) error stop 'FKT13 invalid revision not rejected'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, FKT13_LAYOUT_ID, &
       FKT13_LINEAGE_ID, 1_int64, FKT13_T1, .false., physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_INVALID_TIME) error stop 'FKT13 inconsistent unbound time not rejected'

  call reconstruct_kernel_persistence_snapshot_trusted(KERNEL_PERSISTENCE_SCHEMA_VERSION, FKT13_LAYOUT_ID, &
       FKT13_LINEAGE_ID, 1_int64, FKT13_T1, .true., missing_physical, snapshot, ok, status)
  if (ok .or. status /= KERNEL_PERSISTENCE_INVALID_PHYSICAL_STATE) &
       error stop 'FKT13 missing physical state not rejected'

  call kernel_reconstruct_committed_state_trusted(initialized_target, FKT13_LINEAGE_ID, 1_int64, physical, &
       FKT13_T1, .true., ok, status)
  if (.not. ok .or. status /= KERNEL_TRUSTED_RECONSTRUCTION_OK) &
       error stop 'FKT13 direct atomic trusted reconstruction failed'
  call kernel_reconstruct_committed_state_trusted(initialized_target, FKT13_LINEAGE_ID, 2_int64, physical, &
       FKT13_T1, .true., ok, status)
  if (ok .or. status /= KERNEL_TRUSTED_RECONSTRUCTION_TARGET_INITIALIZED) &
       error stop 'FKT13 direct atomic overwrite did not fail closed'

  write(*,'(A)') 'FKT13_ATOMIC_TRUSTED_RECONSTRUCTION_VALID=PASS'
  write(*,'(A)') 'FKT13_NO_INDEPENDENT_OVERWRITE_PATH=PASS'
  write(*,'(A)') 'FKT13_SCHEMA_LAYOUT_PROVENANCE_PHYSICAL_TIME_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FKT13_TRUSTED_RECONSTRUCTION_UNIT_GATE PASS'
end program test_fkt13_trusted_reconstruction
