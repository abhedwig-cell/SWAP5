program test_bartholomeus_root_sink_modifier
   use iso_fortran_env, only : real64
   use mod_bartholomeus_root_sink_modifier
   implicit none
   real(real64), allocatable :: out(:)
   real(real64) :: base(4), oxygen(4)
   integer :: status

   base = [0.0_real64, 1.0_real64, 2.0_real64, 4.0_real64]
   oxygen = [1.0_real64, 0.75_real64, 0.5_real64, 0.0_real64]
   call apply_bartholomeus_root_sink_modifier(base,oxygen,out,status)
   if (status /= OXYGEN_MODIFIER_OK) error stop 1
   if (maxval(abs(out-[0.0_real64,0.75_real64,1.0_real64,0.0_real64])) > 1.0e-15_real64) error stop 2

   ! The modifier never creates uptake and never changes ownership/sign.
   if (any(out > base)) error stop 3
   if (any(out < 0.0_real64)) error stop 4

   oxygen(2) = 1.01_real64
   call apply_bartholomeus_root_sink_modifier(base,oxygen,out,status)
   if (status /= OXYGEN_MODIFIER_INVALID_INPUT) error stop 5

   print '(a)', 'PPA_WU05C3P_ROOT_SINK_MODIFIER=PASS'
end program test_bartholomeus_root_sink_modifier
