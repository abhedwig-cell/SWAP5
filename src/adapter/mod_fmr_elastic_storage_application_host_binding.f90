module mod_fmr_elastic_storage_application_host_binding
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_discovery, only: &
       fmr_elastic_storage_request_discovery_diagnostics_t, &
       fmr_discover_elastic_storage_application_request, &
       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE
  use mod_fmr_elastic_storage_row_application_binding, only: &
       fmr_elastic_storage_row_application_diagnostics_t, &
       fmr_bind_elastic_storage_from_row_interchange, &
       FMR_ELAS_ROW_APP_OK, FMR_ELAS_ROW_APP_INACTIVE
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_HOST_BINDING_OK = 0
  integer, parameter, public :: FMR_ELAS_HOST_BINDING_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_HOST_BINDING_DISCOVERY_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_HOST_BINDING_ROW_BINDING_REJECTED = 3

  type, public :: fmr_elastic_storage_application_host_diagnostics_t
    integer :: status = FMR_ELAS_HOST_BINDING_INACTIVE
    integer :: discovery_status = FMR_ELAS_DISCOVERY_INACTIVE
    integer :: row_binding_status = FMR_ELAS_ROW_APP_INACTIVE
    integer :: selected_profile_id = 0
    logical :: request_ready = .false.
    logical :: generated_prior_requested = .false.
    logical :: generated_prior_applied = .false.
  end type fmr_elastic_storage_application_host_diagnostics_t

  public :: fmr_prepare_application_parameters_with_elastic_storage

contains

  subroutine fmr_prepare_application_parameters_with_elastic_storage(explicit_config_path, row_interchange_path, &
                                                                      base_parameters, prepared_parameters, diagnostics)
    character(len=*), intent(in) :: explicit_config_path
    character(len=*), intent(in) :: row_interchange_path
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    type(fmr_b110_physical_parameters_t), intent(out) :: prepared_parameters
    type(fmr_elastic_storage_application_host_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_application_request_t) :: request
    type(fmr_elastic_storage_request_discovery_diagnostics_t) :: discovery
    type(fmr_elastic_storage_row_application_diagnostics_t) :: row_binding

    prepared_parameters = base_parameters
    diagnostics = fmr_elastic_storage_application_host_diagnostics_t()

    call fmr_discover_elastic_storage_application_request(explicit_config_path, request, discovery)
    diagnostics%discovery_status = discovery%status
    diagnostics%request_ready = discovery%request_ready

    if (discovery%status == FMR_ELAS_DISCOVERY_INACTIVE) then
      diagnostics%status = FMR_ELAS_HOST_BINDING_INACTIVE
      return
    end if

    if (discovery%status /= FMR_ELAS_DISCOVERY_OK) then
      diagnostics%status = FMR_ELAS_HOST_BINDING_DISCOVERY_REJECTED
      return
    end if

    diagnostics%generated_prior_requested = request%generated_prior_requested

    call fmr_bind_elastic_storage_from_row_interchange(row_interchange_path, request%generated_prior_requested, &
                                                        base_parameters, prepared_parameters, row_binding)
    diagnostics%row_binding_status = row_binding%status
    diagnostics%selected_profile_id = row_binding%selected_profile_id
    diagnostics%generated_prior_applied = row_binding%generated_prior_applied

    if (row_binding%status == FMR_ELAS_ROW_APP_INACTIVE) then
      diagnostics%status = FMR_ELAS_HOST_BINDING_INACTIVE
      return
    end if

    if (row_binding%status /= FMR_ELAS_ROW_APP_OK) then
      prepared_parameters = base_parameters
      diagnostics%status = FMR_ELAS_HOST_BINDING_ROW_BINDING_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_HOST_BINDING_OK
  end subroutine fmr_prepare_application_parameters_with_elastic_storage

end module mod_fmr_elastic_storage_application_host_binding
