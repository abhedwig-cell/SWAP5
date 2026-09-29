program test_fpe_elastic14_prior
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &
       FMR_ELAS_PRIOR_OK, FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED, FMR_ELAS_PRIOR_INVALID_INPUT, FMR_ELAS_PRIOR_OUT_OF_DOMAIN, &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN, &
       FMR_ELAS_DOMAIN_IN, FMR_ELAS_DOMAIN_EDGE, FMR_ELAS_REFERENCE_HEAD_CM, FMR_ELAS_UNCERTAINTY_FACTOR
  implicit none

  type(fmr_elastic_storage_prior_t) :: prior
  integer :: status
  real(real64) :: nanv

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  call materialize_fmr_elastic_storage_prior(1.454_real64, 0.36_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_OK .and. prior%available, 'A1 mineral available')
  call require(prior%domain_class == FMR_ELAS_DOMAIN_IN, 'A1 mineral in domain')
  call require(prior%reference_head_cm == FMR_ELAS_REFERENCE_HEAD_CM, 'A1 reference head')
  call require(prior%value_cm_inv > 0.0_real64, 'A1 positive')
  call require(prior%lower_cm_inv < prior%value_cm_inv .and. prior%upper_cm_inv > prior%value_cm_inv, 'A2 uncertainty order')
  call require(abs(prior%upper_cm_inv / prior%value_cm_inv - FMR_ELAS_UNCERTAINTY_FACTOR) < 1.0e-14_real64, 'A2 upper factor')
  call require(abs(prior%value_cm_inv / prior%lower_cm_inv - FMR_ELAS_UNCERTAINTY_FACTOR) < 1.0e-14_real64, 'A2 lower factor')
  write(*,'(A,ES24.16E3)') 'F_PE_ELASTIC14_REFERENCE_PRIOR=', prior%value_cm_inv
  write(*,'(A)') 'F_PE_ELASTIC14_A1_FORMULA=PASS'
  write(*,'(A)') 'F_PE_ELASTIC14_A2_UNCERTAINTY=PASS'

  call materialize_fmr_elastic_storage_prior(0.65_real64, 0.55_real64, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, prior, status)
  call require(status == FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED .and. .not. prior%available, 'A3 organic')
  call materialize_fmr_elastic_storage_prior(0.25_real64, 0.75_real64, FMR_ELAS_REGIME_PEAT, prior, status)
  call require(status == FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED .and. .not. prior%available, 'A3 peat')
  call materialize_fmr_elastic_storage_prior(1.4_real64, 0.35_real64, FMR_ELAS_REGIME_UNKNOWN, prior, status)
  call require(status == FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED .and. .not. prior%available, 'A3 unknown')
  write(*,'(A)') 'F_PE_ELASTIC14_A3_NONMINERAL=PASS'

  call materialize_fmr_elastic_storage_prior(-1.0_real64, 0.2_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_INVALID_INPUT .and. .not. prior%available, 'A4 negative density')
  call materialize_fmr_elastic_storage_prior(1.4_real64, -0.1_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_INVALID_INPUT .and. .not. prior%available, 'A4 negative theta')
  call materialize_fmr_elastic_storage_prior(1.4_real64, 1.1_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_INVALID_INPUT .and. .not. prior%available, 'A4 theta high')
  call materialize_fmr_elastic_storage_prior(nanv, 0.2_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_INVALID_INPUT .and. .not. prior%available, 'A4 nan density')
  call materialize_fmr_elastic_storage_prior(10.0_real64, 0.1_real64, FMR_ELAS_REGIME_MINERAL, prior, status)
  call require(status == FMR_ELAS_PRIOR_OUT_OF_DOMAIN .and. .not. prior%available, 'A4 out of domain')
  write(*,'(A)') 'F_PE_ELASTIC14_A4_FAIL_CLOSED=PASS'

  write(*,'(A)') 'F_PE_ELASTIC14_PRIOR_ORACLE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC14_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic14_prior
