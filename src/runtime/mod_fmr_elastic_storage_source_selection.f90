module mod_fmr_elastic_storage_source_selection
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       FMR_ELAS_REGIME_MINERAL
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_SELECT_OK = 0
  integer, parameter, public :: FMR_ELAS_SELECT_INVALID_USER_VALUE = 1
  integer, parameter, public :: FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE = 2

  integer, parameter, public :: FMR_ELAS_SOURCE_OFF = 0
  integer, parameter, public :: FMR_ELAS_SOURCE_USER_EXPLICIT = 1
  integer, parameter, public :: FMR_ELAS_SOURCE_GENERATED_MINERAL = 2

  type, public :: fmr_elastic_storage_selection_t
    logical :: activate = .false.
    real(real64) :: value_cm_inv = 0.0_real64
    integer :: source = FMR_ELAS_SOURCE_OFF
    logical :: uncertainty_available = .false.
    real(real64) :: lower_cm_inv = 0.0_real64
    real(real64) :: upper_cm_inv = 0.0_real64
    real(real64) :: reference_head_cm = 0.0_real64
    integer :: generated_domain_class = 0
  end type fmr_elastic_storage_selection_t

  public :: select_fmr_elastic_storage_source

contains

  subroutine select_fmr_elastic_storage_source(user_supplied, user_value_cm_inv, generated_requested, generated_prior, selection, status)
    logical, intent(in) :: user_supplied
    real(real64), intent(in) :: user_value_cm_inv
    logical, intent(in) :: generated_requested
    type(fmr_elastic_storage_prior_t), intent(in) :: generated_prior
    type(fmr_elastic_storage_selection_t), intent(out) :: selection
    integer, intent(out) :: status

    selection = fmr_elastic_storage_selection_t()
    status = FMR_ELAS_SELECT_OK

    if (user_supplied) then
      if (.not. ieee_is_finite(user_value_cm_inv) .or. user_value_cm_inv < 0.0_real64) then
        status = FMR_ELAS_SELECT_INVALID_USER_VALUE
        return
      end if
      selection%activate = .true.
      selection%value_cm_inv = user_value_cm_inv
      selection%source = FMR_ELAS_SOURCE_USER_EXPLICIT
      return
    end if

    if (.not. generated_requested) return

    if (.not. valid_generated_prior(generated_prior)) then
      status = FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE
      return
    end if

    selection%activate = .true.
    selection%value_cm_inv = generated_prior%value_cm_inv
    selection%source = FMR_ELAS_SOURCE_GENERATED_MINERAL
    selection%uncertainty_available = .true.
    selection%lower_cm_inv = generated_prior%lower_cm_inv
    selection%upper_cm_inv = generated_prior%upper_cm_inv
    selection%reference_head_cm = generated_prior%reference_head_cm
    selection%generated_domain_class = generated_prior%domain_class
  end subroutine select_fmr_elastic_storage_source

  pure logical function valid_generated_prior(prior) result(valid)
    type(fmr_elastic_storage_prior_t), intent(in) :: prior

    valid = prior%available
    if (.not. valid) return
    valid = prior%regime == FMR_ELAS_REGIME_MINERAL
    if (.not. valid) return
    valid = ieee_is_finite(prior%value_cm_inv) .and. prior%value_cm_inv > 0.0_real64
    if (.not. valid) return
    valid = ieee_is_finite(prior%lower_cm_inv) .and. ieee_is_finite(prior%upper_cm_inv)
    if (.not. valid) return
    valid = prior%lower_cm_inv > 0.0_real64 .and. prior%lower_cm_inv < prior%value_cm_inv .and. &
         prior%upper_cm_inv > prior%value_cm_inv
    if (.not. valid) return
    valid = ieee_is_finite(prior%reference_head_cm)
  end function valid_generated_prior

end module mod_fmr_elastic_storage_source_selection
