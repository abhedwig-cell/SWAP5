module mod_fmr_elastic_storage_resolved_input_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       materialize_fmr_elastic_storage_prior, FMR_ELAS_PRIOR_OK
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK, FMR_ELAS_PRIOR_BIND_INACTIVE
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_INPUT_OK = 0
  integer, parameter, public :: FMR_ELAS_INPUT_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_INPUT_INVALID_SHAPE = 2
  integer, parameter, public :: FMR_ELAS_INPUT_PRIOR_REJECTED = 3
  integer, parameter, public :: FMR_ELAS_INPUT_BINDING_REJECTED = 4

  type, public :: fmr_elastic_storage_input_diagnostics_t
    integer :: status = FMR_ELAS_INPUT_INACTIVE
    integer :: failed_node = 0
    integer :: prior_status = FMR_ELAS_PRIOR_OK
    integer :: binding_status = FMR_ELAS_PRIOR_BIND_INACTIVE
    logical :: request_present = .false.
    logical :: priors_materialized = .false.
    logical :: binding_applied = .false.
  end type fmr_elastic_storage_input_diagnostics_t

  public :: fmr_apply_resolved_elastic_storage_inputs

contains

  subroutine fmr_apply_resolved_elastic_storage_inputs(base_parameters, generated_prior_requested, &
                                                        rho_dry_g_cm3, theta_ref_cm3_cm3, regime, &
                                                        bound_parameters, diagnostics)
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    logical, intent(in) :: generated_prior_requested
    real(real64), intent(in) :: rho_dry_g_cm3(:)
    real(real64), intent(in) :: theta_ref_cm3_cm3(:)
    integer, intent(in) :: regime(:)
    type(fmr_b110_physical_parameters_t), intent(out) :: bound_parameters
    type(fmr_elastic_storage_input_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_prior_t), allocatable :: priors(:)
    type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
    integer :: i, n, prior_status

    bound_parameters = base_parameters
    diagnostics = fmr_elastic_storage_input_diagnostics_t()
    diagnostics%request_present = generated_prior_requested

    if (.not. generated_prior_requested) then
      diagnostics%status = FMR_ELAS_INPUT_INACTIVE
      return
    end if

    n = base_parameters%active_nodes
    if (n <= 0) then
      diagnostics%status = FMR_ELAS_INPUT_INVALID_SHAPE
      return
    end if
    if (size(rho_dry_g_cm3) /= n .or. size(theta_ref_cm3_cm3) /= n .or. size(regime) /= n) then
      diagnostics%status = FMR_ELAS_INPUT_INVALID_SHAPE
      return
    end if

    allocate(priors(n))
    do i = 1, n
      call materialize_fmr_elastic_storage_prior(rho_dry_g_cm3(i), theta_ref_cm3_cm3(i), &
           regime(i), priors(i), prior_status)
      if (prior_status /= FMR_ELAS_PRIOR_OK) then
        diagnostics%status = FMR_ELAS_INPUT_PRIOR_REJECTED
        diagnostics%failed_node = i
        diagnostics%prior_status = prior_status
        return
      end if
    end do
    diagnostics%priors_materialized = .true.

    call fmr_bind_generated_elastic_storage_priors(base_parameters, .true., priors, &
         bound_parameters, bind_diag)
    diagnostics%binding_status = bind_diag%status
    if (bind_diag%status /= FMR_ELAS_PRIOR_BIND_OK) then
      diagnostics%status = FMR_ELAS_INPUT_BINDING_REJECTED
      diagnostics%failed_node = bind_diag%failed_node
      bound_parameters = base_parameters
      return
    end if

    diagnostics%binding_applied = .true.
    diagnostics%status = FMR_ELAS_INPUT_OK
  end subroutine fmr_apply_resolved_elastic_storage_inputs

end module mod_fmr_elastic_storage_resolved_input_adapter
