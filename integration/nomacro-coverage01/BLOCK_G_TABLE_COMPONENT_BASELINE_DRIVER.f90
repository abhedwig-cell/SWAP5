! Calls the exact original PreProcTabulatedFunction implementation.
program original_table_preprocess
  use MOD_arrays, only: matab
  use doTSPACK, only: IER
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  real(8) :: x(matab), y(matab), k(matab), d(matab), sigma(matab)
  integer :: i, n, ios, flag
  character(len=1024) :: filename, header
  call get_command_argument(1,filename)
  open(10,file=trim(filename),status='old',action='read')
  read(10,'(a)')header
  x=0d0;y=0d0;k=0d0;n=0
  do i=1,matab
    read(10,*,iostat=ios)x(i),y(i),k(i)
    if(ios<0)exit
    if(ios/=0)error stop 'Invalid original table input'
    n=n+1
  end do
  close(10)
  ! Identical original readswap transformation into the component contract.
  x(1:n)=-log(-x(1:n)+1d0)
  do flag=1,2
    if(flag==2)y(1:n)=log(k(1:n))
    write(*,*)'BEFORE_ORIGINAL_PREPROCESS',flag,n
    flush(6)
    call PreProcTabulatedFunction(flag,n,x,y,d,sigma)
    write(*,*)'AFTER_ORIGINAL_PREPROCESS',flag,IER
    if(.not.all(ieee_is_finite(d(1:n))).or..not.all(ieee_is_finite(sigma(1:n)))) &
      error stop 'Nonfinite original table coefficients'
    flush(6)
  end do
end program
