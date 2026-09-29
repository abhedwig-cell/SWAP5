module mod_fmr_elastic_storage_request_source_arbitration
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_REQUEST_SOURCE_NONE = 0
  integer, parameter, public :: FMR_ELAS_REQUEST_SOURCE_EXPLICIT = 1
  integer, parameter, public :: FMR_ELAS_REQUEST_SOURCE_CLI = 2
  integer, parameter, public :: FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT = 3

  integer, parameter, public :: FMR_ELAS_REQUEST_ARBITRATION_OK = 0
  integer, parameter, public :: FMR_ELAS_REQUEST_ARBITRATION_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_REQUEST_ARBITRATION_CONFLICT = 2
  integer, parameter, public :: FMR_ELAS_REQUEST_ARBITRATION_INVALID_SOURCE = 3

  type, public :: fmr_elastic_storage_request_path_candidate_t
    logical :: supplied = .false.
    character(len=512) :: path = ''
  end type fmr_elastic_storage_request_path_candidate_t

  type, public :: fmr_elastic_storage_request_source_selection_t
    integer :: source = FMR_ELAS_REQUEST_SOURCE_NONE
    character(len=512) :: path = ''
    logical :: active = .false.
  end type fmr_elastic_storage_request_source_selection_t

  public :: fmr_resolve_elastic_storage_request_source

contains

  subroutine fmr_resolve_elastic_storage_request_source(explicit_candidate, cli_candidate, environment_candidate, &
                                                         selection, status)
    type(fmr_elastic_storage_request_path_candidate_t), intent(in) :: explicit_candidate
    type(fmr_elastic_storage_request_path_candidate_t), intent(in) :: cli_candidate
    type(fmr_elastic_storage_request_path_candidate_t), intent(in) :: environment_candidate
    type(fmr_elastic_storage_request_source_selection_t), intent(out) :: selection
    integer, intent(out) :: status

    integer :: supplied_count

    selection = fmr_elastic_storage_request_source_selection_t()
    status = FMR_ELAS_REQUEST_ARBITRATION_INACTIVE

    if (.not. candidate_valid(explicit_candidate) .or. .not. candidate_valid(cli_candidate) .or. &
        .not. candidate_valid(environment_candidate)) then
      status = FMR_ELAS_REQUEST_ARBITRATION_INVALID_SOURCE
      return
    end if

    supplied_count = merge(1,0,explicit_candidate%supplied) + merge(1,0,cli_candidate%supplied) + &
                     merge(1,0,environment_candidate%supplied)

    if (supplied_count == 0) return
    if (supplied_count > 1) then
      status = FMR_ELAS_REQUEST_ARBITRATION_CONFLICT
      return
    end if

    if (explicit_candidate%supplied) then
      selection%source = FMR_ELAS_REQUEST_SOURCE_EXPLICIT
      selection%path = explicit_candidate%path
    else if (cli_candidate%supplied) then
      selection%source = FMR_ELAS_REQUEST_SOURCE_CLI
      selection%path = cli_candidate%path
    else
      selection%source = FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT
      selection%path = environment_candidate%path
    end if

    selection%active = .true.
    status = FMR_ELAS_REQUEST_ARBITRATION_OK
  end subroutine fmr_resolve_elastic_storage_request_source

  pure logical function candidate_valid(candidate) result(valid)
    type(fmr_elastic_storage_request_path_candidate_t), intent(in) :: candidate

    valid = .true.
    if (.not. candidate%supplied) return
    if (len_trim(candidate%path) == 0) valid = .false.
  end function candidate_valid

end module mod_fmr_elastic_storage_request_source_arbitration
