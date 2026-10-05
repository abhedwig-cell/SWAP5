program test_mig431_water_limits
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_irrigation_water_limits
  implicit none
  type(irrigation_retention_parameters_t) :: vg(3)
  real(real64), allocatable :: fc(:),mid(:),wp(:)
  integer :: status
  vg%theta_residual = 0.05_real64
  vg%theta_saturated = 0.4_real64
  vg%alpha = 0.02_real64
  vg%n = 2.0_real64
  vg%m = 0.5_real64
  vg(1)%alpha = 0.5_real64
  call derive_irrigation_water_limits(vg,[2,3],-50.0_real64,-100.0_real64,-500.0_real64, &
       fc,mid,wp,status)
  if (status /= IRRIGATION_LIMITS_OK) error stop 1
  if (abs(fc(1)-(0.05_real64+0.35_real64/sqrt(2.0_real64))) > 1.e-12_real64) error stop 2
  if (fc(1) /= fc(2) .or. fc(2) <= mid(2) .or. mid(2) <= wp(2)) error stop 3
  call derive_irrigation_water_limits(vg,[1,1,3],-50.0_real64,-100.0_real64,-500.0_real64, &
       fc,mid,wp,status)
  if (status /= IRRIGATION_LIMITS_INVALID .or. allocated(fc)) error stop 4
  print '(a)', 'F_MIG431_IRRIGATION_RETENTION_LIMITS=PASS'
end program
