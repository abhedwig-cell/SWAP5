program test_decay_fractions
 use iso_fortran_env,only:real64,iostat_end
 use mod_b111_soil_organic_turnover,only:b111_decay_fractions
 implicit none
 real(real64)::x,loss,average
 integer::ios,code
 do
  read(*,*,iostat=ios)x
  if(ios==iostat_end)exit
  if(ios/=0)error stop 1
  call b111_decay_fractions(x,loss,average,code)
  write(*,'(I3,2(1X,ES26.17E3))')code,loss,average
 end do
end program
