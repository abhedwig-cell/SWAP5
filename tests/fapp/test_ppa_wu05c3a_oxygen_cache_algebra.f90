program test_ppa_wu05c3a_oxygen_cache_algebra
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05c3a_oxygen_cache_algebra
  implicit none

  integer, parameter :: ncase = 100000
  integer :: i, status
  integer(int64) :: state
  real(real64) :: h100, h500, theta100, theta500, theta_gfp, theta_s, theta_r
  real(real64) :: alpha, gen_n, gen_m
  real(real64) :: b, gfp, term1, term2, cap, nmin, mplus
  real(real64) :: eb, egfp, eterm1, eterm2, ecap, enmin, emplus
  real(real64) :: saved(7), replay(7)

  h100 = -100.0_real64
  h500 = -500.0_real64
  state = 172903_int64
  do i = 1, ncase
    theta100 = 0.15_real64 + 0.25_real64*next_unit(state)
    theta500 = 0.10_real64 + 0.20_real64*next_unit(state)
    theta_s = 0.38_real64 + 0.20_real64*next_unit(state)
    theta_gfp = theta_s - (0.02_real64 + 0.12_real64*next_unit(state))
    theta_r = 0.01_real64 + 0.06_real64*next_unit(state)
    alpha = 0.5_real64 + 5.0_real64*next_unit(state)
    gen_n = 1.2_real64 + 2.0_real64*next_unit(state)
    gen_m = 0.2_real64 + 0.7_real64*next_unit(state)

    call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, &
        theta_gfp, theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
    call require(status == PPA_WU05C3A_OK, 'ordinary source-domain inputs rejected')
    call source_oracle(h100, h500, theta100, theta500, theta_gfp, theta_s, theta_r, alpha, gen_n, gen_m, &
        eb, egfp, eterm1, eterm2, ecap, enmin, emplus)
    call require(same_bits(b, eb) .and. same_bits(gfp, egfp) .and. same_bits(term1, eterm1) .and. &
        same_bits(term2, eterm2) .and. same_bits(cap, ecap) .and. same_bits(nmin, enmin) .and. &
        same_bits(mplus, emplus), 'derived values differ from source formula oracle')
  end do

  theta100 = 0.29_real64; theta500 = 0.22_real64; theta_s = 0.47_real64
  theta_gfp = 0.39_real64; theta_r = 0.04_real64; alpha = 2.1_real64
  gen_n = 1.7_real64; gen_m = 1.0_real64 - 1.0_real64/gen_n
  call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, theta_gfp, &
      theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
  call require(status == PPA_WU05C3A_OK, 'A replay rejected')
  saved = [b, gfp, term1, term2, cap, nmin, mplus]
  theta100 = 0.32_real64; theta500 = 0.19_real64; theta_gfp = 0.36_real64
  call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, theta_gfp, &
      theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
  call require(status == PPA_WU05C3A_OK, 'B replay rejected')
  theta100 = 0.29_real64; theta500 = 0.22_real64; theta_gfp = 0.39_real64
  call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, theta_gfp, &
      theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
  replay = [b, gfp, term1, term2, cap, nmin, mplus]
  call require(status == PPA_WU05C3A_OK .and. same_vector_bits(saved, replay), 'A/B/A replay differs')

  theta100 = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, theta_gfp, &
      theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
  call require(status == PPA_WU05C3A_INVALID_INPUT .and. same_vector_bits( &
      [b, gfp, term1, term2, cap, nmin, mplus], [0.0_real64, 0.0_real64, 0.0_real64, &
      0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]), 'non-finite input did not fail closed')
  theta100 = 0.2_real64
  theta500 = 0.2_real64
  call evaluate_ppa_wu05c3a_oxygen_cache_algebra(h100, h500, theta100, theta500, theta_gfp, &
      theta_s, theta_r, alpha, gen_n, gen_m, b, gfp, term1, term2, cap, nmin, mplus, status)
  call require(status == PPA_WU05C3A_INVALID_INPUT .and. same_vector_bits( &
      [b, gfp, term1, term2, cap, nmin, mplus], [0.0_real64, 0.0_real64, 0.0_real64, &
      0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]), 'singular input did not fail closed')

  write(*, '(a)') 'PPA_WU05C3A_SOURCE_FORMULA_ORACLE_100000=PASS'
  write(*, '(a)') 'PPA_WU05C3A_ALL_DERIVED_FIELDS_BITWISE=PASS'
  write(*, '(a)') 'PPA_WU05C3A_STATELESS_A_B_A_REPLAY=PASS'
  write(*, '(a)') 'PPA_WU05C3A_NONFINITE_AND_SINGULAR_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(value)
    integer(int64), intent(inout) :: value
    value = modulo(48271_int64 * value, 2147483647_int64)
    next_unit = real(value, real64) / 2147483647.0_real64
  end function next_unit

  subroutine source_oracle(h1, h5, t100, t500, tgfp, ts, tr, a, gn, gm, &
      cb, gf, d1, d2, ct, nm, mp)
    real(real64), intent(in) :: h1, h5, t100, t500, tgfp, ts, tr, a, gn, gm
    real(real64), intent(out) :: cb, gf, d1, d2, ct, nm, mp
    real(real64) :: lh1, lh5, theta100_local, theta500_local, campbell_b
    lh1 = log10(-h1)
    lh5 = log10(-h5)
    theta100_local = log10(t100)
    theta500_local = log10(t500)
    campbell_b = (lh5-lh1)/(theta100_local-theta500_local)
    gf = ts-tgfp
    d1 = 2.0_real64*(gf**3)+0.04_real64*gf
    d2 = 2.0_real64+3.0_real64/campbell_b
    ct = (ts-tr)*0.01_real64*a*gn*gm
    nm = gn-1.0_real64
    mp = gm+1.0_real64
    cb = campbell_b
  end subroutine source_oracle

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  logical function same_vector_bits(left, right)
    real(real64), intent(in) :: left(:), right(:)
    integer :: j
    same_vector_bits = size(left) == size(right)
    if (size(left) /= size(right)) return
    do j = 1, size(left)
      if (.not. same_bits(left(j), right(j))) then
        same_vector_bits = .false.
        return
      end if
    end do
  end function same_vector_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'PPA_WU05C3A_FAIL='//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05c3a_oxygen_cache_algebra
