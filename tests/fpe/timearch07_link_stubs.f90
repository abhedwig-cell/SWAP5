subroutine swap_error(where,message)
  character(len=*),intent(in) :: where,message
  write(*,'(A,1X,A,1X,A)') 'TIMEARCH07_UNEXPECTED_SWAP_ERROR',trim(where),trim(message)
  error stop 1
end subroutine swap_error

subroutine swap_warning(where,message)
  character(len=*),intent(in) :: where,message
end subroutine swap_warning

subroutine dtdpar(value,datea,fsec)
  real(8),intent(in) :: value
  integer,intent(out) :: datea(6)
  real(4),intent(out) :: fsec
  datea=0
  datea(1)=2000
  datea(2)=1
  datea(3)=1
  fsec=0.0
end subroutine dtdpar

subroutine dtardp(datea,fsec,value)
  integer,intent(in) :: datea(6)
  real(4),intent(in) :: fsec
  real(8),intent(out) :: value
  value=0.0d0
end subroutine dtardp

subroutine dtdpst(fmt,value,text)
  character(len=*),intent(in) :: fmt
  real(8),intent(in) :: value
  character(len=*),intent(out) :: text
  text='2000-01-01'
end subroutine dtdpst

subroutine writehead(unit_a,unit_b,label,filtext,project)
  integer,intent(in) :: unit_a,unit_b
  character(len=*),intent(in) :: label,filtext,project
end subroutine writehead
