program test_ppa_wu05g2_micro_stress_aggregate
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05g2_micro_stress_aggregate
  implicit none
  integer :: i, node, selector, status
  real(real64) :: oxygen(5), salinity(5), frost(5), actual(5), expected(5), product, factor
  real(real64) :: saved(5), alternate(5)

  call run_case(1, [0.2_real64, 0.5_real64], [0.4_real64, 1.0_real64], &
      [1.0_real64, 0.0_real64], [0.2_real64*0.4_real64*1.0_real64, 0.0_real64])
  call run_case(2, [0.2_real64, 0.5_real64], [0.4_real64, 1.0_real64], &
      [1.0_real64, 0.0_real64], [min(0.2_real64,0.4_real64,1.0_real64), min(0.5_real64,1.0_real64,0.0_real64)])
  call run_case(3, [0.2_real64, 0.5_real64], [0.4_real64, 1.0_real64], &
      [1.0_real64, 0.0_real64], [0.2_real64*0.4_real64*1.0_real64, 0.2_real64*0.4_real64*1.0_real64])

  do i = 1, 100000
    do node = 1, 5
      oxygen(node) = real(mod(i*31 + node*113, 1001), real64) / 1000.0_real64
      salinity(node) = real(mod(i*47 + node*71, 1001), real64) / 1000.0_real64
      frost(node) = real(mod(i*59 + node*43, 1001), real64) / 1000.0_real64
    end do
    selector = mod(i-1, 3) + 1
    call ppa_wu05g2_micro_stress_aggregate(selector, oxygen, salinity, frost, actual, status)
    if (status /= PPA_WU05G2_OK) error stop 'valid source-domain selector rejected'
    if (selector == 1) then
      expected = oxygen * salinity * frost
    else if (selector == 2) then
      expected = min(oxygen, salinity, frost)
    else
      product = 1.0_real64
      do node = 1, 5
        factor = oxygen(node) * salinity(node) * frost(node)
        if (factor > 0.0_real64) product = product * factor
      end do
      expected = product
    end if
    if (.not. same_vector_bits(actual, expected)) error stop '100000-vector source oracle mismatch'
  end do

  call ppa_wu05g2_micro_stress_aggregate(1, [0.3_real64, 0.7_real64], [0.6_real64, 0.8_real64], &
      [0.9_real64, 0.5_real64], saved(1:2), status)
  call ppa_wu05g2_micro_stress_aggregate(2, [0.9_real64, 0.7_real64], [0.8_real64, 0.6_real64], &
      [0.7_real64, 0.5_real64], alternate(1:2), status)
  call ppa_wu05g2_micro_stress_aggregate(1, [0.3_real64, 0.7_real64], [0.6_real64, 0.8_real64], &
      [0.9_real64, 0.5_real64], actual(1:2), status)
  if (.not. same_vector_bits(saved(1:2), actual(1:2))) error stop 'A/B/A stateless replay mismatch'

  call ppa_wu05g2_micro_stress_aggregate(1, [ieee_value(0.0_real64, ieee_quiet_nan)], &
      [1.0_real64], [1.0_real64], actual(1:1), status)
  if (status /= PPA_WU05G2_INVALID_INPUT) error stop 'nonfinite stress accepted'
  call ppa_wu05g2_micro_stress_aggregate(4, [1.0_real64], [1.0_real64], [1.0_real64], actual(1:1), status)
  if (status /= PPA_WU05G2_INVALID_INPUT) error stop 'invalid selector accepted'
  if (alternate(1) < 0.0_real64) error stop 'A/B fixture not exercised'

  write(*,'(a)') 'PPA_WU05G2_SWALPTOT_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05G2_PRODUCT_MIN_AND_POSITIVE_PRODUCT=PASS'
  write(*,'(a)') 'PPA_WU05G2_ZERO_FACTOR_SOURCE_SEMANTICS=PASS'
  write(*,'(a)') 'PPA_WU05G2_STATELESS_AND_INVALID_FAIL_CLOSED=PASS'

contains

  subroutine run_case(sw, wet, salt, frozen, want)
    integer, intent(in) :: sw
    real(real64), intent(in) :: wet(:), salt(:), frozen(:), want(:)
    call ppa_wu05g2_micro_stress_aggregate(sw, wet, salt, frozen, actual(1:size(want)), status)
    if (status /= PPA_WU05G2_OK .or. .not. same_vector_bits(actual(1:size(want)), want)) &
      error stop 'selector edge case mismatch'
  end subroutine run_case

  pure logical function same_vector_bits(left, right)
    real(real64), intent(in) :: left(:), right(:)
    integer :: index
    same_vector_bits = size(left) == size(right)
    if (.not. same_vector_bits) return
    do index = 1, size(left)
      if (transfer(left(index), 0_int64) /= transfer(right(index), 0_int64)) then
        same_vector_bits = .false.
        return
      end if
    end do
  end function same_vector_bits

end program test_ppa_wu05g2_micro_stress_aggregate
