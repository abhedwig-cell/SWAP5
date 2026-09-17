program test_fgc31_smooth_freatic_projection
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_smooth_freatic_projection
  implicit none

  call verify_smooth_projection_and_direction()
  call verify_fail_closed_boundaries()

  print '(A)', 'FGC31_SMOOTH_FREATIC_PROJECTION=PASS'
  print '(A)', 'FGC31_ANALYTIC_DIRECTION_CENTERED_FD=PASS'
  print '(A)', 'FGC31_LEGACY_CURRENT_INTERIOR_FORMULA_EQUIVALENCE=PASS'
  print '(A)', 'FGC31_BRANCH_BOUNDARIES_FAIL_CLOSED=PASS'

contains

  subroutine verify_smooth_projection_and_direction()
    real(real64), parameter :: z(4) = [-5.0_real64, -15.0_real64, -25.0_real64, -35.0_real64]
    real(real64), parameter :: distance(4) = [5.0_real64, 10.0_real64, 10.0_real64, 10.0_real64]
    real(real64), parameter :: h(4) = [-20.0_real64, -8.0_real64, 4.0_real64, 10.0_real64]
    real(real64), parameter :: dh(4) = [0.10_real64, -0.30_real64, 0.70_real64, 0.20_real64]
    real(real64), parameter :: eps_values(3) = [1.0e-4_real64, 3.0e-5_real64, 1.0e-5_real64]
    type(b110_smooth_freatic_projection_diagnostics_t) :: d, dp, dm
    real(real64) :: gwl, dgwl, gp, gm, dummy
    real(real64) :: expected, expected_old_form, fd
    integer :: i

    call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_OK, 'smooth projection status')
    call require(d%value_defined .and. d%direction_defined, 'smooth projection availability')
    call require(d%crossing_lower_node == 2, 'deepest unsaturated crossing node')
    call require(.not. d%branch_or_nonsmooth_point, 'smooth route incorrectly marked nonsmooth')

    expected = z(3) + h(3) * distance(3) / (h(3)-h(2))
    expected_old_form = z(3) + h(3) / (h(3)-h(2)) * 0.5_real64 * &
         ((2.0_real64*distance(3)-10.0_real64) + 10.0_real64)
    call require(close(gwl, expected, 1.0e-14_real64), 'projection value')
    ! For the fixture dz(2)=dz(3)=10 cm, old 0.5*(dz2+dz3) and current
    ! node_distance(3) are the same 10 cm geometry.
    call require(close(expected_old_form, expected, 1.0e-14_real64), 'legacy/current geometry formula equivalence')

    do i = 1, size(eps_values)
      call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h+eps_values(i)*dh, 0.0_real64*dh, &
           gp, dummy, dp)
      call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h-eps_values(i)*dh, 0.0_real64*dh, &
           gm, dummy, dm)
      call require(dp%status == B110_GWL_PROJECTION_OK .and. dm%status == B110_GWL_PROJECTION_OK, 'FD route stays smooth')
      fd = (gp-gm)/(2.0_real64*eps_values(i))
      call require(abs(fd-dgwl) < 2.0e-9_real64, 'analytic groundwater direction vs centered FD')
    end do
  end subroutine verify_smooth_projection_and_direction

  subroutine verify_fail_closed_boundaries()
    real(real64), parameter :: z(3) = [-5.0_real64, -15.0_real64, -25.0_real64]
    real(real64), parameter :: distance(3) = [5.0_real64, 10.0_real64, 10.0_real64]
    real(real64) :: h(3), dh(3), gwl, dgwl
    type(b110_smooth_freatic_projection_diagnostics_t) :: d

    dh = [0.1_real64, 0.2_real64, 0.3_real64]

    h = [-10.0_real64, -4.0_real64, -1.0_real64]
    call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_NO_INTERIOR_WATER_TABLE .and. .not. d%value_defined, &
         'below-profile route must fail closed')

    h = [-10.0_real64, -4.0_real64, 0.0_real64]
    call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_NONSMOOTH .and. d%branch_or_nonsmooth_point, &
         'bottom zero-pressure boundary must fail closed')

    h = [1.0_real64, 2.0_real64, 3.0_real64]
    call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_FULLY_SATURATED .and. d%branch_or_nonsmooth_point, &
         'fully saturated branch must fail closed')

    h = [-2.0_real64, 0.0_real64, 3.0_real64]
    call evaluate_b110_smooth_freatic_projection(2, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_NONSMOOTH .and. d%branch_or_nonsmooth_point, &
         'interior exact zero must fail closed')

    h = [-2.0_real64, -1.0_real64, 3.0_real64]
    call evaluate_b110_smooth_freatic_projection(2, .true., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_UNSUPPORTED_MACROPORE, 'macropore route must fail closed')

    call evaluate_b110_smooth_freatic_projection(7, .false., z, distance, h, dh, gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_UNSUPPORTED_BOTTOM_MODE, 'non-qbot bottom mode must fail closed')

    call evaluate_b110_smooth_freatic_projection(2, .false., z, [5.0_real64, -1.0_real64, 10.0_real64], h, dh, &
         gwl, dgwl, d)
    call require(d%status == B110_GWL_PROJECTION_INVALID_INPUT, 'invalid geometry must fail closed')
  end subroutine verify_fail_closed_boundaries

  pure logical function close(a, b, tol) result(ok)
    real(real64), intent(in) :: a, b, tol
    ok = abs(a-b) <= tol
  end function close

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC31_TEST_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc31_smooth_freatic_projection
