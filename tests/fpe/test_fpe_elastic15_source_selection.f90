program test_fpe_elastic15_source_selection
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &
       FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_PEAT
  use mod_fmr_elastic_storage_source_selection, only: fmr_elastic_storage_selection_t, select_fmr_elastic_storage_source, &
       FMR_ELAS_SELECT_OK, FMR_ELAS_SELECT_INVALID_USER_VALUE, FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE, &
       FMR_ELAS_SOURCE_OFF, FMR_ELAS_SOURCE_USER_EXPLICIT, FMR_ELAS_SOURCE_GENERATED_MINERAL
  implicit none

  type(fmr_elastic_storage_prior_t) :: prior, bad_prior
  type(fmr_elastic_storage_selection_t) :: selection
  integer :: status, prior_status
  real(real64) :: nanv, user_value

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  call materialize_fmr_elastic_storage_prior(1.454_real64, 0.36_real64, FMR_ELAS_REGIME_MINERAL, prior, prior_status)
  call require(prior_status == FMR_ELAS_PRIOR_OK .and. prior%available, 'fixture prior')

  ! A1: default OFF.
  call select_fmr_elastic_storage_source(.false., 0.0_real64, .false., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_OK, 'A1 status')
  call require(.not. selection%activate .and. selection%source == FMR_ELAS_SOURCE_OFF, 'A1 off')
  call require(selection%value_cm_inv == 0.0_real64 .and. .not. selection%uncertainty_available, 'A1 clean')
  write(*,'(A)') 'F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS'

  ! A2: explicit user source exact identity.
  user_value = 1.25e-6_real64
  call select_fmr_elastic_storage_source(.true., user_value, .false., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_OK .and. selection%activate, 'A2 active')
  call require(selection%source == FMR_ELAS_SOURCE_USER_EXPLICIT, 'A2 source')
  call require(selection%value_cm_inv == user_value, 'A2 identity')
  call require(.not. selection%uncertainty_available, 'A2 no fabricated uncertainty')
  write(*,'(A)') 'F_PE_ELASTIC15_A2_USER=PASS'

  ! A3: explicit user wins over generated request.
  call select_fmr_elastic_storage_source(.true., user_value, .true., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_OK .and. selection%activate, 'A3 active')
  call require(selection%source == FMR_ELAS_SOURCE_USER_EXPLICIT, 'A3 source')
  call require(selection%value_cm_inv == user_value, 'A3 identity')
  write(*,'(A)') 'F_PE_ELASTIC15_A3_USER_OVERRIDE=PASS'

  ! A4: invalid user never falls back to valid generated prior.
  call select_fmr_elastic_storage_source(.true., nanv, .true., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_INVALID_USER_VALUE, 'A4 status')
  call require(.not. selection%activate .and. selection%source == FMR_ELAS_SOURCE_OFF, 'A4 no fallback')
  call select_fmr_elastic_storage_source(.true., -1.0e-6_real64, .true., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_INVALID_USER_VALUE .and. .not. selection%activate, 'A4 negative')
  write(*,'(A)') 'F_PE_ELASTIC15_A4_INVALID_USER_NO_FALLBACK=PASS'

  ! A5: generated-only exact metadata identity.
  call select_fmr_elastic_storage_source(.false., 0.0_real64, .true., prior, selection, status)
  call require(status == FMR_ELAS_SELECT_OK .and. selection%activate, 'A5 active')
  call require(selection%source == FMR_ELAS_SOURCE_GENERATED_MINERAL, 'A5 source')
  call require(selection%value_cm_inv == prior%value_cm_inv, 'A5 value')
  call require(selection%uncertainty_available, 'A5 uncertainty')
  call require(selection%lower_cm_inv == prior%lower_cm_inv .and. selection%upper_cm_inv == prior%upper_cm_inv, 'A5 bounds')
  call require(selection%reference_head_cm == prior%reference_head_cm, 'A5 head')
  call require(selection%generated_domain_class == prior%domain_class, 'A5 domain')
  write(*,'(A,ES24.16E3)') 'F_PE_ELASTIC15_GENERATED_VALUE=', selection%value_cm_inv
  write(*,'(A)') 'F_PE_ELASTIC15_A5_GENERATED=PASS'

  ! A6: unavailable / non-mineral / corrupt generated prior fail closed.
  bad_prior = fmr_elastic_storage_prior_t()
  call select_fmr_elastic_storage_source(.false., 0.0_real64, .true., bad_prior, selection, status)
  call require(status == FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE .and. .not. selection%activate, 'A6 unavailable')

  bad_prior = prior
  bad_prior%regime = FMR_ELAS_REGIME_PEAT
  call select_fmr_elastic_storage_source(.false., 0.0_real64, .true., bad_prior, selection, status)
  call require(status == FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE .and. .not. selection%activate, 'A6 peat')

  bad_prior = prior
  bad_prior%lower_cm_inv = bad_prior%value_cm_inv
  call select_fmr_elastic_storage_source(.false., 0.0_real64, .true., bad_prior, selection, status)
  call require(status == FMR_ELAS_SELECT_GENERATED_NOT_AVAILABLE .and. .not. selection%activate, 'A6 bounds')

  write(*,'(A)') 'F_PE_ELASTIC15_A6_GENERATED_FAIL_CLOSED=PASS'
  write(*,'(A)') 'F_PE_ELASTIC15_POLICY_ORACLE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC15_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic15_source_selection
