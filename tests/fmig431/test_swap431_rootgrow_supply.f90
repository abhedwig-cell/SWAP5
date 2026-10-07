program test_swap431_rootgrow_supply
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_extension_supply_limit
  implicit none

  type(root_extension_supply_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  ! No drought and enough assimilate supply: proposed extension survives.
  call limit_root_extension_by_drought_and_supply(5.0_real64,1.0_real64,0.0_real64,0.5_real64, &
       2.0_real64,20.0_real64,-10.0_real64,2.0_real64,1.0e-8_real64,r,status)
  if(status/=ROOT_SUPPLY_OK) error stop 1
  if(abs(r%drought_scaled_extension_cm-5.0_real64)>tol.or.abs(r%extension_cm-5.0_real64)>tol) error stop 2
  if(abs(r%required_root_growth-1.0_real64)>tol.or.abs(r%supply_factor-1.0_real64)>tol) error stop 3

  ! Full drought falls back to RRIMIN.
  call limit_root_extension_by_drought_and_supply(5.0_real64,1.0_real64,1.0_real64,0.5_real64, &
       2.0_real64,20.0_real64,-10.0_real64,2.0_real64,1.0e-8_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%drought_scaled_extension_cm-1.0_real64)>tol) error stop 4
  if(abs(r%extension_cm-1.0_real64)>tol) error stop 5

  ! Intermediate drought: RR * min(1,(1-IALPDRY)/EXTENTCRIT).
  call limit_root_extension_by_drought_and_supply(5.0_real64,1.0_real64,0.75_real64,0.5_real64, &
       2.0_real64,20.0_real64,-10.0_real64,2.0_real64,1.0e-8_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%drought_scaled_extension_cm-2.5_real64)>tol) error stop 6

  ! Assimilate supply limits the drought-scaled extension proportionally.
  call limit_root_extension_by_drought_and_supply(5.0_real64,1.0_real64,0.0_real64,0.5_real64, &
       4.0_real64,20.0_real64,-10.0_real64,0.5_real64,1.0e-8_real64,r,status)
  if(status/=ROOT_SUPPLY_OK) error stop 7
  if(abs(r%required_root_growth-2.0_real64)>tol) error stop 8
  if(abs(r%supply_factor-0.25_real64)>tol.or.abs(r%extension_cm-1.25_real64)>tol) error stop 9

  ! Source SMALL cutoff is applied after supply limitation.
  call limit_root_extension_by_drought_and_supply(5.0_real64,0.0_real64,0.0_real64,0.5_real64, &
       4.0_real64,20.0_real64,-10.0_real64,1.0e-12_real64,1.0e-6_real64,r,status)
  if(status/=ROOT_SUPPLY_OK.or.abs(r%extension_cm)>tol) error stop 10

  print '(a)','SW431_CROP_ROOTGROW_SUPPLY=PASS'
end program
