module mod_fmr_elastic_storage_cli_source
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t
  implicit none
  private

  character(len=*), parameter, public :: FMR_ELAS_CLI_OPTION_PREFIX = '--elastic-storage-config='

  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_OK = 0
  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_MULTIPLE = 2
  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_INVALID_SYNTAX = 3
  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_TOO_LONG = 4
  integer, parameter, public :: FMR_ELAS_CLI_SOURCE_READ_FAILED = 5

  public :: fmr_read_elastic_storage_cli_source

contains

  subroutine fmr_read_elastic_storage_cli_source(candidate, status)
    type(fmr_elastic_storage_request_path_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status

    character(len=1024) :: argument
    character(len=512) :: selected_path
    integer :: i, argc, arg_length, arg_status, prefix_length, path_length, matches

    candidate = fmr_elastic_storage_request_path_candidate_t()
    status = FMR_ELAS_CLI_SOURCE_INACTIVE
    selected_path = ''
    matches = 0
    prefix_length = len(FMR_ELAS_CLI_OPTION_PREFIX)

    argc = command_argument_count()
    do i = 1, argc
      argument = ''
      arg_length = 0
      arg_status = 0
      call get_command_argument(i, value=argument, length=arg_length, status=arg_status)
      if (arg_status /= 0) then
        status = FMR_ELAS_CLI_SOURCE_READ_FAILED
        return
      end if

      if (arg_length < prefix_length) cycle
      if (argument(1:prefix_length) /= FMR_ELAS_CLI_OPTION_PREFIX) cycle

      matches = matches + 1
      if (matches > 1) then
        status = FMR_ELAS_CLI_SOURCE_MULTIPLE
        return
      end if

      path_length = arg_length - prefix_length
      if (path_length <= 0) then
        status = FMR_ELAS_CLI_SOURCE_INVALID_SYNTAX
        return
      end if
      if (path_length > len(selected_path)) then
        status = FMR_ELAS_CLI_SOURCE_TOO_LONG
        return
      end if

      selected_path = ''
      selected_path(1:path_length) = argument(prefix_length+1:arg_length)
    end do

    if (matches == 0) return

    candidate%supplied = .true.
    candidate%path = selected_path
    status = FMR_ELAS_CLI_SOURCE_OK
  end subroutine fmr_read_elastic_storage_cli_source

end module mod_fmr_elastic_storage_cli_source
