program test_frost_nan_guard_independent
  use iso_fortran_env, only: real64, int64
  use ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf, ieee_negative_inf
  use mod_frost_hydraulic_effect
  implicit none
  real(real64) :: factor(3), k(3), dk(3), invalid(3)
  integer(int64) :: k_bits(3), dk_bits(3)
  type(frost_hydraulic_parameters_t) :: p
  integer :: kind, field, position, status, cases

  invalid = [ieee_value(0.0_real64, ieee_quiet_nan), &
       ieee_value(0.0_real64, ieee_positive_inf), ieee_value(0.0_real64, ieee_negative_inf)]
  cases = 0
  do kind = 1, 3
    do field = 1, 3
      do position = 1, 3
        factor = [0.0_real64, 0.5_real64, 1.0_real64]
        k = [2.0_real64, 3.0_real64, 4.0_real64]
        dk = [-1.0_real64, 0.0_real64, 2.0_real64]
        select case(field)
        case(1)
          factor(position) = invalid(kind)
        case(2)
          k(position) = invalid(kind)
        case(3)
          dk(position) = invalid(kind)
        end select
        k_bits = transfer(k, k_bits)
        dk_bits = transfer(dk, dk_bits)
        call apply_frost_hydraulic_conductivity(factor, k, dk, status)
        if (status /= FROST_EFFECT_INVALID_HYDRAULICS) error stop 'nonfinite hydraulic input accepted'
        if (any(transfer(k, k_bits) /= k_bits)) error stop 'rejected input changed conductivity bits'
        if (any(transfer(dk, dk_bits) /= dk_bits)) error stop 'rejected input changed derivative bits'
        cases = cases + 1
      end do
    end do
    do field = 1, 2
      p = frost_hydraulic_parameters_t()
      p%active = .true.
      p%reduction_start_c = 2.0_real64
      p%reduction_end_c = -2.0_real64
      if (field == 1) p%reduction_start_c = invalid(kind)
      if (field == 2) p%reduction_end_c = invalid(kind)
      if (p%valid()) error stop 'nonfinite active threshold accepted'
      p%active = .false.
      if (.not. p%valid()) error stop 'inactive ignored threshold changed semantics'
      cases = cases + 1
    end do
  end do
  if (cases /= 33) error stop 'independent matrix incomplete'
  print '(a)', 'FROST_NAN_GUARD_33_NONFINITE_BIT_PRESERVATION=PASS'
end program test_frost_nan_guard_independent
