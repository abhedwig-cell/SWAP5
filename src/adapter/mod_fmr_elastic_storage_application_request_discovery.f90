module mod_fmr_elastic_storage_application_request_discovery
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t, fmr_elastic_storage_request_source_selection_t, &
       fmr_resolve_elastic_storage_request_source, &
       FMR_ELAS_REQUEST_ARBITRATION_OK, FMR_ELAS_REQUEST_ARBITRATION_INACTIVE, &
       FMR_ELAS_REQUEST_ARBITRATION_CONFLICT
  use mod_fmr_elastic_storage_environment_source, only: &
       fmr_read_elastic_storage_environment_source, FMR_ELAS_ENV_SOURCE_OK, FMR_ELAS_ENV_SOURCE_INACTIVE
  use mod_fmr_elastic_storage_cli_source, only: &
       fmr_read_elastic_storage_cli_source, FMR_ELAS_CLI_SOURCE_OK, FMR_ELAS_CLI_SOURCE_INACTIVE
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_loader, only: &
       fmr_elastic_storage_request_loader_diagnostics_t, fmr_load_elastic_storage_application_request, &
       FMR_ELAS_REQUEST_LOADER_OK
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_DISCOVERY_OK = 0
  integer, parameter, public :: FMR_ELAS_DISCOVERY_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_DISCOVERY_SOURCE_CONFLICT = 3
  integer, parameter, public :: FMR_ELAS_DISCOVERY_REQUEST_REJECTED = 4
  integer, parameter, public :: FMR_ELAS_DISCOVERY_INVALID_EXPLICIT_SOURCE = 5

  type, public :: fmr_elastic_storage_request_discovery_diagnostics_t
    integer :: status = FMR_ELAS_DISCOVERY_INACTIVE
    integer :: cli_status = FMR_ELAS_CLI_SOURCE_INACTIVE
    integer :: environment_status = FMR_ELAS_ENV_SOURCE_INACTIVE
    integer :: arbitration_status = FMR_ELAS_REQUEST_ARBITRATION_INACTIVE
    integer :: selected_source = 0
    integer :: loader_status = 0
    logical :: request_ready = .false.
  end type fmr_elastic_storage_request_discovery_diagnostics_t

  public :: fmr_discover_elastic_storage_application_request

contains

  subroutine fmr_discover_elastic_storage_application_request(explicit_path, request, diagnostics)
    character(len=*), intent(in) :: explicit_path
    type(fmr_elastic_storage_application_request_t), intent(out) :: request
    type(fmr_elastic_storage_request_discovery_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_request_path_candidate_t) :: explicit_candidate, cli_candidate, environment_candidate
    type(fmr_elastic_storage_request_source_selection_t) :: selection
    type(fmr_elastic_storage_request_loader_diagnostics_t) :: loader_diagnostics
    integer :: arbitration_status

    request = fmr_elastic_storage_application_request_t()
    diagnostics = fmr_elastic_storage_request_discovery_diagnostics_t()
    explicit_candidate = fmr_elastic_storage_request_path_candidate_t()

    if (len_trim(explicit_path) > 0) then
      if (len_trim(explicit_path) > len(explicit_candidate%path)) then
        diagnostics%status = FMR_ELAS_DISCOVERY_INVALID_EXPLICIT_SOURCE
        return
      end if
      explicit_candidate%supplied = .true.
      explicit_candidate%path = explicit_path
    end if

    call fmr_read_elastic_storage_cli_source(cli_candidate, diagnostics%cli_status)
    if (diagnostics%cli_status /= FMR_ELAS_CLI_SOURCE_OK .and. &
        diagnostics%cli_status /= FMR_ELAS_CLI_SOURCE_INACTIVE) then
      diagnostics%status = FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED
      return
    end if

    call fmr_read_elastic_storage_environment_source(environment_candidate, diagnostics%environment_status)
    if (diagnostics%environment_status /= FMR_ELAS_ENV_SOURCE_OK .and. &
        diagnostics%environment_status /= FMR_ELAS_ENV_SOURCE_INACTIVE) then
      diagnostics%status = FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED
      return
    end if

    call fmr_resolve_elastic_storage_request_source(explicit_candidate, cli_candidate, environment_candidate, &
                                                     selection, arbitration_status)
    diagnostics%arbitration_status = arbitration_status
    diagnostics%selected_source = selection%source

    if (arbitration_status == FMR_ELAS_REQUEST_ARBITRATION_INACTIVE) return
    if (arbitration_status == FMR_ELAS_REQUEST_ARBITRATION_CONFLICT) then
      diagnostics%status = FMR_ELAS_DISCOVERY_SOURCE_CONFLICT
      return
    end if
    if (arbitration_status /= FMR_ELAS_REQUEST_ARBITRATION_OK) then
      diagnostics%status = FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED
      return
    end if

    call fmr_load_elastic_storage_application_request(selection%path, request, loader_diagnostics)
    diagnostics%loader_status = loader_diagnostics%status
    if (loader_diagnostics%status /= FMR_ELAS_REQUEST_LOADER_OK) then
      request = fmr_elastic_storage_application_request_t()
      diagnostics%status = FMR_ELAS_DISCOVERY_REQUEST_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_DISCOVERY_OK
    diagnostics%request_ready = .true.
  end subroutine fmr_discover_elastic_storage_application_request

end module mod_fmr_elastic_storage_application_request_discovery
