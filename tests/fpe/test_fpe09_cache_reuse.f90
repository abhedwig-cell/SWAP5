program test_fpe09_cache_reuse
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters
  implicit none

  type(b110_default_mvg_parameters_t) :: cache
  real(real64), allocatable :: input4(:,:), input5(:,:)
  real(real64) :: old_theta_r, old_span
  logical :: reused

  allocate(input4(24,4), input5(24,5))
  call make_fixture(input4, 1.0_real64)

  call initialize_b110_default_mvg_parameters(cache, input4, reused)
  call require(.not. reused, 'first materialization must allocate storage')
  call require(cache%active_nodes == 4, 'first active_nodes')
  call require(size(cache%cofgen,1) == 42 .and. size(cache%cofgen,2) == 4, 'first cache shape')
  old_theta_r = cache%cofgen(1,1)
  old_span = cache%cofgen(25,1)
  write(*,'(A)') 'FPE09_CACHE_FIRST_ALLOCATION=PASS'

  call make_fixture(input4, 1.0_real64)
  input4(1,:) = input4(1,:) + 0.001_real64
  call initialize_b110_default_mvg_parameters(cache, input4, reused)
  call require(reused, 'same-shape refresh must reuse storage')
  call require(cache%cofgen(1,1) /= old_theta_r, 'same-shape refresh overwrites primary values')
  call require(cache%cofgen(25,1) /= old_span, 'same-shape refresh recomputes derived values')
  call require(cache%cofgen(1,1) == input4(1,1), 'same-shape refreshed input identity')
  write(*,'(A)') 'FPE09_CACHE_SAME_SHAPE_REUSE_AND_REFRESH=PASS'

  call make_fixture(input5, 1.1_real64)
  call initialize_b110_default_mvg_parameters(cache, input5, reused)
  call require(.not. reused, 'shape change must reallocate storage')
  call require(cache%active_nodes == 5, 'shape-change active_nodes')
  call require(size(cache%cofgen,1) == 42 .and. size(cache%cofgen,2) == 5, 'shape-change exact cache shape')
  call require(cache%cofgen(3,5) == input5(3,5), 'shape-change refreshed values')
  write(*,'(A)') 'FPE09_CACHE_SHAPE_CHANGE_REALLOCATION=PASS'

  input5(3,:) = input5(3,:) * 0.95_real64
  call initialize_b110_default_mvg_parameters(cache, input5, reused)
  call require(reused, 'new same-shape refresh must reuse storage')
  call require(cache%cofgen(3,5) == input5(3,5), 'new same-shape refresh overwrites values')
  write(*,'(A)') 'FPE09_CACHE_SECOND_SHAPE_REUSE=PASS'

  ! Backward-compatible caller form without the optional observation argument.
  call initialize_b110_default_mvg_parameters(cache, input5)
  call require(cache%cofgen(3,5) == input5(3,5), 'legacy caller form retained')
  write(*,'(A)') 'FPE09_CACHE_LEGACY_CALL_FORM=PASS'
  write(*,'(A)') 'FPE09_CACHE_REUSE_ORACLE PASS'

contains

  subroutine make_fixture(values, scale)
    real(real64), intent(out) :: values(:,:)
    real(real64), intent(in) :: scale
    integer :: j
    values = 0.0_real64
    do j = 1, size(values,2)
      values(1,j) = 0.032_real64
      values(2,j) = 0.423_real64
      values(3,j) = 4.75_real64*scale
      values(4,j) = 0.0135_real64
      values(5,j) = 0.365_real64
      values(6,j) = 1.455_real64
      values(7,j) = 1.0_real64 - 1.0_real64/values(6,j)
      values(8,j) = values(4,j)
      values(10,j) = values(3,j)
      values(11,j) = 0.999_real64
      values(12,j) = 0.99_real64*values(3,j)
      values(22,j) = -1.0e6_real64
      values(23,j) = 1.0e-12_real64
    end do
  end subroutine make_fixture

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPE09_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe09_cache_reuse
