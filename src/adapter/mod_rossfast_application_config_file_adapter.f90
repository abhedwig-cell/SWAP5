module mod_rossfast_application_config_file_adapter
  use, intrinsic :: iso_fortran_env, only: iostat_end
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t
  implicit none
  private

  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_MISSING_PATH = 1
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_OPEN_FAILED = 2
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_IO_FAILED = 3
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX = 4
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_MULTIPLE_ASSIGNMENTS = 5
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_TOO_LARGE = 6
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_FILE_MAX_BYTES = 4096

  public :: fmr_read_rossfast_application_config_file

contains

  subroutine fmr_read_rossfast_application_config_file(path, config, status)
    character(len=*), intent(in) :: path
    type(fmr_rossfast_application_config_t), intent(out) :: config
    integer, intent(out) :: status
    character(len=FMR_ROSSFAST_CONFIG_FILE_MAX_BYTES) :: line
    character(len=FMR_ROSSFAST_CONFIG_FILE_MAX_BYTES) :: record
    integer :: unit, ios, file_size, equals_at
    integer :: key_length, value_length
    logical :: exists, seen_assignment

    config = fmr_rossfast_application_config_t()
    status = FMR_ROSSFAST_CONFIG_FILE_MISSING_PATH
    if (len_trim(path) == 0) return

    inquire(file=trim(path), exist=exists, size=file_size, iostat=ios)
    if (ios /= 0 .or. .not. exists) then
      status = FMR_ROSSFAST_CONFIG_FILE_OPEN_FAILED
      return
    end if
    if (file_size < 0) then
      status = FMR_ROSSFAST_CONFIG_FILE_IO_FAILED
      return
    end if
    if (file_size > FMR_ROSSFAST_CONFIG_FILE_MAX_BYTES) then
      status = FMR_ROSSFAST_CONFIG_FILE_TOO_LARGE
      return
    end if

    open(newunit=unit, file=trim(path), status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) then
      status = FMR_ROSSFAST_CONFIG_FILE_OPEN_FAILED
      return
    end if

    seen_assignment = .false.
    do
      read(unit, '(A)', iostat=ios) line
      if (ios == iostat_end) exit
      if (ios /= 0) then
        close(unit)
        config = fmr_rossfast_application_config_t()
        status = FMR_ROSSFAST_CONFIG_FILE_IO_FAILED
        return
      end if

      record = adjustl(line)
      if (len_trim(record) == 0) cycle
      if (seen_assignment) then
        close(unit)
        config = fmr_rossfast_application_config_t()
        status = FMR_ROSSFAST_CONFIG_FILE_MULTIPLE_ASSIGNMENTS
        return
      end if

      equals_at = index(record, '=')
      if (equals_at <= 1 .or. equals_at >= len_trim(record)) then
        close(unit)
        config = fmr_rossfast_application_config_t()
        status = FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX
        return
      end if
      if (index(record(equals_at + 1:), '=') /= 0) then
        close(unit)
        config = fmr_rossfast_application_config_t()
        status = FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX
        return
      end if

      key_length = len_trim(record(:equals_at - 1))
      value_length = len_trim(adjustl(record(equals_at + 1:)))
      if (key_length <= 0 .or. value_length <= 0 .or. &
          key_length > len(config%key) .or. value_length > len(config%value)) then
        close(unit)
        config = fmr_rossfast_application_config_t()
        status = FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX
        return
      end if

      config%supplied = .true.
      config%key = trim(record(:equals_at - 1))
      config%value = trim(adjustl(record(equals_at + 1:)))
      seen_assignment = .true.
    end do
    close(unit)

    if (.not. seen_assignment) then
      config = fmr_rossfast_application_config_t()
      status = FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX
      return
    end if

    status = FMR_ROSSFAST_CONFIG_FILE_OK
  end subroutine fmr_read_rossfast_application_config_file

end module mod_rossfast_application_config_file_adapter
