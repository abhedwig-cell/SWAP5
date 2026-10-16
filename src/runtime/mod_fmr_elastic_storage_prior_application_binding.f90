module mod_fmr_elastic_storage_prior_application_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_DOMAIN_IN, FMR_ELAS_DOMAIN_EDGE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_PRIOR_BIND_OK = 0
  integer, parameter, public :: FMR_ELAS_PRIOR_BIND_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT = 2
  integer, parameter, public :: FMR_ELAS_PRIOR_BIND_INVALID_SHAPE = 3
  integer, parameter, public :: FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED = 4

  type, public :: fmr_elastic_storage_prior_binding_diagnostics_t
    integer :: status = FMR_ELAS_PRIOR_BIND_INACTIVE
    integer :: failed_node = 0
    logical :: request_present = .false.
    logical :: explicit_elas_conflict = .false.
    logical :: generated_prior_applied = .false.
    logical :: prepared_cache_invalidated = .false.
  end type fmr_elastic_storage_prior_binding_diagnostics_t

  public :: fmr_bind_generated_elastic_storage_priors

contains

  subroutine fmr_bind_generated_elastic_storage_priors(base_parameters, generated_prior_requested, priors, &
                                                        bound_parameters, diagnostics)
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    logical, intent(in) :: generated_prior_requested
    type(fmr_elastic_storage_prior_t), intent(in) :: priors(:)
    type(fmr_b110_physical_parameters_t), intent(out) :: bound_parameters
    type(fmr_elastic_storage_prior_binding_diagnostics_t), intent(out) :: diagnostics

    integer :: i, n

    bound_parameters = base_parameters
    diagnostics = fmr_elastic_storage_prior_binding_diagnostics_t()
    diagnostics%request_present = generated_prior_requested

    if (.not. generated_prior_requested) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_INACTIVE
      return
    end if

    n = base_parameters%active_nodes
    if (n <= 0) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_INVALID_SHAPE
      return
    end if
    if (size(priors) /= n) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_INVALID_SHAPE
      return
    end if
    if (.not. allocated(base_parameters%cofgen)) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_INVALID_SHAPE
      return
    end if
    if (size(base_parameters%cofgen,1) < 24 .or. size(base_parameters%cofgen,2) < n) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_INVALID_SHAPE
      return
    end if

    if (base_parameters%elasticity_active) then
      diagnostics%status = FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
      diagnostics%explicit_elas_conflict = .true.
      return
    end if

    do i = 1, n
      if (.not. ieee_is_finite(base_parameters%cofgen(24,i))) then
        diagnostics%status = FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
        diagnostics%explicit_elas_conflict = .true.
        diagnostics%failed_node = i
        return
      end if
      if (base_parameters%cofgen(24,i) /= 0.0_real64) then
        diagnostics%status = FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
        diagnostics%explicit_elas_conflict = .true.
        diagnostics%failed_node = i
        return
      end if
    end do

    do i = 1, n
      if (.not. prior_eligible(priors(i))) then
        diagnostics%status = FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED
        diagnostics%failed_node = i
        return
      end if
    end do

    do i = 1, n
      bound_parameters%cofgen(24,i) = priors(i)%value_cm_inv
    end do
    bound_parameters%elasticity_active = .true.
    if (bound_parameters%prepared_default_mvg_available) then
      bound_parameters%prepared_default_mvg_available = .false.
      diagnostics%prepared_cache_invalidated = .true.
    end if

    diagnostics%status = FMR_ELAS_PRIOR_BIND_OK
    diagnostics%generated_prior_applied = .true.
  end subroutine fmr_bind_generated_elastic_storage_priors

  pure logical function prior_eligible(prior) result(eligible)
    type(fmr_elastic_storage_prior_t), intent(in) :: prior

    eligible = .false.
    if (.not. prior%available) return
    if (prior%regime /= FMR_ELAS_REGIME_MINERAL) return
    if (prior%domain_class /= FMR_ELAS_DOMAIN_IN .and. prior%domain_class /= FMR_ELAS_DOMAIN_EDGE) return
    if (.not. ieee_is_finite(prior%value_cm_inv)) return
    if (prior%value_cm_inv <= 0.0_real64) return
    eligible = .true.
  end function prior_eligible

end module mod_fmr_elastic_storage_prior_application_binding
