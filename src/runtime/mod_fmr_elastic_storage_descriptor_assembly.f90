module mod_fmr_elastic_storage_descriptor_assembly
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       materialize_fmr_elastic_storage_prior, FMR_ELAS_PRIOR_OK
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK, FMR_ELAS_PRIOR_BIND_INACTIVE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_ASSEMBLY_OK = 0
  integer, parameter, public :: FMR_ELAS_ASSEMBLY_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_ASSEMBLY_INVALID_SHAPE = 2
  integer, parameter, public :: FMR_ELAS_ASSEMBLY_PRIOR_REJECTED = 3
  integer, parameter, public :: FMR_ELAS_ASSEMBLY_BIND_REJECTED = 4

  type, public :: fmr_elastic_storage_descriptor_t
    real(real64) :: rho_dry_g_cm3 = 0.0_real64
    real(real64) :: theta_ref_cm3_cm3 = 0.0_real64
    integer :: regime = 0
  end type fmr_elastic_storage_descriptor_t

  type, public :: fmr_elastic_storage_assembly_diagnostics_t
    integer :: status = FMR_ELAS_ASSEMBLY_INACTIVE
    integer :: failed_node = 0
    integer :: prior_status = 0
    integer :: binding_status = FMR_ELAS_PRIOR_BIND_INACTIVE
    logical :: generated_prior_applied = .false.
    logical :: prepared_cache_invalidated = .false.
  end type fmr_elastic_storage_assembly_diagnostics_t

  public :: fmr_assemble_generated_elastic_storage

contains

  subroutine fmr_assemble_generated_elastic_storage(base_parameters, generated_prior_requested, descriptors, &
                                                     bound_parameters, diagnostics)
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    logical, intent(in) :: generated_prior_requested
    type(fmr_elastic_storage_descriptor_t), intent(in) :: descriptors(:)
    type(fmr_b110_physical_parameters_t), intent(out) :: bound_parameters
    type(fmr_elastic_storage_assembly_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_prior_t), allocatable :: priors(:)
    type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
    integer :: i, n, local_prior_status

    bound_parameters = base_parameters
    diagnostics = fmr_elastic_storage_assembly_diagnostics_t()

    if (.not. generated_prior_requested) then
      diagnostics%status = FMR_ELAS_ASSEMBLY_INACTIVE
      return
    end if

    n = base_parameters%active_nodes
    if (n <= 0 .or. size(descriptors) /= n) then
      diagnostics%status = FMR_ELAS_ASSEMBLY_INVALID_SHAPE
      return
    end if

    allocate(priors(n))
    do i = 1, n
      call materialize_fmr_elastic_storage_prior(descriptors(i)%rho_dry_g_cm3, &
           descriptors(i)%theta_ref_cm3_cm3, descriptors(i)%regime, priors(i), local_prior_status)
      if (local_prior_status /= FMR_ELAS_PRIOR_OK .or. .not. priors(i)%available) then
        diagnostics%status = FMR_ELAS_ASSEMBLY_PRIOR_REJECTED
        diagnostics%failed_node = i
        diagnostics%prior_status = local_prior_status
        return
      end if
    end do

    call fmr_bind_generated_elastic_storage_priors(base_parameters, .true., priors, bound_parameters, bind_diag)
    diagnostics%binding_status = bind_diag%status
    diagnostics%prepared_cache_invalidated = bind_diag%prepared_cache_invalidated
    diagnostics%generated_prior_applied = bind_diag%generated_prior_applied

    if (bind_diag%status /= FMR_ELAS_PRIOR_BIND_OK) then
      diagnostics%status = FMR_ELAS_ASSEMBLY_BIND_REJECTED
      diagnostics%failed_node = bind_diag%failed_node
      return
    end if

    diagnostics%status = FMR_ELAS_ASSEMBLY_OK
  end subroutine fmr_assemble_generated_elastic_storage

end module mod_fmr_elastic_storage_descriptor_assembly
