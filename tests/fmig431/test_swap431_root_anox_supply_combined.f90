program test_swap431_root_anox_supply_combined
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_anaerobic_extension_gate
  use mod_crop_root_extension_supply_limit
  implicit none
  type(root_extension_supply_result_t) :: r
  logical :: allowed
  integer :: status, i
  real(real64), parameter :: tol=1.e-12_real64

  call root_extension_allowed_by_daily_oxygen(.true.,0.2_real64,0.4_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or.allowed) error stop 1
  call root_extension_allowed_by_daily_oxygen(.true.,0.4_real64,0.4_real64,allowed,status)
  if(status/=ROOT_ANOX_GATE_OK.or..not.allowed) error stop 2

  call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
    5._real64,20._real64,-10._real64,0.5_real64,0.01_real64,r,status)
  if(status/=ROOT_SUPPLY_OK) error stop 3
  if(abs(r%drought_scaled_extension_cm-2._real64)>tol) error stop 4
  if(abs(r%required_root_growth-1._real64)>tol) error stop 5
  if(abs(r%supply_factor-0.5_real64)>tol.or.abs(r%extension_cm-1._real64)>tol) error stop 6

  call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
    5._real64,20._real64,-10._real64,0._real64,0.01_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%extension_cm)>tol) error stop 7

  call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
    5._real64,20._real64,-10._real64,0.5_real64,1.01_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%extension_cm)>tol) error stop 8

  ! B1.11 min(RR, RRIMIN) permits RRIMIN above the proposed RR.
  call limit_root_extension_by_drought_and_supply(1._real64,2._real64,1._real64,0.5_real64, &
    5._real64,20._real64,-10._real64,10._real64,0.01_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%extension_cm-1._real64)>tol) error stop 11

  do i=1,100
    call root_extension_allowed_by_daily_oxygen(.false.,0.2_real64,0.4_real64,allowed,status)
    if(status/=ROOT_ANOX_GATE_OK.or..not.allowed) error stop 9
    call limit_root_extension_by_drought_and_supply(10._real64,2._real64,0.9_real64,0.5_real64, &
      5._real64,20._real64,-10._real64,0.5_real64,0.01_real64,r,status)
    if(status/=ROOT_SUPPLY_OK.or.abs(r%extension_cm-1._real64)>tol) error stop 10
  end do
  print '(a)','ROOT_ANOX_SUPPLY_COMBINED=PASS'
end program
