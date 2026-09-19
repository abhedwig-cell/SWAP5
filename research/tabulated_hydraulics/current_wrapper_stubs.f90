module error_mod
  implicit none
contains
  subroutine fatalerr_collected(routine_name, message)
    character(len=*), intent(in) :: routine_name, message
    write(*,'(A,1X,A,1X,A)') 'FATALERR_COLLECTED', trim(routine_name), trim(message)
    error stop 91
  end subroutine fatalerr_collected
end module error_mod

module variables
  use iso_fortran_env, only: real64
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none
  real(real64) :: cofgen(24,macp) = 0.0_real64
  integer :: swsophy = 1
  integer :: numtab(macp) = 0
  real(real64) :: sptab(7,macp,matab) = 0.0_real64
  integer :: ientrytab(macp,0:matabentries) = 0
  integer :: iHWCKmodel(macp) = 1
  integer :: layer(macp) = 1
  integer :: swfrost = 0
  real(real64) :: dt = 0.1_real64
  logical :: fluseksatexm(macp) = .false.
  real(real64) :: tsoil(macp) = 10.0_real64
end module variables

module WC_K_models_04_11
  use iso_fortran_env, only: real64
  implicit none
contains
  real(real64) function functionvalue_04_11(which, node, head, wc, temp)
    integer, intent(in) :: which, node
    real(real64), intent(in) :: head
    real(real64), intent(in), optional :: wc, temp
    functionvalue_04_11 = 0.0_real64
  end function functionvalue_04_11
end module WC_K_models_04_11
