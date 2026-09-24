module variables
  implicit none
  real(8) :: cofgen(42,100)=0.0d0
  integer :: iHWCKmodel(10)=1
  logical :: BiModal(10)=.false., NoVap(10)=.false.
  integer :: layer(100)=1
end module variables

module error_mod
  implicit none
contains
  subroutine fatalerr_collected(where,message)
    character(len=*),intent(in)::where,message
    write(*,'(A,1X,A,1X,A)') 'FATAL',trim(where),trim(message)
    error stop 99
  end subroutine
end module error_mod
