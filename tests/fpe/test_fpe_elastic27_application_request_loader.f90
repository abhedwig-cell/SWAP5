program test_fpe_elastic27_application_request_loader
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_loader, only: &
       fmr_elastic_storage_request_loader_diagnostics_t, fmr_load_elastic_storage_application_request, &
       FMR_ELAS_REQUEST_LOADER_OK, FMR_ELAS_REQUEST_LOADER_INACTIVE, &
       FMR_ELAS_REQUEST_LOADER_FILE_REJECTED, FMR_ELAS_REQUEST_LOADER_CONFIG_REJECTED
  use mod_fmr_elastic_storage_prior_policy, only: &
       fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &
       FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK, FMR_ELAS_PRIOR_BIND_INACTIVE, FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  implicit none

  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_loader_diagnostics_t) :: diag
  type(fmr_elastic_storage_prior_t) :: priors(2)
  type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
  type(fmr_b110_physical_parameters_t) :: base, bound
  integer :: i, prior_status

  call fmr_load_elastic_storage_application_request('', request, diag)
  call req(diag%status == FMR_ELAS_REQUEST_LOADER_INACTIVE .and. .not. request%generated_prior_requested, 'A1 inactive')
  write(*,'(A)') 'F_PE_ELASTIC27_A1_EMPTY_PATH_INACTIVE=PASS'

  call write_text('elastic27-valid.cfg', 'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
  call fmr_load_elastic_storage_application_request('elastic27-valid.cfg', request, diag)
  call req(diag%status == FMR_ELAS_REQUEST_LOADER_OK .and. request%generated_prior_requested, 'A2 valid')
  write(*,'(A)') 'F_PE_ELASTIC27_A2_VALID_REQUEST=PASS'

  call fmr_load_elastic_storage_application_request('elastic27-missing.cfg', request, diag)
  call req(diag%status == FMR_ELAS_REQUEST_LOADER_FILE_REJECTED .and. .not. request%generated_prior_requested, 'A3 missing')
  write(*,'(A)') 'F_PE_ELASTIC27_A3_FILE_FAIL_CLOSED=PASS'

  call write_text('elastic27-invalid.cfg', 'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR' // new_line('a') // 'SECOND=VALUE')
  call fmr_load_elastic_storage_application_request('elastic27-invalid.cfg', request, diag)
  call req(diag%status == FMR_ELAS_REQUEST_LOADER_FILE_REJECTED .and. .not. request%generated_prior_requested, 'A4 syntax')
  write(*,'(A)') 'F_PE_ELASTIC27_A4_FILE_PROVENANCE=PASS'

  call write_text('elastic27-unsupported.cfg', 'ELASTIC_STORAGE_SOURCE=OTHER_VALUE')
  call fmr_load_elastic_storage_application_request('elastic27-unsupported.cfg', request, diag)
  call req(diag%status == FMR_ELAS_REQUEST_LOADER_CONFIG_REJECTED .and. .not. request%generated_prior_requested, 'A5 semantic')
  write(*,'(A)') 'F_PE_ELASTIC27_A5_CONFIG_PROVENANCE=PASS'

  call init_base(base)
  do i=1,2
    call materialize_fmr_elastic_storage_prior(1.40_real64 + 0.01_real64*real(i,real64), 0.36_real64, &
         FMR_ELAS_REGIME_MINERAL, priors(i), prior_status)
    call req(prior_status == FMR_ELAS_PRIOR_OK .and. priors(i)%available, 'prior')
  end do

  call fmr_load_elastic_storage_application_request('', request, diag)
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_INACTIVE .and. .not. bound%elasticity_active, 'A6 default off')
  write(*,'(A)') 'F_PE_ELASTIC27_A6_ELASTIC15_DEFAULT_OFF=PASS'

  call fmr_load_elastic_storage_application_request('elastic27-valid.cfg', request, diag)
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_OK .and. bound%elasticity_active, 'A7 apply')
  write(*,'(A)') 'F_PE_ELASTIC27_A7_ELASTIC15_APPLY=PASS'

  base%elasticity_active = .true.
  base%cofgen(24,1:2) = [1.0e-6_real64, 2.0e-6_real64]
  call fmr_bind_generated_elastic_storage_priors(base, request%generated_prior_requested, priors, bound, bind_diag)
  call req(bind_diag%status == FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT, 'A8 conflict')
  write(*,'(A)') 'F_PE_ELASTIC27_A8_EXPLICIT_OWNER_PRESERVED=PASS'

  call cleanup()
  write(*,'(A)') 'F_PE_ELASTIC27=PASS'

contains

  subroutine write_text(path, text)
    character(len=*), intent(in) :: path, text
    integer :: unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)') text
    close(unit)
  end subroutine write_text

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

  subroutine cleanup()
    call execute_command_line('rm -f elastic27-valid.cfg elastic27-invalid.cfg elastic27-unsupported.cfg')
  end subroutine cleanup

  subroutine req(cond,msg)
    logical,intent(in) :: cond
    character(len=*),intent(in) :: msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC27_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic27_application_request_loader
