program test_ppa_micro07_stress_factors
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_root_micro_stress_factors
  implicit none
  type(micro_stress_parameters_t) :: p
  real(real64), allocatable :: factors(:)
  real(real64) :: head(5), salt(5), expected(5)
  integer :: status

  p%oxygen_mode=1
  p%salinity_mode=1
  p%upper_compartment_last_node=2
  p%wet_limit_cm=-10.0_real64
  p%upper_oxygen_limit_cm=-100.0_real64
  p%lower_oxygen_limit_cm=-200.0_real64
  p%salt_threshold=2.0_real64
  p%salt_slope=0.2_real64
  head=[-5.0_real64,-55.0_real64,-105.0_real64,-250.0_real64,100.0_real64]
  salt=[0.0_real64,3.0_real64,6.0_real64,2.0_real64,100.0_real64]
  ! Node 1 wet stress is zero. Node 2 uses the upper limit: 45/90.
  ! Node 3 uses the lower limit: 95/190, then salt reduces to 0.2.
  ! The unrooted node keeps its initialized factor of one.
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  expected=[0.0_real64,0.4_real64,0.1_real64,1.0_real64,1.0_real64]
  call check(status==MICRO_STRESS_OK.and.allocated(factors),1)
  call check(all(abs(factors-expected)<1.0e-14_real64),2)
  print '(A)', 'MICRO07_FEDDES_MAAS_PRODUCT=PASS'

  p%combination_mode=2
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  expected=[0.0_real64,0.5_real64,0.2_real64,1.0_real64,1.0_real64]
  call check(status==MICRO_STRESS_OK.and.all(abs(factors-expected)<1.0e-14_real64),3)
  print '(A)', 'MICRO07_MINIMUM_COMPOSITION=PASS'

  p%combination_mode=3
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  expected=[0.04_real64,0.04_real64,0.04_real64,0.04_real64,1.0_real64]
  call check(status==MICRO_STRESS_OK.and.all(abs(factors-expected)<1.0e-14_real64),4)
  print '(A)', 'MICRO07_LITERAL_ZERO_SKIP_BROADCAST=PASS'

  p%oxygen_mode=0
  p%salinity_mode=0
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  call check(status==MICRO_STRESS_OK.and.all(factors==1.0_real64),5)
  p%combination_mode=1
  p%oxygen_mode=1
  p%salinity_mode=0
  head(1)=p%wet_limit_cm
  head(2)=p%upper_oxygen_limit_cm
  head(3)=p%lower_oxygen_limit_cm
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  expected=[0.0_real64,1.0_real64,1.0_real64,1.0_real64,1.0_real64]
  call check(status==MICRO_STRESS_OK.and.all(factors==expected),6)
  print '(A)', 'MICRO07_BOUNDARY_AND_DISABLED_MODES=PASS'

  p%upper_oxygen_limit_cm=p%wet_limit_cm
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  call check(status==MICRO_STRESS_INVALID.and..not.allocated(factors),7)
  p%upper_oxygen_limit_cm=-100.0_real64
  head(1)=ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  call check(status==MICRO_STRESS_INVALID.and..not.allocated(factors),8)
  head(1)=-5.0_real64
  p%oxygen_mode=2
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  call check(status==MICRO_STRESS_INVALID.and..not.allocated(factors),9)
  p%oxygen_mode=0
  salt(1)=-1.0_real64
  call evaluate_micro_stress_factors(p,head,salt,4,factors,status)
  call check(status==MICRO_STRESS_INVALID.and..not.allocated(factors),10)
  salt(1)=0.0_real64
  call evaluate_micro_stress_factors(p,head,salt,0,factors,status)
  call check(status==MICRO_STRESS_OK.and.all(factors==1.0_real64),11)
  print '(A)', 'MICRO07_FAIL_CLOSED_AND_ZERO_ROOTS=PASS'
contains
  subroutine check(condition, number)
    logical, intent(in) :: condition
    integer, intent(in) :: number
    if(.not.condition) then
      print '(A,I0)', 'MICRO07_TEST_FAIL=',number
      error stop 1
    end if
  end subroutine
end program
