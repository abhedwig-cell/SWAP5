program test_root_invalid_edge_local
 use, intrinsic :: iso_fortran_env, only: real64
 use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
 use mod_crop_root_anaerobic_extension_gate
 use mod_crop_root_extension_supply_limit
 implicit none
 real(real64) :: special(2), x(9)
 type(root_extension_supply_result_t) :: r
 logical :: allowed
 integer :: stat,i,k
 special(1)=ieee_value(0._real64,ieee_quiet_nan)
 special(2)=ieee_value(0._real64,ieee_positive_inf)
 do k=1,2
  call root_extension_allowed_by_daily_oxygen(.true.,special(k),0.4_real64,allowed,stat)
  if(stat/=ROOT_ANOX_GATE_INVALID_INPUT.or.allowed) error stop 1
  call root_extension_allowed_by_daily_oxygen(.true.,0.4_real64,special(k),allowed,stat)
  if(stat/=ROOT_ANOX_GATE_INVALID_INPUT.or.allowed) error stop 2
  do i=1,9
   x=[10._real64,2._real64,0.9_real64,0.5_real64,5._real64, &
      20._real64,-10._real64,0.5_real64,0.01_real64]
   x(i)=special(k)
   call limit_root_extension_by_drought_and_supply(x(1),x(2),x(3),x(4), &
     x(5),x(6),x(7),x(8),x(9),r,stat)
   if(stat/=ROOT_SUPPLY_INVALID_INPUT) error stop 3
   if(abs(r%extension_cm)>1.e-15_real64.or.abs(r%required_root_growth)>1.e-15_real64) error stop 4
  end do
 end do
 call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
  5._real64,20._real64,-20._real64,0.5_real64,0.01_real64,r,stat)
 if(stat/=ROOT_SUPPLY_INVALID_INPUT.or.abs(r%extension_cm)>1.e-15_real64) error stop 5
 print '(a)','ROOT_INVALID_EDGE_MATRIX=PASS'
end program
