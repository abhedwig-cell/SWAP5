module mod_fmr_elastic_storage_rd_application_host
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_discovery, only: &
       fmr_elastic_storage_request_discovery_diagnostics_t, &
       fmr_discover_elastic_storage_application_request, &
       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, &
       FMR_ELAS_HOST_BINDING_OK
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_RD_HOST_OK = 0
  integer, parameter, public :: FMR_ELAS_RD_HOST_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_RD_HOST_DISCOVERY_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_RD_HOST_PREPROCESS_REJECTED = 3
  integer, parameter, public :: FMR_ELAS_RD_HOST_BINDING_REJECTED = 4

  abstract interface
    subroutine fmr_elastic_storage_rd_preprocess_callback_t(source_path, x_rd_m, y_rd_m, &
                                                             row_output_path, provenance_output_path, status)
      import :: real64
      character(len=*), intent(in) :: source_path
      real(real64), intent(in) :: x_rd_m, y_rd_m
      character(len=*), intent(in) :: row_output_path, provenance_output_path
      integer, intent(out) :: status
    end subroutine fmr_elastic_storage_rd_preprocess_callback_t
  end interface

  type, public :: fmr_elastic_storage_rd_application_host_diagnostics_t
    integer :: status = FMR_ELAS_RD_HOST_INACTIVE
    integer :: discovery_status = FMR_ELAS_DISCOVERY_INACTIVE
    integer :: preprocess_status = 0
    integer :: preprocess_invocations = 0
    integer :: host_binding_status = 0
    logical :: request_ready = .false.
    logical :: generated_prior_requested = .false.
    logical :: generated_prior_applied = .false.
  end type fmr_elastic_storage_rd_application_host_diagnostics_t

  public :: fmr_elastic_storage_rd_preprocess_callback_t
  public :: fmr_prepare_rd_application_with_elastic_storage

contains

  subroutine fmr_prepare_rd_application_with_elastic_storage(explicit_config_path, source_path, x_rd_m, y_rd_m, &
                                                              row_output_path, provenance_output_path, base_parameters, &
                                                              prepared_parameters, preprocess, diagnostics)
    character(len=*), intent(in) :: explicit_config_path
    character(len=*), intent(in) :: source_path
    real(real64), intent(in) :: x_rd_m, y_rd_m
    character(len=*), intent(in) :: row_output_path, provenance_output_path
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    type(fmr_b110_physical_parameters_t), intent(out) :: prepared_parameters
    procedure(fmr_elastic_storage_rd_preprocess_callback_t) :: preprocess
    type(fmr_elastic_storage_rd_application_host_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_application_request_t) :: request
    type(fmr_elastic_storage_request_discovery_diagnostics_t) :: discovery
    type(fmr_elastic_storage_application_host_diagnostics_t) :: host_binding

    prepared_parameters = base_parameters
    diagnostics = fmr_elastic_storage_rd_application_host_diagnostics_t()

    call fmr_discover_elastic_storage_application_request(explicit_config_path, request, discovery)
    diagnostics%discovery_status = discovery%status
    diagnostics%request_ready = discovery%request_ready
    diagnostics%generated_prior_requested = request%generated_prior_requested

    if (discovery%status == FMR_ELAS_DISCOVERY_INACTIVE) then
      diagnostics%status = FMR_ELAS_RD_HOST_INACTIVE
      return
    end if

    if (discovery%status /= FMR_ELAS_DISCOVERY_OK .or. .not. discovery%request_ready .or. &
        .not. request%generated_prior_requested) then
      diagnostics%status = FMR_ELAS_RD_HOST_DISCOVERY_REJECTED
      return
    end if

    diagnostics%preprocess_invocations = 1
    call preprocess(source_path, x_rd_m, y_rd_m, row_output_path, provenance_output_path, diagnostics%preprocess_status)
    if (diagnostics%preprocess_status /= 0) then
      prepared_parameters = base_parameters
      diagnostics%status = FMR_ELAS_RD_HOST_PREPROCESS_REJECTED
      return
    end if

    call fmr_prepare_application_parameters_with_elastic_storage(explicit_config_path, row_output_path, &
         base_parameters, prepared_parameters, host_binding)
    diagnostics%host_binding_status = host_binding%status
    diagnostics%generated_prior_applied = host_binding%generated_prior_applied

    if (host_binding%status /= FMR_ELAS_HOST_BINDING_OK) then
      prepared_parameters = base_parameters
      diagnostics%status = FMR_ELAS_RD_HOST_BINDING_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_RD_HOST_OK
  end subroutine fmr_prepare_rd_application_with_elastic_storage

end module mod_fmr_elastic_storage_rd_application_host
