program fkt13_negative_probe
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t
  use mod_fkt13_process_support, only: FKT13_LAYOUT_ID
  use mod_fkt13_persistence_adapter, only: fkt13_read_artifact
  implicit none

  type(kernel_persistence_snapshot_t) :: snapshot
  logical :: imported
  integer :: status, expected_status, ios
  character(len=1024) :: artifact_path, expected_text

  if (command_argument_count() /= 2) error stop 'FKT13 negative probe requires artifact path and expected status'
  call get_command_argument(1, artifact_path)
  call get_command_argument(2, expected_text)
  read(expected_text,*,iostat=ios) expected_status
  if (ios /= 0) error stop 'FKT13 negative probe expected status parse failed'

  call fkt13_read_artifact(trim(artifact_path), FKT13_LAYOUT_ID, snapshot, imported, status)
  if (imported) error stop 'FKT13 corrupted artifact unexpectedly imported'
  if (snapshot%ready()) error stop 'FKT13 rejected artifact produced ready carrier'
  if (status /= expected_status) then
    write(*,'(A,I0,A,I0)') 'FKT13 negative status mismatch actual=', status, ' expected=', expected_status
    error stop 1
  end if

  write(*,'(A,I0,A)') 'FKT13_NEGATIVE_EXPECTED_REJECTION status=', status, ' PASS'
end program fkt13_negative_probe
