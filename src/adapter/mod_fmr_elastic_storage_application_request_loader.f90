module mod_fmr_elastic_storage_application_request_loader
  use mod_fmr_elastic_storage_application_config, only: &
       fmr_elastic_storage_application_config_t, fmr_elastic_storage_application_request_t, &
       fmr_bind_elastic_storage_application_config, FMR_ELAS_CONFIG_OK
  use mod_fmr_elastic_storage_application_config_file_adapter, only: &
       fmr_read_elastic_storage_application_config_file, FMR_ELAS_CONFIG_FILE_OK
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_REQUEST_LOADER_OK = 0
  integer, parameter, public :: FMR_ELAS_REQUEST_LOADER_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_REQUEST_LOADER_FILE_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_REQUEST_LOADER_CONFIG_REJECTED = 3

  type, public :: fmr_elastic_storage_request_loader_diagnostics_t
    integer :: status = FMR_ELAS_REQUEST_LOADER_INACTIVE
    integer :: file_status = 0
    integer :: config_status = 0
    logical :: path_supplied = .false.
    logical :: request_ready = .false.
  end type fmr_elastic_storage_request_loader_diagnostics_t

  public :: fmr_load_elastic_storage_application_request

contains

  subroutine fmr_load_elastic_storage_application_request(path, request, diagnostics)
    character(len=*), intent(in) :: path
    type(fmr_elastic_storage_application_request_t), intent(out) :: request
    type(fmr_elastic_storage_request_loader_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_application_config_t) :: config
    integer :: file_status, config_status

    request = fmr_elastic_storage_application_request_t()
    diagnostics = fmr_elastic_storage_request_loader_diagnostics_t()

    if (len_trim(path) == 0) return
    diagnostics%path_supplied = .true.

    call fmr_read_elastic_storage_application_config_file(path, config, file_status)
    diagnostics%file_status = file_status
    if (file_status /= FMR_ELAS_CONFIG_FILE_OK) then
      diagnostics%status = FMR_ELAS_REQUEST_LOADER_FILE_REJECTED
      return
    end if

    call fmr_bind_elastic_storage_application_config(config, request, config_status)
    diagnostics%config_status = config_status
    if (config_status /= FMR_ELAS_CONFIG_OK) then
      request = fmr_elastic_storage_application_request_t()
      diagnostics%status = FMR_ELAS_REQUEST_LOADER_CONFIG_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_REQUEST_LOADER_OK
    diagnostics%request_ready = .true.
  end subroutine fmr_load_elastic_storage_application_request

end module mod_fmr_elastic_storage_application_request_loader
