program test_bartholomeus_root_uptake_composition
   use iso_fortran_env, only : real64
   use mod_bartholomeus_root_uptake_composition
   implicit none
   real(real64) :: base(3),factor(3)
   real(real64), allocatable :: final(:)
   integer :: status

   base=[1.0_real64,2.0_real64,3.0_real64]
   factor=[1.0_real64,0.5_real64,0.0_real64]
   call apply_bartholomeus_reduction(base,factor,final,status)
   if(status/=BARTHOLOMEUS_COMPOSE_OK) error stop 1
   if(maxval(abs(final-[1.0_real64,1.0_real64,0.0_real64]))>epsilon(1.0_real64)) error stop 2

   factor(2)=1.1_real64
   call apply_bartholomeus_reduction(base,factor,final,status)
   if(status/=BARTHOLOMEUS_COMPOSE_INVALID) error stop 3

   print '(a)', 'PPA_WU05C3Q_ROOT_COMPOSITION=PASS'
end program
