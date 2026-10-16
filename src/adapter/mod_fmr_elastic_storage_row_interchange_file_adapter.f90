module mod_fmr_elastic_storage_row_interchange_file_adapter
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: iostat_end, real64
  use mod_fmr_elastic_storage_explicit_profile_source, only: fmr_elastic_storage_bro_horizon_row_t
  use mod_fmr_elastic_storage_horizon_node_mapper, only: FMR_ELAS_GEOMETRY_TOL_M
  implicit none
  private

  character(len=*), parameter, public :: FMR_ELAS_ROWS_MAGIC = 'SWAP5_ELASTIC33_BRO_ROWS_V1'
  character(len=*), parameter, public :: FMR_ELAS_ROWS_SOURCE_HASH = &
       'f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6'
  character(len=*), parameter, public :: FMR_ELAS_ROWS_COLUMNS = &
       'normalsoilprofile_id|layer_number|top_depth_m|bottom_depth_m|staringseriesblock|' // &
       'rho_dry_g_cm3|organic_matter_available|organic_matter_pct|peat_type_present'

  integer, parameter, public :: FMR_ELAS_ROWS_FILE_OK = 0
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_MISSING_PATH = 1
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_OPEN_FAILED = 2
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_IO_FAILED = 3
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_INVALID_HEADER = 4
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_INVALID_ROW = 5
  integer, parameter, public :: FMR_ELAS_ROWS_FILE_EXTRA_RECORD = 6

  integer, parameter :: LINE_LEN = 4096

  type, public :: fmr_elastic_storage_row_file_diagnostics_t
    integer :: status = FMR_ELAS_ROWS_FILE_MISSING_PATH
    integer :: profile_id = 0
    integer :: expected_rows = 0
    integer :: parsed_rows = 0
    integer :: failed_row = 0
  end type fmr_elastic_storage_row_file_diagnostics_t

  public :: fmr_read_elastic_storage_row_interchange_file

contains

  subroutine fmr_read_elastic_storage_row_interchange_file(path, rows, diagnostics)
    character(len=*), intent(in) :: path
    type(fmr_elastic_storage_bro_horizon_row_t), allocatable, intent(out) :: rows(:)
    type(fmr_elastic_storage_row_file_diagnostics_t), intent(out) :: diagnostics

    character(len=LINE_LEN) :: line
    integer :: unit, ios, profile_id, row_count, i
    real(real64) :: previous_bottom
    logical :: exists

    if (allocated(rows)) deallocate(rows)
    diagnostics = fmr_elastic_storage_row_file_diagnostics_t()

    if (len_trim(path) == 0) return
    inquire(file=trim(path), exist=exists, iostat=ios)
    if (ios /= 0 .or. .not. exists) then
      diagnostics%status = FMR_ELAS_ROWS_FILE_OPEN_FAILED
      return
    end if

    open(newunit=unit, file=trim(path), status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) then
      diagnostics%status = FMR_ELAS_ROWS_FILE_OPEN_FAILED
      return
    end if

    call read_required_line(unit, line, ios)
    if (ios /= 0 .or. trim(line) /= FMR_ELAS_ROWS_MAGIC) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if

    call read_required_line(unit, line, ios)
    if (ios /= 0 .or. trim(line) /= 'source_artifact_sha256=' // FMR_ELAS_ROWS_SOURCE_HASH) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if

    call read_required_line(unit, line, ios)
    if (ios /= 0 .or. .not. parse_prefixed_integer(trim(line), 'normalsoilprofile_id=', profile_id)) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if
    if (profile_id <= 0) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if
    diagnostics%profile_id = profile_id

    call read_required_line(unit, line, ios)
    if (ios /= 0 .or. .not. parse_prefixed_integer(trim(line), 'row_count=', row_count)) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if
    if (row_count <= 0) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if
    diagnostics%expected_rows = row_count

    call read_required_line(unit, line, ios)
    if (ios /= 0 .or. trim(line) /= 'columns=' // FMR_ELAS_ROWS_COLUMNS) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_HEADER)
      return
    end if

    allocate(rows(row_count))
    previous_bottom = 0.0_real64
    do i = 1, row_count
      call read_required_line(unit, line, ios)
      if (ios /= 0) then
        diagnostics%failed_row = i
        call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_IO_FAILED)
        return
      end if
      if (.not. parse_row(trim(line), profile_id, i, previous_bottom, rows(i))) then
        diagnostics%failed_row = i
        call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_INVALID_ROW)
        return
      end if
      previous_bottom = rows(i)%bottom_depth_m
      diagnostics%parsed_rows = i
    end do

    read(unit, '(A)', iostat=ios) line
    if (ios /= iostat_end) then
      call fail_close(unit, rows, diagnostics, FMR_ELAS_ROWS_FILE_EXTRA_RECORD)
      return
    end if

    close(unit)
    diagnostics%status = FMR_ELAS_ROWS_FILE_OK
  end subroutine fmr_read_elastic_storage_row_interchange_file

  subroutine read_required_line(unit, line, ios)
    integer, intent(in) :: unit
    character(len=*), intent(out) :: line
    integer, intent(out) :: ios
    line = ''
    read(unit, '(A)', iostat=ios) line
  end subroutine read_required_line

  logical function parse_prefixed_integer(line, prefix, value) result(ok)
    character(len=*), intent(in) :: line, prefix
    integer, intent(out) :: value
    integer :: ios, n

    ok = .false.
    value = 0
    n = len(prefix)
    if (len(line) <= n) return
    if (line(1:n) /= prefix) return
    if (index(line(n+1:), '=') /= 0) return
    read(line(n+1:), *, iostat=ios) value
    if (ios /= 0) return
    ok = .true.
  end function parse_prefixed_integer

  logical function parse_row(line, expected_profile_id, expected_layer, previous_bottom, row) result(ok)
    character(len=*), intent(in) :: line
    integer, intent(in) :: expected_profile_id, expected_layer
    real(real64), intent(in) :: previous_bottom
    type(fmr_elastic_storage_bro_horizon_row_t), intent(out) :: row

    character(len=256) :: fields(9)
    integer :: profile_id, layer_number, block, organic_flag, peat_flag
    integer :: ios
    real(real64) :: top_depth, bottom_depth, density, organic_value

    row = fmr_elastic_storage_bro_horizon_row_t()
    ok = .false.
    if (.not. split9(line, fields)) return

    read(fields(1), *, iostat=ios) profile_id
    if (ios /= 0) return
    read(fields(2), *, iostat=ios) layer_number
    if (ios /= 0) return
    read(fields(3), *, iostat=ios) top_depth
    if (ios /= 0) return
    read(fields(4), *, iostat=ios) bottom_depth
    if (ios /= 0) return
    read(fields(5), *, iostat=ios) block
    if (ios /= 0) return
    read(fields(6), *, iostat=ios) density
    if (ios /= 0) return
    read(fields(7), *, iostat=ios) organic_flag
    if (ios /= 0) return
    read(fields(8), *, iostat=ios) organic_value
    if (ios /= 0) return
    read(fields(9), *, iostat=ios) peat_flag
    if (ios /= 0) return

    if (profile_id /= expected_profile_id) return
    if (layer_number /= expected_layer) return
    if (.not. ieee_is_finite(top_depth) .or. .not. ieee_is_finite(bottom_depth)) return
    if (top_depth < 0.0_real64 .or. bottom_depth <= top_depth) return
    if (expected_layer == 1) then
      if (abs(top_depth) > FMR_ELAS_GEOMETRY_TOL_M) return
    else
      if (abs(top_depth - previous_bottom) > FMR_ELAS_GEOMETRY_TOL_M) return
    end if
    if (.not. ieee_is_finite(density) .or. density <= 0.0_real64) return
    if (organic_flag /= 0 .and. organic_flag /= 1) return
    if (peat_flag /= 0 .and. peat_flag /= 1) return
    if (.not. ieee_is_finite(organic_value)) return
    if (organic_flag == 1) then
      if (organic_value < 0.0_real64 .or. organic_value > 100.0_real64) return
    end if

    row%normalsoilprofile_id = profile_id
    row%layer_number = layer_number
    row%top_depth_m = top_depth
    row%bottom_depth_m = bottom_depth
    row%staringseriesblock = block
    row%rho_dry_g_cm3 = density
    row%organic_matter_available = organic_flag == 1
    row%organic_matter_pct = organic_value
    row%peat_type_present = peat_flag == 1
    ok = .true.
  end function parse_row

  logical function split9(line, fields) result(ok)
    character(len=*), intent(in) :: line
    character(len=256), intent(out) :: fields(9)
    integer :: start_at, rel, stop_at, i

    fields = ''
    ok = .false.
    start_at = 1
    do i = 1, 8
      if (start_at > len_trim(line)) return
      rel = index(line(start_at:), '|')
      if (rel <= 0) return
      stop_at = start_at + rel - 2
      if (stop_at < start_at) return
      if (stop_at - start_at + 1 > len(fields(i))) return
      fields(i) = line(start_at:stop_at)
      if (len_trim(fields(i)) == 0) return
      start_at = stop_at + 2
    end do
    if (start_at > len_trim(line)) return
    if (index(line(start_at:), '|') /= 0) return
    if (len_trim(line(start_at:)) > len(fields(9))) return
    fields(9) = line(start_at:)
    if (len_trim(fields(9)) == 0) return
    ok = .true.
  end function split9

  subroutine fail_close(unit, rows, diagnostics, status)
    integer, intent(in) :: unit, status
    type(fmr_elastic_storage_bro_horizon_row_t), allocatable, intent(inout) :: rows(:)
    type(fmr_elastic_storage_row_file_diagnostics_t), intent(inout) :: diagnostics

    close(unit)
    if (allocated(rows)) deallocate(rows)
    diagnostics%status = status
  end subroutine fail_close

end module mod_fmr_elastic_storage_row_interchange_file_adapter
