program test_root_invalid_edge_local
 use, intrinsic :: iso_fortran_env, only: real64
 use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
 use mod_crop_root_anaerobic_extension_gate
 use mod_crop_root_extension_supply_limit
 implicit none
 real(real64) :: nan
 type(root_extension_supply_result_t) :: r
 logical :: allowed
 integer :: stat
 nan=ieee_value(0._real64,ieee_quiet_nan)
 call root_extension_allowed_by_daily_oxygen(.true.,nan,0.4_real64,allowed,stat)
 if(stat/=ROOT_ANOX_GATE_INVALID_INPUT.or.allowed) error stop 1
 call root_extension_allowed_by_daily_oxygen(.true.,0.4_real64,nan,allowed,stat)
 if(stat/=ROOT_ANOX_GATE_INVALID_INPUT.or.allowed) error stop 2
 call limit_root_extension_by_drought_and_supply(10._real64,2._real64,nan,0.5_real64, &
  5._real64,20._real64,-10._real64,0.5_real64,0.01_real64,r,stat)
 if(stat/=ROOT_SUPPLY_INVALID_INPUT.or.abs(r%extension_cm)>1.e-12_real64) error stop 3
 call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
  5._real64,20._real64,-20._real64,0.5_real64,0.01_real64,r,stat)
 if(stat/=ROOT_SUPPLY_INVALID_INPUT.or.abs(r%extension_cm)>1.e-12_real64) error stop 4
 print '(a)','ROOT_INVALID_EDGE_LOCAL=PASS'
end program
