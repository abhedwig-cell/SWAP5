program test_fsi39_b110_ksatexm
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  implicit none

  type(b110_default_mvg_parameters_t) :: disabled, enabled
  real(real64) :: cof(24,1), k_disabled, k_enabled
  logical :: ok_disabled, ok_enabled
  real(real64), parameter :: tol = 2.0e-12_real64

  cof = 0.0_real64
  ! Exact Hupsel lower-layer B1.11 cofgen rows 1:12.
  cof(1,1) = 0.02_real64
  cof(2,1) = 0.3870640000000001_real64
  cof(3,1) = 22.76176_real64
  cof(4,1) = 0.016083_real64
  cof(5,1) = 2.4396619999999993_real64
  cof(6,1) = 1.524418_real64
  cof(7,1) = 0.3440119442305195_real64
  cof(8,1) = 0.016083_real64
  cof(9,1) = 0.0_real64
  cof(10,1) = 227.61759999999998_real64
  cof(11,1) = 0.9981816467911503_real64
  cof(12,1) = 15.814441314772257_real64

  call initialize_b110_default_mvg_parameters(disabled, cof)
  call initialize_b110_default_mvg_parameters(enabled, cof, enable_ksatexm_extension=.true.)

  call evaluate_b110_default_mvg_conductivity(disabled, 1, 1.0_real64, k_disabled, ok_disabled)
  call evaluate_b110_default_mvg_conductivity(enabled, 1, 1.0_real64, k_enabled, ok_enabled)
  call require(ok_disabled .and. ok_enabled, 1)
  call require(abs(k_disabled-22.76176_real64) < tol, 2)
  call require(abs(k_enabled-227.61759999999998_real64) < tol, 3)

  ! Exact B1.11 interpolation oracle at h=-1 cm for this Hupsel layer.
  call evaluate_b110_default_mvg_conductivity(disabled, 1, -1.0_real64, k_disabled, ok_disabled)
  call evaluate_b110_default_mvg_conductivity(enabled, 1, -1.0_real64, k_enabled, ok_enabled)
  call require(ok_disabled .and. ok_enabled, 4)
  call require(abs(k_enabled-153.81975964948478_real64) < 2.0e-11_real64, 5)
  call require(k_enabled > k_disabled, 6)

  ! Below the legacy relsat threshold the opt-in route must be an exact no-op.
  call evaluate_b110_default_mvg_conductivity(disabled, 1, -5.0_real64, k_disabled, ok_disabled)
  call evaluate_b110_default_mvg_conductivity(enabled, 1, -5.0_real64, k_enabled, ok_enabled)
  call require(ok_disabled .and. ok_enabled, 7)
  call require(k_enabled == k_disabled, 8)

  print '(A)','F_SI39_DEFAULT_DISABLED_PRESERVATION=PASS'
  print '(A)','F_SI39_HUPSEL_SATURATED_KSATEXM=PASS'
  print '(A)','F_SI39_HUPSEL_NEAR_SATURATED_INTERPOLATION=PASS'
  print '(A)','F_SI39_BELOW_THRESHOLD_NOOP=PASS'

contains
  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'F_SI39_FAIL=', code
      error stop 1
    end if
  end subroutine require
end program test_fsi39_b110_ksatexm
