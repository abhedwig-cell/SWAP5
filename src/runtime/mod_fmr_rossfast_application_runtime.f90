module mod_fmr_rossfast_application_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t, &
       fmr_bind_rossfast_application_config, FMR_ROSSFAST_CONFIG_OK
  use mod_fmr_rossfast_registry_dispatch, only: fmr_rossfast_registry_dispatcher_t, &
       fmr_rossfast_dispatch_result_t, FMR_ROSSFAST_DISPATCH_OK, &
       FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_forcing_t
  use mod_rossfast_d3r_kernel_model_adapter, only: rossfast_d3r_kernel_parameters_t
  implicit none
  private

  integer, parameter, public :: FMR_ROSSFAST_APPLICATION_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED = 1
  integer, parameter, public :: FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED = 2
  integer, parameter, public :: FMR_ROSSFAST_APPLICATION_DISPATCH_REJECTED = 3

  type, public :: fmr_rossfast_application_outcome_t
    integer :: status = FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED
    integer :: config_status = -1
    integer :: dispatch_status = -1
    logical :: asset_registry_bound = .false.
    logical :: dispatch_invoked = .false.
  end type fmr_rossfast_application_outcome_t

  public :: fmr_run_rossfast_application

contains

  subroutine fmr_run_rossfast_application(config, asset_root, application_columns, application_templates, &
                                           parameter_registry, forcing_registry, state_registry, numerical_config, &
                                           t0, t1, results, outcome)
    type(fmr_rossfast_application_config_t), intent(in) :: config
    character(len=*), intent(in) :: asset_root
    type(fmr_rossfast_application_column_t), intent(in) :: application_columns(:)
    type(fmr_template_t), intent(in) :: application_templates(:)
    type(rossfast_d3r_kernel_parameters_t), intent(in) :: parameter_registry(:)
    type(rossfast_d3r_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_rossfast_dispatch_result_t), allocatable, intent(out) :: results(:)
    type(fmr_rossfast_application_outcome_t), intent(out) :: outcome

    type(fmr_logical_column_t), allocatable :: runtime_columns(:)
    type(fmr_template_t), allocatable :: runtime_templates(:)
    type(fmr_rossfast_registry_dispatcher_t) :: dispatcher
    logical :: valid

    outcome = fmr_rossfast_application_outcome_t()
    allocate(results(0))

    ! F-ROSS11 is composition only. F-ROSS09 remains the sole semantic
    ! authority for explicit model configuration and F-ROSS08 remains the sole
    ! application-to-runtime routing materializer.
    call fmr_bind_rossfast_application_config(config, application_columns, application_templates, &
         runtime_columns, runtime_templates, outcome%config_status)
    if (outcome%config_status /= FMR_ROSSFAST_CONFIG_OK) then
      outcome%status = FMR_ROSSFAST_APPLICATION_CONFIG_REJECTED
      return
    end if

    ! Registry binding accepts only a nonempty root. Exact immutable table
    ! availability is deliberately preflighted by F-ROSS07 for the complete
    ! selected batch before its first physical transaction.
    call dispatcher%initialize(asset_root, valid)
    outcome%asset_registry_bound = valid
    if (.not. valid) then
      outcome%status = FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED
      return
    end if

    deallocate(results)
    outcome%dispatch_invoked = .true.
    call dispatcher%execute_batch(runtime_columns, runtime_templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, t0, t1, results, outcome%dispatch_status)

    select case(outcome%dispatch_status)
    case(FMR_ROSSFAST_DISPATCH_OK)
      outcome%status = FMR_ROSSFAST_APPLICATION_OK
    case(FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED)
      outcome%status = FMR_ROSSFAST_APPLICATION_ASSET_PROVIDER_REJECTED
    case default
      outcome%status = FMR_ROSSFAST_APPLICATION_DISPATCH_REJECTED
    end select
  end subroutine fmr_run_rossfast_application

end module mod_fmr_rossfast_application_runtime
