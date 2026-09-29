program test_fpe_elastic25_application_request
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_application_config, only: &
       fmr_elastic_storage_application_config_t, fmr_elastic_storage_application_request_t, &
       fmr_bind_elastic_storage_application_config, FMR_ELAS_CONFIG_OK, FMR_ELAS_CONFIG_MISSING, &
       FMR_ELAS_CONFIG_UNSUPPORTED_KEY, FMR_ELAS_CONFIG_UNSUPPORTED_VALUE, &
       FMR_ELAS_CONFIG_KEY_SOURCE, FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO
  use mod_fmr_elastic_storage_prior_policy, only: &
       fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &
       FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, &
       fmr_bind_generated_elastic_storage_priors, FMR_ELAS_PRIOR_BIND_OK, &
       FMR_ELAS_PRIOR_BIND_INACTIVE, FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  implicit none

  type(fmr_elastic_storage_application_config_t) :: config
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_prior_t) :: priors(2)
  type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
  type(fmr_b110_physical_parameters_t) :: base, bound
  integer :: status, i, prior_status

  config = fmr_elastic_storage_application_config_t()
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_MISSING .and. .not. request%generated_prior_requested, 'A1 missing')
  write(*,'(A)') 'F_PE_ELASTIC25_A1_DEFAULT_OFF=PASS'

  config%supplied = .true.
  config%key = FMR_ELAS_CONFIG_KEY_SOURCE
  config%value = FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_OK .and. request%generated_prior_requested, 'A2 exact')
  write(*,'(A)') 'F_PE_ELASTIC25_A2_EXPLICIT_REQUEST=PASS'

  config%key = 'OTHER_KEY'
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_UNSUPPORTED_KEY .and. .not. request%generated_prior_requested, 'A3 key')
  write(*,'(A)') 'F_PE_ELASTIC25_A3_KEY_FAIL_CLOSED=PASS'

  config%key = FMR_ELAS_CONFIG_KEY_SOURCE
  config%value = 'OTHER_VALUE'
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_UNSUPPORTED_VALUE .and. .not. request%generated_prior_requested, 'A4 value')
  write(*,'(A)') 'F_PE_ELASTIC25_A4_VALUE_FAIL_CLOSED=PASS'

  config%value = 'generated_bofek_bro_prior'
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_UNSUPPORTED_VALUE .and. .not. request%generated_prior_requested, 'A5 case')
  config%value = ' GENERATED_BOFEK_BRO_PRIOR'
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_UNSUPPORTED_VALUE .and. .not. request%generated_prior_requested, 'A5 leading')
  config%value = FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call req(status == FMR_ELAS_CONFIG_OK .and. request%generated_prior_requested, 'A5 padding')
  write(*,'(A)') 'F_PE_ELASTIC25_A5_EXACT_TOKEN_SEMANTICS=PASS'

  call init_base(base)
  do i = 1, 2
    call materialize_fmr_elastic_storage_prior(1.40_real64 + 0.01_real64*real(i,real64), 0.36_real64, &
         FMR_ELAS_REGIME_MINERAL, priors(i), prior_status)
    call req(prior_status == FMR_ELAS_PRIOR_OK .and. priors(i)%available, 'prior materialize')
  end do

  config = fmr_elastic_storage_application_config_t()
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_INACTIVE, 'A6 inactive')
  call req(.not. bound%elasticity_active .and. all(bound%cofgen(24,1:2) == 0.0_real64), 'A6 identity')
  write(*,'(A)') 'F_PE_ELASTIC25_A6_ELASTIC15_DEFAULT_OFF=PASS'

  config%supplied = .true.
  config%key = FMR_ELAS_CONFIG_KEY_SOURCE
  config%value = FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO
  call fmr_bind_elastic_storage_application_config(config, request, status)
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_OK .and. bound%elasticity_active, 'A7 applied')
  call req(all(bound%cofgen(24,1:2) > 0.0_real64), 'A7 values')
  write(*,'(A)') 'F_PE_ELASTIC25_A7_ELASTIC15_APPLY=PASS'

  base%elasticity_active = .true.
  base%cofgen(24,1:2) = [1.0e-6_real64, 2.0e-6_real64]
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT, 'A8 conflict')
  call req(bound%elasticity_active .and. all(bound%cofgen(24,1:2) == base%cofgen(24,1:2)), 'A8 preserve')
  write(*,'(A)') 'F_PE_ELASTIC25_A8_EXPLICIT_OWNER_PRESERVED=PASS'

  write(*,'(A)') 'F_PE_ELASTIC25=PASS'

contains

  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    p%active_nodes = 2
    allocate(p%cofgen(24,2))
    p%cofgen = 0.0_real64
    p%cofgen(1,:) = 0.05_real64
    p%cofgen(2,:) = 0.45_real64
    p%elasticity_active = .false.
    p%prepared_default_mvg_available = .false.
  end subroutine init_base

  subroutine req(cond, msg)
    logical, intent(in) :: cond
    character(len=*), intent(in) :: msg
    if (.not. cond) then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC25_FAIL', trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic25_application_request
