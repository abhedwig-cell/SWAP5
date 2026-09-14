module mod_drainage_ernst_ipos45_preparation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ERNST_PREP_OK = 0
  integer, parameter, public :: ERNST_PREP_INVALID_PARAMETERS = 1
  integer, parameter, public :: ERNST_PREP_NUMERICAL_DOMAIN = 2

  type, public :: ernst_ipos4_geometry_t
    real(real64) :: drain_spacing = 0.0_real64
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: impermeable_base_level = 0.0_real64
    real(real64) :: interface_level = 0.0_real64
    real(real64) :: horizontal_conductivity_bottom = 0.0_real64
    real(real64) :: vertical_conductivity_top = 0.0_real64
    real(real64) :: vertical_conductivity_bottom = 0.0_real64
    real(real64) :: wetted_perimeter = 0.0_real64
    real(real64) :: entry_resistance = 0.0_real64
  end type ernst_ipos4_geometry_t

  type, public :: ernst_ipos5_geometry_t
    real(real64) :: drain_spacing = 0.0_real64
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: impermeable_base_level = 0.0_real64
    real(real64) :: interface_level = 0.0_real64
    real(real64) :: horizontal_conductivity_top = 0.0_real64
    real(real64) :: horizontal_conductivity_bottom = 0.0_real64
    real(real64) :: vertical_conductivity_top = 0.0_real64
    real(real64) :: wetted_perimeter = 0.0_real64
    real(real64) :: geometry_factor = 0.0_real64
    real(real64) :: entry_resistance = 0.0_real64
  end type ernst_ipos5_geometry_t

  type, public :: ernst_ipos4_prepared_t
    logical :: is_valid = .false.
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: interface_level = 0.0_real64
    real(real64) :: vertical_conductivity_top = 0.0_real64
    real(real64) :: vertical_conductivity_bottom = 0.0_real64
    real(real64) :: effective_base_level = 0.0_real64
    real(real64) :: depth_below_drain = 0.0_real64
    real(real64) :: horizontal_resistance = 0.0_real64
    real(real64) :: radial_resistance = 0.0_real64
    real(real64) :: fixed_resistance = 0.0_real64
  end type ernst_ipos4_prepared_t

  type, public :: ernst_ipos5_prepared_t
    logical :: is_valid = .false.
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: interface_level = 0.0_real64
    real(real64) :: vertical_conductivity_top = 0.0_real64
    real(real64) :: effective_base_level = 0.0_real64
    real(real64) :: depth_below_drain = 0.0_real64
    real(real64) :: horizontal_resistance_denominator = 0.0_real64
    real(real64) :: horizontal_resistance = 0.0_real64
    real(real64) :: radial_log_argument = 0.0_real64
    real(real64) :: radial_resistance = 0.0_real64
    real(real64) :: fixed_resistance = 0.0_real64
  end type ernst_ipos5_prepared_t

  type, public :: ernst_preparation_diagnostics_t
    integer :: status = ERNST_PREP_OK
    logical :: prepared = .false.
    logical :: radial_resistance_negative = .false.
    logical :: immutable_parameter_cache = .true.
    logical :: persistent_process_state = .false.
  end type ernst_preparation_diagnostics_t

  public :: prepare_ernst_ipos4
  public :: prepare_ernst_ipos5

contains

  subroutine prepare_ernst_ipos4(geometry, prepared, diagnostics)
    type(ernst_ipos4_geometry_t), intent(in) :: geometry
    type(ernst_ipos4_prepared_t), intent(out) :: prepared
    type(ernst_preparation_diagnostics_t), intent(out) :: diagnostics

    real(real64), parameter :: pi = acos(-1.0_real64)
    real(real64) :: effective_base, depth_below_drain, rhor, rrad, fixed

    prepared = ernst_ipos4_prepared_t()
    diagnostics = ernst_preparation_diagnostics_t()

    if (.not. valid_ipos4_geometry(geometry)) then
      diagnostics%status = ERNST_PREP_INVALID_PARAMETERS
      return
    end if

    effective_base = max(geometry%impermeable_base_level, &
         geometry%drain_bottom_level - 0.25_real64 * geometry%drain_spacing)
    depth_below_drain = geometry%drain_bottom_level - effective_base
    if (.not. ieee_is_finite(depth_below_drain) .or. .not. (depth_below_drain > 0.0_real64)) then
      diagnostics%status = ERNST_PREP_NUMERICAL_DOMAIN
      return
    end if

    rhor = geometry%drain_spacing**2 / &
         (8.0_real64 * geometry%horizontal_conductivity_bottom * depth_below_drain)
    rrad = geometry%drain_spacing / &
         (pi * sqrt(geometry%horizontal_conductivity_bottom * geometry%vertical_conductivity_bottom)) * &
         log(depth_below_drain / geometry%wetted_perimeter)
    fixed = rhor + rrad + geometry%entry_resistance

    if (.not. ieee_is_finite(rhor) .or. .not. ieee_is_finite(rrad) .or. .not. ieee_is_finite(fixed)) then
      diagnostics%status = ERNST_PREP_NUMERICAL_DOMAIN
      return
    end if

    prepared%is_valid = .true.
    prepared%shape_factor = geometry%shape_factor
    prepared%drain_bottom_level = geometry%drain_bottom_level
    prepared%interface_level = geometry%interface_level
    prepared%vertical_conductivity_top = geometry%vertical_conductivity_top
    prepared%vertical_conductivity_bottom = geometry%vertical_conductivity_bottom
    prepared%effective_base_level = effective_base
    prepared%depth_below_drain = depth_below_drain
    prepared%horizontal_resistance = rhor
    prepared%radial_resistance = rrad
    prepared%fixed_resistance = fixed

    diagnostics%prepared = .true.
    diagnostics%radial_resistance_negative = rrad < 0.0_real64
  end subroutine prepare_ernst_ipos4

  subroutine prepare_ernst_ipos5(geometry, prepared, diagnostics)
    type(ernst_ipos5_geometry_t), intent(in) :: geometry
    type(ernst_ipos5_prepared_t), intent(out) :: prepared
    type(ernst_preparation_diagnostics_t), intent(out) :: diagnostics

    real(real64), parameter :: pi = acos(-1.0_real64)
    real(real64) :: effective_base, depth_below_drain, hden, logarg, rhor, rrad, fixed

    prepared = ernst_ipos5_prepared_t()
    diagnostics = ernst_preparation_diagnostics_t()

    if (.not. valid_ipos5_geometry(geometry)) then
      diagnostics%status = ERNST_PREP_INVALID_PARAMETERS
      return
    end if

    effective_base = max(geometry%impermeable_base_level, &
         geometry%drain_bottom_level - 0.25_real64 * geometry%drain_spacing)
    depth_below_drain = geometry%drain_bottom_level - effective_base
    if (.not. ieee_is_finite(depth_below_drain) .or. depth_below_drain < 0.0_real64) then
      diagnostics%status = ERNST_PREP_NUMERICAL_DOMAIN
      return
    end if

    hden = 8.0_real64 * geometry%horizontal_conductivity_top * &
         (geometry%drain_bottom_level - geometry%interface_level) + &
         8.0_real64 * geometry%horizontal_conductivity_bottom * &
         (geometry%interface_level - effective_base)
    logarg = geometry%geometry_factor * &
         (geometry%drain_bottom_level - geometry%interface_level) / geometry%wetted_perimeter

    if (.not. ieee_is_finite(hden) .or. .not. (hden > 0.0_real64) .or. &
         .not. ieee_is_finite(logarg) .or. .not. (logarg > 0.0_real64)) then
      diagnostics%status = ERNST_PREP_NUMERICAL_DOMAIN
      return
    end if

    rhor = geometry%drain_spacing**2 / hden
    rrad = geometry%drain_spacing / &
         (pi * sqrt(geometry%horizontal_conductivity_top * geometry%vertical_conductivity_top)) * log(logarg)
    fixed = rhor + rrad + geometry%entry_resistance

    if (.not. ieee_is_finite(rhor) .or. .not. ieee_is_finite(rrad) .or. .not. ieee_is_finite(fixed)) then
      diagnostics%status = ERNST_PREP_NUMERICAL_DOMAIN
      return
    end if

    prepared%is_valid = .true.
    prepared%shape_factor = geometry%shape_factor
    prepared%drain_bottom_level = geometry%drain_bottom_level
    prepared%interface_level = geometry%interface_level
    prepared%vertical_conductivity_top = geometry%vertical_conductivity_top
    prepared%effective_base_level = effective_base
    prepared%depth_below_drain = depth_below_drain
    prepared%horizontal_resistance_denominator = hden
    prepared%horizontal_resistance = rhor
    prepared%radial_log_argument = logarg
    prepared%radial_resistance = rrad
    prepared%fixed_resistance = fixed

    diagnostics%prepared = .true.
    diagnostics%radial_resistance_negative = rrad < 0.0_real64
  end subroutine prepare_ernst_ipos5

  logical function valid_ipos4_geometry(geometry) result(valid)
    type(ernst_ipos4_geometry_t), intent(in) :: geometry

    valid = ieee_is_finite(geometry%drain_spacing) .and. ieee_is_finite(geometry%shape_factor) .and. &
         ieee_is_finite(geometry%drain_bottom_level) .and. ieee_is_finite(geometry%impermeable_base_level) .and. &
         ieee_is_finite(geometry%interface_level) .and. ieee_is_finite(geometry%horizontal_conductivity_bottom) .and. &
         ieee_is_finite(geometry%vertical_conductivity_top) .and. &
         ieee_is_finite(geometry%vertical_conductivity_bottom) .and. &
         ieee_is_finite(geometry%wetted_perimeter) .and. ieee_is_finite(geometry%entry_resistance)
    if (.not. valid) return

    valid = geometry%drain_spacing > 0.0_real64 .and. geometry%shape_factor > 0.0_real64 .and. &
         geometry%impermeable_base_level < geometry%drain_bottom_level .and. &
         geometry%drain_bottom_level <= geometry%interface_level .and. &
         geometry%horizontal_conductivity_bottom > 0.0_real64 .and. &
         geometry%vertical_conductivity_top > 0.0_real64 .and. &
         geometry%vertical_conductivity_bottom > 0.0_real64 .and. &
         geometry%wetted_perimeter > 0.0_real64 .and. geometry%entry_resistance >= 0.0_real64
  end function valid_ipos4_geometry

  logical function valid_ipos5_geometry(geometry) result(valid)
    type(ernst_ipos5_geometry_t), intent(in) :: geometry

    valid = ieee_is_finite(geometry%drain_spacing) .and. ieee_is_finite(geometry%shape_factor) .and. &
         ieee_is_finite(geometry%drain_bottom_level) .and. ieee_is_finite(geometry%impermeable_base_level) .and. &
         ieee_is_finite(geometry%interface_level) .and. ieee_is_finite(geometry%horizontal_conductivity_top) .and. &
         ieee_is_finite(geometry%horizontal_conductivity_bottom) .and. &
         ieee_is_finite(geometry%vertical_conductivity_top) .and. ieee_is_finite(geometry%wetted_perimeter) .and. &
         ieee_is_finite(geometry%geometry_factor) .and. ieee_is_finite(geometry%entry_resistance)
    if (.not. valid) return

    valid = geometry%drain_spacing > 0.0_real64 .and. geometry%shape_factor > 0.0_real64 .and. &
         geometry%impermeable_base_level <= geometry%drain_bottom_level .and. &
         geometry%drain_bottom_level > geometry%interface_level .and. &
         geometry%horizontal_conductivity_top > 0.0_real64 .and. &
         geometry%horizontal_conductivity_bottom >= 0.0_real64 .and. &
         geometry%vertical_conductivity_top > 0.0_real64 .and. geometry%wetted_perimeter > 0.0_real64 .and. &
         geometry%geometry_factor > 0.0_real64 .and. geometry%entry_resistance >= 0.0_real64
  end function valid_ipos5_geometry

end module mod_drainage_ernst_ipos45_preparation
