module MOD_texture_orgmat
  implicit none
  real(8)::bdens(1)
end module
subroutine swap_error(a,b)
  implicit none
  character(*),intent(in)::a,b
  print *,a,b
  error stop 1
end subroutine
program test_negative
  use MOD_texture_orgmat
  implicit none
  real(8)::x(18),ce,ca,actual,unmet,tau,orig_c,orig_a,p
  integer::code,ios
  do
    read(*,*,iostat=ios)x
    if(ios/=0)exit
    bdens(1)=x(18)
    call Wofost_SoilWaterN_Negative(x(1),x(2),x(3),x(4),x(5),x(6),x(7),x(8),x(9), &
         x(10),x(11),x(12),x(13),x(14),x(15),x(16),x(17),ce,ca,actual,unmet,tau,code)
    orig_c=0d0;orig_a=0d0
    if(code==0.and.unmet==0d0)call Wofost_SoilWaterN(x(1),x(2),x(3),x(4),x(5),x(6),x(7), &
         x(8),x(9),x(10),x(11),x(12),p,x(13),x(14),x(15),x(16),x(17),orig_c,orig_a)
    write(*,'(i2,7(1x,es25.16))')code,ce,ca,actual,unmet,tau,orig_c,orig_a
  end do
end program
