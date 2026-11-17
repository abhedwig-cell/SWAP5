program decimal_words
 use iso_fortran_env,only:int64
 implicit none
 integer::n,i,total=0,ios
 real(8)::a(501),b(501)
 do
  read(*,*,iostat=ios)n
  if(ios<0)exit
  if(ios/=0.or.n<1.or.n>501)error stop 'Invalid shape'
  read(*,*)a(1:n)
  read(*,*)b(1:n)
  do i=1,n
   if(transfer(a(i),0_int64)/=transfer(b(i),0_int64))error stop 'Different kernel input bits'
  enddo
  total=total+n
 enddo
 print *,'ACTUAL_FORTRAN_DECIMAL_WORD_BITS_EXACT',total
end program
