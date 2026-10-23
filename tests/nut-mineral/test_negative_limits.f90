program test_negative_limits
 use iso_fortran_env,only:real64
 use mod_b111_soil_n_transport
 implicit none
 real(real64)::x(16)
 integer::ios
 type(b111_soil_n_transport_result_t)::r
 do
  read(*,*,iostat=ios)x
  if(ios/=0)exit
  call evaluate_b111_soil_n_negative_boundary(x(1),x(2),x(3),x(4),x(5),x(6),x(7),x(8), &
   x(9),x(10),x(11),x(12),x(13),x(14),x(15),x(16),r)
  write(*,'(2(I0,1X),5(ES26.17E3,1X))')r%status,r%solution_class,r%concentration_end, &
   r%concentration_average,r%top_actual_rate,r%top_unmet,r%depletion_time
 end do
end program
