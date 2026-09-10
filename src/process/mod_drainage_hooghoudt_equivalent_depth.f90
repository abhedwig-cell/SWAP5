module mod_drainage_hooghoudt_equivalent_depth
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: EQDEPTH_OK = 0
  integer, parameter, public :: EQDEPTH_INVALID_PARAMETERS = 1
  integer, parameter, public :: EQDEPTH_NUMERICAL_DOMAIN = 2

  integer, parameter, public :: EQDEPTH_BRANCH_SHALLOW = 1
  integer, parameter, public :: EQDEPTH_BRANCH_ASYMPTOTIC = 2
  integer, parameter, public :: EQDEPTH_BRANCH_SERIES = 3

  real(real64), parameter, public :: EQDEPTH_X_SHALLOW = 1.0e-6_real64
  real(real64), parameter, public :: EQDEPTH_X_SERIES = 0.5_real64

  type, public :: hooghoudt_equivalent_depth_geometry_t
    real(real64) :: drain_spacing = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: impermeable_base_level = 0.0_real64
    real(real64) :: wetted_perimeter = 0.0_real64
  end type hooghoudt_equivalent_depth_geometry_t

  type, public :: hooghoudt_equivalent_depth_prepared_t
    logical :: is_valid = .false.
    real(real64) :: drain_spacing = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: effective_base_level = 0.0_real64
    real(real64) :: depth_below_drain = 0.0_real64
    real(real64) :: wetted_perimeter = 0.0_real64
    real(real64) :: x = 0.0_real64
    real(real64) :: equivalent_depth = 0.0_real64
    integer :: branch = 0
    logical :: clipped_to_depth_below_drain = .false.
    logical :: at_x_shallow_boundary = .false.
    logical :: at_x_series_boundary = .false.
  end type hooghoudt_equivalent_depth_prepared_t

  type, public :: hooghoudt_equivalent_depth_diagnostics_t
    integer :: status = EQDEPTH_OK
    logical :: prepared = .false.
    real(real64) :: raw_equivalent_depth = 0.0_real64
    real(real64) :: formula_denominator = 0.0_real64
    logical :: immutable_parameter_cache = .true.
    logical :: persistent_process_state = .false.
  end type hooghoudt_equivalent_depth_diagnostics_t

  public :: prepare_hooghoudt_equivalent_depth

contains

  subroutine prepare_hooghoudt_equivalent_depth(geometry, prepared, diagnostics)
    type(hooghoudt_equivalent_depth_geometry_t), intent(in) :: geometry
    type(hooghoudt_equivalent_depth_prepared_t), intent(out) :: prepared
    type(hooghoudt_equivalent_depth_diagnostics_t), intent(out) :: diagnostics

    real(real64), parameter :: pi = acos(-1.0_real64)
    real(real64) :: effective_base, depth_below_drain, x, fx, denominator, raw_depth, e
    integer :: i

    prepared = hooghoudt_equivalent_depth_prepared_t()
    diagnostics = hooghoudt_equivalent_depth_diagnostics_t()

    if (.not. valid_geometry(geometry)) then
      diagnostics%status = EQDEPTH_INVALID_PARAMETERS
      return
    end if

    effective_base = max(geometry%impermeable_base_level, &
         geometry%drain_bottom_level - 0.25_real64 * geometry%drain_spacing)
    depth_below_drain = geometry%drain_bottom_level - effective_base
    x = 2.0_real64 * pi * depth_below_drain / geometry%drain_spacing

    if (.not. ieee_is_finite(effective_base) .or. .not. ieee_is_finite(depth_below_drain) .or. &
         .not. ieee_is_finite(x) .or. depth_below_drain < 0.0_real64) then
      diagnostics%status = EQDEPTH_NUMERICAL_DOMAIN
      return
    end if

    denominator = 0.0_real64
    if (x > EQDEPTH_X_SERIES) then
      prepared%branch = EQDEPTH_BRANCH_SERIES
      fx = 0.0_real64
      do i = 1, 5, 2
        e = exp(-2.0_real64 * real(i,real64) * x)
        fx = fx + 4.0_real64 * e / (real(i,real64) * (1.0_real64 - e))
      end do
      denominator = log(geometry%drain_spacing / geometry%wetted_perimeter) + fx
      if (.not. ieee_is_finite(denominator) .or. .not. (denominator > 0.0_real64)) then
        diagnostics%status = EQDEPTH_NUMERICAL_DOMAIN
        return
      end if
      raw_depth = pi * geometry%drain_spacing / (8.0_real64 * denominator)
    else if (x < EQDEPTH_X_SHALLOW) then
      prepared%branch = EQDEPTH_BRANCH_SHALLOW
      raw_depth = depth_below_drain
    else
      prepared%branch = EQDEPTH_BRANCH_ASYMPTOTIC
      fx = pi*pi / (4.0_real64*x) + log(x / (2.0_real64*pi))
      denominator = log(geometry%drain_spacing / geometry%wetted_perimeter) + fx
      if (.not. ieee_is_finite(denominator) .or. .not. (denominator > 0.0_real64)) then
        diagnostics%status = EQDEPTH_NUMERICAL_DOMAIN
        return
      end if
      raw_depth = pi * geometry%drain_spacing / (8.0_real64 * denominator)
    end if

    if (.not. ieee_is_finite(raw_depth) .or. raw_depth < 0.0_real64) then
      diagnostics%status = EQDEPTH_NUMERICAL_DOMAIN
      return
    end if

    prepared%is_valid = .true.
    prepared%drain_spacing = geometry%drain_spacing
    prepared%drain_bottom_level = geometry%drain_bottom_level
    prepared%effective_base_level = effective_base
    prepared%depth_below_drain = depth_below_drain
    prepared%wetted_perimeter = geometry%wetted_perimeter
    prepared%x = x
    prepared%equivalent_depth = min(raw_depth, depth_below_drain)
    prepared%clipped_to_depth_below_drain = raw_depth > depth_below_drain
    prepared%at_x_shallow_boundary = .not. (x < EQDEPTH_X_SHALLOW) .and. .not. (x > EQDEPTH_X_SHALLOW)
    prepared%at_x_series_boundary = .not. (x < EQDEPTH_X_SERIES) .and. .not. (x > EQDEPTH_X_SERIES)

    diagnostics%prepared = .true.
    diagnostics%raw_equivalent_depth = raw_depth
    diagnostics%formula_denominator = denominator
  end subroutine prepare_hooghoudt_equivalent_depth

  logical function valid_geometry(geometry) result(valid)
    type(hooghoudt_equivalent_depth_geometry_t), intent(in) :: geometry

    valid = ieee_is_finite(geometry%drain_spacing) .and. &
         ieee_is_finite(geometry%drain_bottom_level) .and. &
         ieee_is_finite(geometry%impermeable_base_level) .and. &
         ieee_is_finite(geometry%wetted_perimeter)
    if (.not. valid) return

    valid = geometry%drain_spacing > 0.0_real64 .and. &
         geometry%wetted_perimeter > 0.0_real64 .and. &
         geometry%impermeable_base_level <= geometry%drain_bottom_level
  end function valid_geometry

end module mod_drainage_hooghoudt_equivalent_depth
