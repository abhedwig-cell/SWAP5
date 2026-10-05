program test_mig431_tillage_water
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tillage_water_redistribution
  implicit none

  type(tillage_water_result_t) :: result
  real(real64), parameter :: thickness(2) = [10.0_real64,20.0_real64]
  real(real64), parameter :: residual(2) = [0.1_real64,0.1_real64]
  integer :: status

  call redistribute_tillage_water(TILLAGE_WATER_SIMPLE, [0.5_real64,0.2_real64], &
       [0.0_real64,0.0_real64], residual, [0.4_real64,0.4_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_OK .and. &
       maxval(abs(result%water_content-[0.4_real64,0.25_real64])) < 1.0e-14_real64, &
       'simple redistribution caps supersaturated top and moves 1 cm to lower compartment')
  call require(abs(result%mass_residual_cm) < 1.0e-14_real64 .and. &
       abs(result%ponding_depth_cm-0.2_real64) < 1.0e-14_real64, 'simple redistribution conserves soil plus pond')

  call redistribute_tillage_water(TILLAGE_WATER_SIMPLE, [0.5_real64,0.5_real64], &
       [0.0_real64,0.0_real64], residual, [0.4_real64,0.4_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_OK .and. &
       abs(result%ponding_depth_cm-3.2_real64) < 1.0e-14_real64 .and. &
       abs(result%mass_residual_cm) < 1.0e-14_real64, &
       'excess beyond new pore capacity enters pond without mass loss')

  call redistribute_tillage_water(TILLAGE_WATER_PROFILE, [0.4_real64,0.2_real64], &
       [0.3_real64,0.3_real64], residual, [0.5_real64,0.5_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_OK .and. &
       maxval(abs(result%water_content-[4.0_real64/15.0_real64,4.0_real64/15.0_real64])) < &
       1.0e-14_real64, 'profile redistribution removes 1 cm in thickness-weighted proportion')
  call require(abs(result%mass_residual_cm) < 1.0e-14_real64, 'profile water-removal branch closes mass')

  call redistribute_tillage_water(TILLAGE_WATER_PROFILE, [0.4_real64,0.2_real64], &
       [0.2_real64,0.2_real64], residual, [0.4_real64,0.4_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_OK .and. &
       maxval(abs(result%water_content-[4.0_real64/15.0_real64,4.0_real64/15.0_real64])) < &
       1.0e-14_real64, 'profile redistribution fills new pore volume in thickness-weighted proportion')
  call require(abs(result%mass_residual_cm) < 1.0e-14_real64, 'profile water-addition branch closes mass')

  call redistribute_tillage_water(TILLAGE_WATER_PROFILE, [0.5_real64,0.5_real64], &
       [0.4_real64,0.4_real64], residual, [0.4_real64,0.4_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_OK .and. &
       abs(result%ponding_depth_cm-3.2_real64) < 1.0e-14_real64 .and. &
       abs(result%mass_residual_cm) < 1.0e-14_real64, 'profile saturation overflow becomes pond')

  call redistribute_tillage_water(0, [0.5_real64,0.5_real64], &
       [0.4_real64,0.4_real64], residual, [0.4_real64,0.4_real64], &
       thickness,0.2_real64,result,status)
  call require(status == TILLAGE_WATER_INVALID .and. .not. allocated(result%water_content), &
       'legacy test-only redistribution selector rejects without publication')

  write(*,'(a)') 'F_MIG431_TILLAGE_SIMPLE_MASS_CLOSURE=PASS'
  write(*,'(a)') 'F_MIG431_TILLAGE_PROFILE_MASS_CLOSURE=PASS'
  write(*,'(a)') 'F_MIG431_TILLAGE_REDIST0_REJECTED=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//label
      error stop 1
    end if
  end subroutine require

end program test_mig431_tillage_water
