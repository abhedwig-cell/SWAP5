module mod_crop_root_geometry_snapshot_producer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_nonadaptive_crop_root_view_producer, only: crop_root_geometry_snapshot_t
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_GEOMETRY_OK = 0
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH = 1
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_DVS = 2
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_ROOT_BIOMASS = 3
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_COMMITTED_DEPTH = 4
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_TABLE = 5
  integer, parameter, public :: CROP_ROOT_GEOMETRY_INVALID_DERIVED_DEPTH = 6

  integer, parameter, public :: CROP_ROOT_MODE_SWRD1 = 1
  integer, parameter, public :: CROP_ROOT_MODE_SWRD2 = 2
  integer, parameter, public :: CROP_ROOT_MODE_SWRD3 = 3

  type, public :: root_depth_table_t
    real(real64), allocatable :: x(:)
    real(real64), allocatable :: root_depth(:)
  end type root_depth_table_t

  type, public :: crop_root_geometry_diagnostics_t
    integer :: status = CROP_ROOT_GEOMETRY_OK
    integer :: mode = 0
    logical :: committed_crop_state_consumed = .false.
    logical :: interpolation_table_consumed = .false.
    logical :: built = .false.
  end type crop_root_geometry_diagnostics_t

  public :: build_swrd1_root_geometry_snapshot
  public :: build_swrd2_root_geometry_snapshot
  public :: build_swrd3_root_geometry_snapshot

contains

  subroutine build_swrd1_root_geometry_snapshot(crop_emerged, dvs, maximum_root_depth, table, snapshot, diagnostics)
    logical, intent(in) :: crop_emerged
    real(real64), intent(in) :: dvs
    real(real64), intent(in) :: maximum_root_depth
    type(root_depth_table_t), intent(in) :: table
    type(crop_root_geometry_snapshot_t), intent(out) :: snapshot
    type(crop_root_geometry_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: depth

    snapshot = crop_root_geometry_snapshot_t()
    diagnostics = crop_root_geometry_diagnostics_t()
    diagnostics%mode = CROP_ROOT_MODE_SWRD1

    if (.not. crop_emerged) then
      diagnostics%built = .true.
      return
    end if

    diagnostics%committed_crop_state_consumed = .true.
    if (.not. valid_maximum_depth(maximum_root_depth)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH
      return
    end if
    if (.not. ieee_is_finite(dvs)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_DVS
      return
    end if
    if (.not. valid_depth_table(table)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_TABLE
      return
    end if
    diagnostics%interpolation_table_consumed = .true.

    depth = table_value(table, dvs)
    if (.not. ieee_is_finite(depth) .or. depth < 0.0_real64) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_DERIVED_DEPTH
      return
    end if

    snapshot%crop_emerged = .true.
    snapshot%current_root_depth = min(depth, maximum_root_depth)
    diagnostics%built = .true.
  end subroutine build_swrd1_root_geometry_snapshot

  subroutine build_swrd2_root_geometry_snapshot(crop_emerged, committed_root_depth, maximum_root_depth, snapshot, diagnostics)
    logical, intent(in) :: crop_emerged
    real(real64), intent(in) :: committed_root_depth
    real(real64), intent(in) :: maximum_root_depth
    type(crop_root_geometry_snapshot_t), intent(out) :: snapshot
    type(crop_root_geometry_diagnostics_t), intent(out) :: diagnostics

    snapshot = crop_root_geometry_snapshot_t()
    diagnostics = crop_root_geometry_diagnostics_t()
    diagnostics%mode = CROP_ROOT_MODE_SWRD2

    if (.not. crop_emerged) then
      diagnostics%built = .true.
      return
    end if

    diagnostics%committed_crop_state_consumed = .true.
    if (.not. valid_maximum_depth(maximum_root_depth)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH
      return
    end if
    if (.not. ieee_is_finite(committed_root_depth) .or. committed_root_depth < 0.0_real64 .or. &
        committed_root_depth > maximum_root_depth) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_COMMITTED_DEPTH
      return
    end if

    snapshot%crop_emerged = .true.
    snapshot%current_root_depth = committed_root_depth
    diagnostics%built = .true.
  end subroutine build_swrd2_root_geometry_snapshot

  subroutine build_swrd3_root_geometry_snapshot(crop_emerged, actual_root_biomass, maximum_root_depth, table, &
                                                 snapshot, diagnostics)
    logical, intent(in) :: crop_emerged
    real(real64), intent(in) :: actual_root_biomass
    real(real64), intent(in) :: maximum_root_depth
    type(root_depth_table_t), intent(in) :: table
    type(crop_root_geometry_snapshot_t), intent(out) :: snapshot
    type(crop_root_geometry_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: depth

    snapshot = crop_root_geometry_snapshot_t()
    diagnostics = crop_root_geometry_diagnostics_t()
    diagnostics%mode = CROP_ROOT_MODE_SWRD3

    if (.not. crop_emerged) then
      diagnostics%built = .true.
      return
    end if

    diagnostics%committed_crop_state_consumed = .true.
    if (.not. valid_maximum_depth(maximum_root_depth)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH
      return
    end if
    if (.not. ieee_is_finite(actual_root_biomass) .or. actual_root_biomass < 0.0_real64) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_ROOT_BIOMASS
      return
    end if
    if (.not. valid_depth_table(table)) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_TABLE
      return
    end if
    diagnostics%interpolation_table_consumed = .true.

    depth = table_value(table, actual_root_biomass)
    if (.not. ieee_is_finite(depth) .or. depth < 0.0_real64) then
      diagnostics%status = CROP_ROOT_GEOMETRY_INVALID_DERIVED_DEPTH
      return
    end if

    snapshot%crop_emerged = .true.
    snapshot%current_root_depth = min(depth, maximum_root_depth)
    diagnostics%built = .true.
  end subroutine build_swrd3_root_geometry_snapshot

  logical function valid_maximum_depth(maximum_root_depth) result(valid)
    real(real64), intent(in) :: maximum_root_depth
    valid = ieee_is_finite(maximum_root_depth) .and. maximum_root_depth > 0.0_real64
  end function valid_maximum_depth

  logical function valid_depth_table(table) result(valid)
    type(root_depth_table_t), intent(in) :: table
    integer :: i, n

    valid = .false.
    if (.not. allocated(table%x) .or. .not. allocated(table%root_depth)) return
    n = size(table%x)
    if (n < 2 .or. size(table%root_depth) /= n) return
    if (.not. all(ieee_is_finite(table%x)) .or. .not. all(ieee_is_finite(table%root_depth))) return
    if (any(table%root_depth < 0.0_real64)) return
    do i = 2, n
      if (table%x(i) <= table%x(i - 1)) return
    end do
    valid = .true.
  end function valid_depth_table

  real(real64) function table_value(table, query) result(value)
    type(root_depth_table_t), intent(in) :: table
    real(real64), intent(in) :: query
    integer :: i, n
    real(real64) :: slope

    n = size(table%x)
    if (query <= table%x(1)) then
      value = table%root_depth(1)
      return
    end if
    do i = 2, n
      if (query <= table%x(i)) then
        slope = (table%root_depth(i) - table%root_depth(i - 1)) / (table%x(i) - table%x(i - 1))
        value = table%root_depth(i - 1) + (query - table%x(i - 1)) * slope
        return
      end if
    end do
    value = table%root_depth(n)
  end function table_value

end module mod_crop_root_geometry_snapshot_producer
