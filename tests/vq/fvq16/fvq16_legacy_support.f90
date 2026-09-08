module MOD_swap_base
  implicit none
  logical :: fl_initialize = .false.
end module MOD_swap_base

subroutine swap_error(routine_name, message)
  implicit none
  character(len=*), intent(in) :: routine_name, message
  error stop trim(routine_name) // ': ' // trim(message)
end subroutine swap_error
