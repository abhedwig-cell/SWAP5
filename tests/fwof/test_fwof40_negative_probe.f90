program test_fwof40_negative_probe
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fwof40_external_crop_restart_adapter
  implicit none
  character(len=512) :: path
  type(kernel_committed_state_t) :: committed
  logical :: restored
  integer :: status

  call get_command_argument(1, path)
  if (len_trim(path) == 0) error stop 'F-WOF40 negative probe path missing'
  call read_fwof40_crop_restart_artifact(trim(path), committed, restored, status)
  if (restored) then
    write(*,'(A,I0)') 'FWOF40_NEGATIVE_UNEXPECTED_ACCEPT status=', status
    error stop 1
  end if
  if (committed%ready()) then
    write(*,'(A,I0)') 'FWOF40_NEGATIVE_UNEXPECTED_ACCEPT status=', status
    error stop 1
  end if
  if (status == FWO40_EXTERNAL_OK) then
    write(*,'(A,I0)') 'FWOF40_NEGATIVE_UNEXPECTED_ACCEPT status=', status
    error stop 1
  end if
  write(*,'(A,I0,A)') 'FWOF40_NEGATIVE_EXPECTED_REJECTION status=', status, ' PASS'
end program test_fwof40_negative_probe
