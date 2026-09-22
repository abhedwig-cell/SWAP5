program test_ppa_wu05d2_jarvis_compensation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05d2_jarvis_compensation
  implicit none

  integer, parameter :: ncase = 100000, nnode = 5
  integer :: i, status, selector
  integer(int64) :: state
  real(real64) :: qrot(nnode), expected_qrot(nnode), out_qrot(nnode), saved_qrot(nnode)
  real(real64) :: ptra, qrosum, expected_sum, out_sum, alpha
  real(real64) :: parts(4), out_parts(4), expected_parts(4), saved_parts(4)
  real(real64) :: a_qrot(nnode), a_qrosum, a_ptra, a_alpha, a_parts(4)
  integer :: a_selector
  logical :: applied, expected_applied

  state = 994711_int64
  do i = 1, ncase
    call make_case(state, qrot, qrosum, ptra, alpha, selector, parts)
    call source_oracle(qrot, qrosum, ptra, alpha, selector, parts, &
        expected_qrot, expected_sum, expected_parts, expected_applied)
    call run_compositor(qrot, qrosum, ptra, alpha, selector, parts, out_qrot, out_sum, out_parts, applied, status)
    call require(status == PPA_WU05D2_OK, 'valid deterministic source-domain input rejected')
    call require(same_vector_bits(out_qrot, expected_qrot) .and. same_bits(out_sum, expected_sum) .and. &
        same_vector_bits(out_parts, expected_parts) .and. (applied .eqv. expected_applied), &
        'compositor differs from source equation oracle')
  end do

  qrot = [1.0_real64, 2.0_real64, 1.5_real64, 0.5_real64, 1.0_real64]
  ptra = 10.0_real64
  qrosum = sum(qrot)
  parts = [1.0_real64, 1.0_real64, 1.0_real64, 1.0_real64]
  call run_compositor(qrot, qrosum, ptra, 1.0_real64, 1, parts, &
      out_qrot, out_sum, out_parts, applied, status)
  call require(status == PPA_WU05D2_OK .and. .not. applied .and. same_vector_bits(qrot, out_qrot) .and. &
      same_bits(qrosum, out_sum) .and. same_vector_bits(parts, out_parts), 'Jarvis no-op gate changed inputs')

  call make_case(state, qrot, qrosum, ptra, alpha, selector, parts)
  call run_compositor(qrot, qrosum, ptra, alpha, selector, parts, out_qrot, out_sum, out_parts, applied, status)
  call require(status == PPA_WU05D2_OK .and. applied, 'A compensation replay rejected')
  a_qrot = qrot; a_qrosum = qrosum; a_ptra = ptra; a_alpha = alpha; a_selector = selector; a_parts = parts
  saved_qrot = out_qrot
  expected_sum = out_sum
  saved_parts = out_parts
  call make_case(state, qrot, qrosum, ptra, alpha, selector, parts)
  call run_compositor(qrot, qrosum, ptra, alpha, selector, parts, out_qrot, out_sum, out_parts, applied, status)
  call require(status == PPA_WU05D2_OK, 'B compensation replay rejected')
  call run_compositor(a_qrot, a_qrosum, a_ptra, a_alpha, a_selector, a_parts, &
      out_qrot, out_sum, out_parts, applied, status)
  call require(status == PPA_WU05D2_OK .and. same_vector_bits(saved_qrot, out_qrot) .and. &
      same_bits(expected_sum, out_sum) .and. same_vector_bits(saved_parts, out_parts), 'A/B/A compounding detected')

  qrot(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call run_compositor(qrot, 5.0_real64, 10.0_real64, 0.5_real64, 1, parts, &
      out_qrot, out_sum, out_parts, applied, status)
  call require(status == PPA_WU05D2_INVALID_INPUT .and. .not. applied .and. same_bits(out_sum, 5.0_real64), &
      'malformed input did not fail closed')

  write(*, '(a)') 'PPA_WU05D2_JARVIS_SOURCE_ORACLE_100000=PASS'
  write(*, '(a)') 'PPA_WU05D2_ALL_STRESSOR_SELECTIONS_AND_ATTRIBUTION=PASS'
  write(*, '(a)') 'PPA_WU05D2_NOOP_AND_A_B_A_NONCOMPOUNDING=PASS'
  write(*, '(a)') 'PPA_WU05D2_NONFINITE_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(value)
    integer(int64), intent(inout) :: value
    value = modulo(48271_int64*value, 2147483647_int64)
    next_unit = real(value, real64)/2147483647.0_real64
  end function next_unit

  subroutine make_case(rng, sink, total, potential, critical, stressor, reductions)
    integer(int64), intent(inout) :: rng
    real(real64), intent(out) :: sink(nnode), total, potential, critical, reductions(4)
    integer, intent(out) :: stressor
    real(real64) :: weights_local(4), wanted_total
    integer :: k
    potential = 10.0_real64
    wanted_total = 0.2_real64 + 0.7_real64*next_unit(rng)
    do k=1,nnode
      sink(k) = wanted_total*potential*(0.1_real64+next_unit(rng))
    end do
    sink = sink * (wanted_total*potential/sum(sink))
    total = sum(sink)
    reductions(1) = max(0.0_real64, potential-total)
    weights_local = [next_unit(rng), next_unit(rng), next_unit(rng), next_unit(rng)]
    weights_local = weights_local/sum(weights_local)
    reductions = reductions(1)*weights_local
    critical = 0.2_real64+0.75_real64*next_unit(rng)
    stressor = 1+int(5.0_real64*next_unit(rng))
    if (stressor > 5) stressor = 5
  end subroutine make_case

  subroutine run_compositor(sink, total, potential, critical, stressor, reductions, &
      result_sink, result_total, result_reductions, was_applied, result_status)
    real(real64), intent(in) :: sink(:), total, potential, critical, reductions(4)
    integer, intent(in) :: stressor
    real(real64), intent(out) :: result_sink(:), result_total, result_reductions(4)
    logical, intent(out) :: was_applied
    integer, intent(out) :: result_status
    call apply_ppa_wu05d2_jarvis_compensation(sink, total, potential, critical, stressor, &
        reductions(1), reductions(2), reductions(3), reductions(4), result_sink, result_total, &
        result_reductions(1), result_reductions(2), result_reductions(3), result_reductions(4), &
        was_applied, result_status)
  end subroutine run_compositor

  subroutine source_oracle(sink, total, potential, critical, stressor, reductions, &
      result_sink, result_total, result_reductions, was_applied)
    real(real64), intent(in) :: sink(:), total, potential, critical, reductions(4)
    integer, intent(in) :: stressor
    real(real64), intent(out) :: result_sink(:), result_total, result_reductions(4)
    logical, intent(out) :: was_applied
    real(real64) :: alpha_total, removed, dry, wet, salt, frost
    real(real64) :: dry_com, wet_com, salt_com, frost_com, total_com, red_total
    integer :: k
    result_sink = sink
    result_total = total
    result_reductions = reductions
    was_applied = .false.
    alpha_total = total/potential
    removed = potential-total
    if (.not.(abs(critical-1.0_real64)>=1.0e-14_real64 .and. &
        removed>1.0e-14_real64 .and. alpha_total>=1.0e-14_real64)) return
    dry = alpha_total**(reductions(2)/removed)
    wet = alpha_total**(reductions(1)/removed)
    salt = alpha_total**(reductions(3)/removed)
    frost = alpha_total**(reductions(4)/removed)
    if (stressor == 1) then
      total_com = min(alpha_total/critical,1.0_real64)
      dry_com=dry; wet_com=wet; salt_com=salt; frost_com=frost
    else
      dry_com=dry; wet_com=wet; salt_com=salt; frost_com=frost
      if (stressor == 2) then
        dry_com=min(dry/critical,1.0_real64)
      else if (stressor == 3) then
        wet_com=min(wet/critical,1.0_real64)
      else if (stressor == 4) then
        salt_com=min(salt/critical,1.0_real64)
      else if (stressor == 5) then
        frost_com=min(frost/critical,1.0_real64)
      end if
      total_com=wet_com*dry_com*salt_com*frost_com
    end if
    do k=1,size(sink)
      result_sink(k)=sink(k)*total_com/alpha_total
    end do
    result_total=potential*total_com
    removed=potential-result_total
    if (removed<1.0e-14_real64) then
      result_reductions=0.0_real64
    else
      red_total=(1.0_real64-wet_com)+(1.0_real64-dry_com)+ &
          (1.0_real64-salt_com)+(1.0_real64-frost_com)
      result_reductions(1)=(1.0_real64-wet_com)/red_total*removed
      result_reductions(2)=(1.0_real64-dry_com)/red_total*removed
      result_reductions(3)=(1.0_real64-salt_com)/red_total*removed
      result_reductions(4)=(1.0_real64-frost_com)/red_total*removed
    end if
    was_applied=.true.
  end subroutine source_oracle

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits=transfer(left,0_int64)==transfer(right,0_int64)
  end function same_bits

  logical function same_vector_bits(left, right)
    real(real64), intent(in) :: left(:), right(:)
    integer :: k
    same_vector_bits=size(left)==size(right)
    if (size(left)/=size(right)) return
    do k=1,size(left)
      if (.not.same_bits(left(k),right(k))) then
        same_vector_bits=.false.
        return
      end if
    end do
  end function same_vector_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not.condition) then
      write(*,'(a)') 'PPA_WU05D2_FAIL='//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05d2_jarvis_compensation
