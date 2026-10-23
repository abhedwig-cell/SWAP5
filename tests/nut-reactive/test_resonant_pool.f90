program test_zero_pool_rates
 use iso_fortran_env,only:real64,iostat_end
 use mod_b111_soil_organic_turnover
 use mod_b111_soil_organic_dissimilation
 implicit none
 type(b111_organic_turnover_parameters_t)::p
 type(b111_organic_turnover_result_t)::r
 type(b111_organic_dissimilation_result_t)::d
 real(real64)::x(12),v(7)
 integer::ios
 do
  read(*,*,iostat=ios)x
  if(ios==iostat_end)exit
  if(ios/=0)error stop 1
  p%ratecon_fom=x(1:2);p%ratecon_bio=x(3);p%ratecon_hum=x(4)
  p%asfa_fom_bio=[.2d0,.25d0];p%asfa_fom_hum=[.15d0,.1d0];p%asfa_bio=x(11);p%asfa_hum=x(12)
  call evaluate_b111_organic_turnover(x(5:6),x(7),x(8),x(9),p,r)
  call evaluate_b111_organic_dissimilation(x(5:6),x(7),x(8),x(10),x(9),p,r,[.45d0,.45d0],.45d0,.45d0,d)
  v=0d0
  if(allocated(r%fom_kg_m3))v(1:2)=r%fom_kg_m3
  v(3:4)=[r%biomass_kg_m3,r%humus_kg_m3]
  v(5:7)=[d%biomass_average_kg_m3,d%humus_average_kg_m3,d%carbon_dissimilation_kg_m2]
  write(*,'(2(I3,1X),7(ES26.17E3,1X))')r%status,d%status,v
 end do
end program
