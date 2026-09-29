module mod_fmr_elastic_storage_application_host
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_discovery, only: &
       fmr_elastic_storage_request_discovery_diagnostics_t, &
       fmr_discover_elastic_storage_application_request, &
       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE
  use mod_fmr_elastic_storage_row_application_binding, only: &
       fmr_elastic_storage_row_application_diagnostics_t, &
       fmr_bind_elastic_storage_from_row_interchange, &
       FMR_ELAS_ROW_APP_OK
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_HOST_OK = 0
  integer, parameter, public :: FMR_ELAS_HOST_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_HOST_DISCOVERY_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_HOST_ROW_PATH_REQUIRED = 3
  integer, parameter, public :: FMR_ELAS_HOST_BINDING_REJECTED = 4

  type, public :: fmr_elastic_storage_application_host_diagnostics_t
    integer :: status = FMR_ELAS_HOST_INACTIVE
    integer :: discovery_status = FMR_ELAS_DISCOVERY_INACTIVE
    integer :: binding_status = 0
    logical :: request_ready = .false.
    logical :: generated_prior_requested = .false.
    logical :: generated_prior_applied = .false.
  end type fmr_elastic_storage_application_host_diagnostics_t

  public :: fmr_compose_elastic_storage_application

contains

  subroutine fmr_compose_elastic_storage_application(explicit_request_path, row_interchange_path, &
                                                       base_parameters, bound_parameters, diagnostics)
    character(len=*), intent(in) :: explicit_request_path
    character(len=*), intent(in) :: row_interchange_path
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    type(fmr_b110_physical_parameters_t), intent(out) :: bound_parameters
    type(fmr_elastic_storage_application_host_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_application_request_t) :: request
    type(fmr_elastic_storage_request_discovery_diagnostics_t) :: discovery
    type(fmr_elastic_storage_row_application_diagnostics_t) :: binding

    bound_parameters = base_parameters
    diagnostics = fmr_elastic_storage_application_host_diagnostics_t()

    call fmr_discover_elastic_storage_application_request(explicit_request_path, request, discovery)
    diagnostics%discovery_status = discovery%status
    diagnostics%request_ready = discovery%request_ready
    diagnostics%generated_prior_requested = request%generated_prior_requested

    if (discovery%status == FMR_ELAS_DISCOVERY_INACTIVE) then
      diagnostics%status = FMR_ELAS_HOST_INACTIVE
      return
    end if

    if (discovery%status /= FMR_ELAS_DISCOVERY_OK .or. .not. discovery%request_ready) then
      diagnostics%status = FMR_ELAS_HOST_DISCOVERY_REJECTED
      return
    end if

    if (.not. request%generated_prior_requested) then
      diagnostics%status = FMR_ELAS_HOST_INACTIVE
      return
    end if

    if (len_trim(row_interchange_path) == 0) then
      diagnostics%status = FMR_ELAS_HOST_ROW_PATH_REQUIRED
      return
    end if

    call fmr_bind_elastic_storage_from_row_interchange(row_interchange_path, &
         request%generated_prior_requested, base_parameters, bound_parameters, binding)

    diagnostics%binding_status = binding%status
    diagnostics%generated_prior_applied = binding%generated_prior_applied

    if (binding%status /= FMR_ELAS_ROW_APP_OK) then
      bound_parameters = base_parameters
      diagnostics%status = FMR_ELAS_HOST_BINDING_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_HOST_OK
  end subroutine fmr_compose_elastic_storage_application

end module mod_fmr_elastic_storage_application_host
