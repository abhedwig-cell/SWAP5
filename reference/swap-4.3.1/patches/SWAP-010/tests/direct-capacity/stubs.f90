module MOD_arrays
  implicit none
  integer, parameter :: maho = 10
end module MOD_arrays

module MOD_grid
  implicit none
  integer :: layer = 1
end module MOD_grid

subroutine swap_error(routine, message)
  implicit none
  character(*), intent(in) :: routine, message
  write(*,*) trim(routine), ': ', trim(message)
  error stop 1
end subroutine swap_error
