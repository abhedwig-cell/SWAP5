module mod_restricted_fixed_weir_surface_water
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FIXED_WEIR_NOT_RUN = 0
  integer, parameter, public :: FIXED_WEIR_AVAILABLE = 1
  integer, parameter, public :: FIXED_WEIR_INVALID_INPUT = 2
  integer, parameter, public :: FIXED_WEIR_MAPPING_REJECTED = 3
  integer, parameter, public :: FIXED_WEIR_NO_FEASIBLE_STATE = 4
  integer, parameter, public :: FIXED_WEIR_NUMERICAL_REJECTED = 5

  type, public :: fixed_weir_surface_water_parameters_t
    real(real64), allocatable :: level_knots(:)
    real(real64), allocatable :: storage_knots(:)
    real(real64) :: weir_head = 0.0_real64
    real(real64) :: rating_coefficient = 0.0_real64
    real(real64) :: rating_exponent = 1.0_real64
    real(real64) :: supply_dip = 0.0_real64
  end type fixed_weir_surface_water_parameters_t

  type, public :: fixed_weir_surface_water_state_t
    real(real64) :: storage = 0.0_real64
  end type fixed_weir_surface_water_state_t

  type, public :: fixed_weir_surface_water_forcing_t
    real(real64) :: secondary_drainage_rate = 0.0_real64
    real(real64) :: supply_capacity_rate = 0.0_real64
  end type fixed_weir_surface_water_forcing_t

  type, public :: fixed_weir_surface_water_numerical_config_t
    integer :: max_bisection_iterations = 128
    real(real64) :: rating_storage_abs_tolerance = 1.0e-12_real64
    real(real64) :: rating_storage_rel_tolerance = 1.0e-12_real64
  end type fixed_weir_surface_water_numerical_config_t

  type, public :: fixed_weir_surface_water_result_t
    integer :: status = FIXED_WEIR_NOT_RUN
    type(fixed_weir_surface_water_state_t) :: candidate_state
    real(real64) :: water_level = 0.0_real64
    real(real64) :: supply_rate = 0.0_real64
    real(real64) :: discharge_rate = 0.0_real64
    real(real64) :: mass_residual = 0.0_real64
    real(real64) :: rating_storage_residual = 0.0_real64
    integer :: bisection_iterations = 0
    logical :: exact_knot_policy_used = .false.
    character(len=32) :: route = 'not-run'
  end type fixed_weir_surface_water_result_t

  public :: evaluate_restricted_fixed_weir_surface_water
  public :: validate_fixed_weir_surface_water_parameters
  public :: fixed_weir_storage_from_level
  public :: fixed_weir_level_from_storage

contains

  pure logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  pure subroutine validate_fixed_weir_surface_water_parameters(parameters, ok)
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    logical, intent(out) :: ok
    integer :: i, n

    ok = .false.
    if (.not. allocated(parameters%level_knots) .or. .not. allocated(parameters%storage_knots)) return
    n = size(parameters%level_knots)
    if (n /= 22 .or. size(parameters%storage_knots) /= n) return
    if (any(.not. ieee_is_finite(parameters%level_knots))) return
    if (any(.not. ieee_is_finite(parameters%storage_knots))) return
    if (.not. ieee_is_finite(parameters%weir_head) .or. .not. ieee_is_finite(parameters%rating_coefficient) .or. &
        .not. ieee_is_finite(parameters%rating_exponent) .or. .not. ieee_is_finite(parameters%supply_dip)) return
    if (parameters%rating_coefficient <= 0.0_real64) return
    if (parameters%rating_exponent < 0.5_real64 .or. parameters%rating_exponent > 3.0_real64) return
    if (parameters%supply_dip < 0.0_real64) return
    do i = 1, n - 1
      if (parameters%level_knots(i) <= parameters%level_knots(i+1)) return
      if (parameters%storage_knots(i) <= parameters%storage_knots(i+1)) return
    end do
    if (parameters%storage_knots(n) < 0.0_real64) return
    if (parameters%weir_head > parameters%level_knots(1) .or. &
        parameters%weir_head < parameters%level_knots(n)) return
    if (parameters%weir_head - parameters%supply_dip > parameters%level_knots(1) .or. &
        parameters%weir_head - parameters%supply_dip < parameters%level_knots(n)) return
    ok = .true.
  end subroutine validate_fixed_weir_surface_water_parameters

  pure subroutine fixed_weir_storage_from_level(parameters, level, storage, ok, exact_knot)
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: level
    real(real64), intent(out) :: storage
    logical, intent(out) :: ok
    logical, intent(out), optional :: exact_knot
    integer :: i, n
    real(real64) :: fraction
    logical :: exact

    storage = 0.0_real64
    ok = .false.
    exact = .false.
    if (present(exact_knot)) exact_knot = .false.
    if (.not. ieee_is_finite(level)) return
    if (.not. allocated(parameters%level_knots) .or. .not. allocated(parameters%storage_knots)) return
    n = size(parameters%level_knots)
    if (n < 2 .or. size(parameters%storage_knots) /= n) return
    if (level > parameters%level_knots(1) .or. level < parameters%level_knots(n)) return

    ! D7 explicitly treats stored knot pairs as authoritative coordinates.
    ! This is a named disposition of the frozen D1 endpoint-rounding seam,
    ! not a tolerance, clamp or hidden change of the admissible domain.
    do i = 1, n
      if (same_real_bits(level, parameters%level_knots(i))) then
        storage = parameters%storage_knots(i)
        exact = .true.
        ok = ieee_is_finite(storage)
        if (present(exact_knot)) exact_knot = exact
        return
      end if
    end do

    do i = 1, n - 1
      if (level < parameters%level_knots(i) .and. level > parameters%level_knots(i+1)) then
        fraction = (level - parameters%level_knots(i+1)) / &
                   (parameters%level_knots(i) - parameters%level_knots(i+1))
        storage = parameters%storage_knots(i+1) + fraction * &
                  (parameters%storage_knots(i) - parameters%storage_knots(i+1))
        ok = ieee_is_finite(storage)
        if (present(exact_knot)) exact_knot = exact
        return
      end if
    end do
  end subroutine fixed_weir_storage_from_level

  pure subroutine fixed_weir_level_from_storage(parameters, storage, level, ok, exact_knot)
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: storage
    real(real64), intent(out) :: level
    logical, intent(out) :: ok
    logical, intent(out), optional :: exact_knot
    integer :: i, n
    real(real64) :: fraction
    logical :: exact

    level = 0.0_real64
    ok = .false.
    exact = .false.
    if (present(exact_knot)) exact_knot = .false.
    if (.not. ieee_is_finite(storage)) return
    if (.not. allocated(parameters%level_knots) .or. .not. allocated(parameters%storage_knots)) return
    n = size(parameters%storage_knots)
    if (n < 2 .or. size(parameters%level_knots) /= n) return
    if (storage > parameters%storage_knots(1) .or. storage < parameters%storage_knots(n)) return

    do i = 1, n
      if (same_real_bits(storage, parameters%storage_knots(i))) then
        level = parameters%level_knots(i)
        exact = .true.
        ok = ieee_is_finite(level)
        if (present(exact_knot)) exact_knot = exact
        return
      end if
    end do

    do i = 1, n - 1
      if (storage < parameters%storage_knots(i) .and. storage > parameters%storage_knots(i+1)) then
        fraction = (storage - parameters%storage_knots(i+1)) / &
                   (parameters%storage_knots(i) - parameters%storage_knots(i+1))
        level = parameters%level_knots(i+1) + fraction * &
                (parameters%level_knots(i) - parameters%level_knots(i+1))
        ok = ieee_is_finite(level)
        if (present(exact_knot)) exact_knot = exact
        return
      end if
    end do
  end subroutine fixed_weir_level_from_storage

  pure real(real64) function rating_rate(parameters, level) result(rate)
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: level
    real(real64) :: excess

    excess = max(0.0_real64, level - parameters%weir_head)
    rate = parameters%rating_coefficient * excess**parameters%rating_exponent
  end function rating_rate

  pure subroutine evaluate_restricted_fixed_weir_surface_water(parameters, numerical, base_state, forcing, &
                                                                step_duration, result)
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    type(fixed_weir_surface_water_numerical_config_t), intent(in) :: numerical
    type(fixed_weir_surface_water_state_t), intent(in) :: base_state
    type(fixed_weir_surface_water_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: step_duration
    type(fixed_weir_surface_water_result_t), intent(out) :: result

    real(real64) :: projected, supply_target, target_storage, required_supply
    real(real64) :: lo, hi, mid, storage_mid, residual_mid, tolerance, scale
    real(real64) :: top_capacity, discharge_rating
    logical :: ok, exact, exact_any
    integer :: iteration

    result = fixed_weir_surface_water_result_t()
    exact_any = .false.

    call validate_fixed_weir_surface_water_parameters(parameters, ok)
    if (.not. ok) then
      result%status = FIXED_WEIR_INVALID_INPUT
      result%route = 'invalid-parameters'
      return
    end if
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64 .or. &
        .not. ieee_is_finite(base_state%storage) .or. &
        .not. ieee_is_finite(forcing%secondary_drainage_rate) .or. &
        .not. ieee_is_finite(forcing%supply_capacity_rate)) then
      result%status = FIXED_WEIR_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if
    if (forcing%secondary_drainage_rate < 0.0_real64 .or. forcing%supply_capacity_rate < 0.0_real64) then
      result%status = FIXED_WEIR_INVALID_INPUT
      result%route = 'held-signed-route'
      return
    end if
    if (numerical%max_bisection_iterations <= 0 .or. &
        .not. ieee_is_finite(numerical%rating_storage_abs_tolerance) .or. &
        .not. ieee_is_finite(numerical%rating_storage_rel_tolerance) .or. &
        numerical%rating_storage_abs_tolerance <= 0.0_real64 .or. &
        numerical%rating_storage_rel_tolerance < 0.0_real64) then
      result%status = FIXED_WEIR_INVALID_INPUT
      result%route = 'invalid-numerics'
      return
    end if
    if (base_state%storage < parameters%storage_knots(size(parameters%storage_knots)) .or. &
        base_state%storage > parameters%storage_knots(1)) then
      result%status = FIXED_WEIR_MAPPING_REJECTED
      result%route = 'base-storage-domain'
      return
    end if

    call fixed_weir_storage_from_level(parameters, parameters%weir_head - parameters%supply_dip, &
                                       supply_target, ok, exact)
    if (.not. ok) then
      result%status = FIXED_WEIR_MAPPING_REJECTED
      result%route = 'supply-target-domain'
      return
    end if
    exact_any = exact_any .or. exact
    call fixed_weir_storage_from_level(parameters, parameters%weir_head, target_storage, ok, exact)
    if (.not. ok) then
      result%status = FIXED_WEIR_MAPPING_REJECTED
      result%route = 'weir-target-domain'
      return
    end if
    exact_any = exact_any .or. exact

    projected = base_state%storage + step_duration * forcing%secondary_drainage_rate
    if (.not. ieee_is_finite(projected)) then
      result%status = FIXED_WEIR_INVALID_INPUT
      result%route = 'projection-nonfinite'
      return
    end if

    if (projected < supply_target) then
      required_supply = max(0.0_real64, (supply_target - projected) / step_duration)
      result%supply_rate = min(forcing%supply_capacity_rate, required_supply)
      projected = projected + step_duration * result%supply_rate
    end if

    if (projected < parameters%storage_knots(size(parameters%storage_knots))) then
      result%status = FIXED_WEIR_NO_FEASIBLE_STATE
      result%route = 'storage-below-domain'
      return
    end if

    if (projected <= target_storage) then
      if (projected > parameters%storage_knots(1)) then
        result%status = FIXED_WEIR_NO_FEASIBLE_STATE
        result%route = 'storage-above-domain'
        return
      end if
      result%candidate_state%storage = projected
      call fixed_weir_level_from_storage(parameters, result%candidate_state%storage, result%water_level, ok, exact)
      if (.not. ok) then
        result%status = FIXED_WEIR_MAPPING_REJECTED
        result%route = 'inverse-mapping-rejected'
        return
      end if
      exact_any = exact_any .or. exact
      result%discharge_rate = 0.0_real64
      result%mass_residual = result%candidate_state%storage - base_state%storage - &
           step_duration * (forcing%secondary_drainage_rate + result%supply_rate - result%discharge_rate)
      result%rating_storage_residual = 0.0_real64
      result%exact_knot_policy_used = exact_any
      result%status = FIXED_WEIR_AVAILABLE
      if (result%supply_rate > 0.0_real64) then
        result%route = 'supply-no-discharge'
      else
        result%route = 'no-discharge'
      end if
      return
    end if

    top_capacity = parameters%storage_knots(1) + step_duration * rating_rate(parameters, parameters%level_knots(1))
    if (.not. ieee_is_finite(top_capacity) .or. projected > top_capacity) then
      result%status = FIXED_WEIR_NO_FEASIBLE_STATE
      result%route = 'rating-overflow'
      return
    end if

    lo = parameters%weir_head
    hi = parameters%level_knots(1)
    mid = 0.5_real64 * (lo + hi)
    residual_mid = huge(0.0_real64)
    do iteration = 1, numerical%max_bisection_iterations
      mid = 0.5_real64 * (lo + hi)
      if (same_real_bits(mid, lo) .or. same_real_bits(mid, hi)) exit
      call fixed_weir_storage_from_level(parameters, mid, storage_mid, ok, exact)
      if (.not. ok) then
        result%status = FIXED_WEIR_MAPPING_REJECTED
        result%route = 'root-mapping-rejected'
        return
      end if
      exact_any = exact_any .or. exact
      residual_mid = storage_mid + step_duration * rating_rate(parameters, mid) - projected
      scale = max(1.0_real64, abs(projected), abs(storage_mid))
      tolerance = numerical%rating_storage_abs_tolerance + numerical%rating_storage_rel_tolerance * scale
      if (abs(residual_mid) <= tolerance) exit
      if (residual_mid > 0.0_real64) then
        hi = mid
      else
        lo = mid
      end if
    end do
    result%bisection_iterations = min(iteration, numerical%max_bisection_iterations)

    call fixed_weir_storage_from_level(parameters, mid, storage_mid, ok, exact)
    if (.not. ok) then
      result%status = FIXED_WEIR_MAPPING_REJECTED
      result%route = 'root-final-mapping'
      return
    end if
    exact_any = exact_any .or. exact
    discharge_rating = rating_rate(parameters, mid)
    residual_mid = storage_mid + step_duration * discharge_rating - projected
    scale = max(1.0_real64, abs(projected), abs(storage_mid))
    tolerance = numerical%rating_storage_abs_tolerance + numerical%rating_storage_rel_tolerance * scale
    if (.not. ieee_is_finite(residual_mid) .or. abs(residual_mid) > tolerance) then
      result%status = FIXED_WEIR_NUMERICAL_REJECTED
      result%route = 'root-not-converged'
      return
    end if

    result%candidate_state%storage = storage_mid
    result%water_level = mid
    ! The accepted discharge is derived from the exact storage mass equation.
    ! The rating-law mismatch remains a separate numerical residual and may
    ! never be used as a water-balance concession.
    result%discharge_rate = (projected - result%candidate_state%storage) / step_duration
    if (.not. ieee_is_finite(result%discharge_rate) .or. result%discharge_rate < 0.0_real64) then
      result%status = FIXED_WEIR_NUMERICAL_REJECTED
      result%route = 'discharge-invalid'
      return
    end if
    result%mass_residual = result%candidate_state%storage - base_state%storage - &
         step_duration * (forcing%secondary_drainage_rate + result%supply_rate - result%discharge_rate)
    result%rating_storage_residual = result%discharge_rate - discharge_rating
    result%exact_knot_policy_used = exact_any
    result%status = FIXED_WEIR_AVAILABLE
    result%route = 'power-rating-discharge'
  end subroutine evaluate_restricted_fixed_weir_surface_water

end module mod_restricted_fixed_weir_surface_water
