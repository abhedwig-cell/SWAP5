module MOD_arrays
  implicit none
  integer, parameter :: maho = 10
end module MOD_arrays

module MOD_grid
  implicit none
  integer :: layer(100) = 1
end module MOD_grid

subroutine swap_error(where, message)
  implicit none
  character(len=*), intent(in) :: where, message
  write(*,'(a)') 'SWAP_ERROR ['//trim(where)//']: '//trim(message)
  error stop 99
end subroutine swap_error
