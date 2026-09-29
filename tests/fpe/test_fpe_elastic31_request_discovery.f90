program test_fpe_elastic31_request_discovery
  use mod_fmr_elastic_storage_application_request_discovery, only: &
       fmr_elastic_storage_request_discovery_diagnostics_t, &
       fmr_discover_elastic_storage_application_request, &
       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE, &
       FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED, FMR_ELAS_DISCOVERY_SOURCE_CONFLICT, &
       FMR_ELAS_DISCOVERY_REQUEST_REJECTED
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_cli_source, only: FMR_ELAS_CLI_SOURCE_MULTIPLE
  use mod_fmr_elastic_storage_environment_source, only: FMR_ELAS_ENV_SOURCE_TOO_LONG
  implicit none

  character(len=32) :: scenario
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_discovery_diagnostics_t) :: diag

  call get_command_argument(1, scenario)

  select case(trim(scenario))
  case('none')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_INACTIVE .and. .not.request%generated_prior_requested,'A1')
    write(*,'(A)')'F_PE_ELASTIC31_A1_NONE_INACTIVE=PASS'

  case('explicit')
    call write_text('elastic31-explicit.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
    call fmr_discover_elastic_storage_application_request('elastic31-explicit.cfg',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_OK .and. diag%request_ready .and. request%generated_prior_requested,'A2')
    call execute_command_line('rm -f elastic31-explicit.cfg')
    write(*,'(A)')'F_PE_ELASTIC31_A2_EXPLICIT_ONLY=PASS'

  case('cli')
    call write_text('elastic31-cli.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_OK .and. diag%request_ready .and. request%generated_prior_requested,'A3')
    call execute_command_line('rm -f elastic31-cli.cfg')
    write(*,'(A)')'F_PE_ELASTIC31_A3_CLI_ONLY=PASS'

  case('env')
    call write_text('elastic31-env.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_OK .and. diag%request_ready .and. request%generated_prior_requested,'A4')
    call execute_command_line('rm -f elastic31-env.cfg')
    write(*,'(A)')'F_PE_ELASTIC31_A4_ENV_ONLY=PASS'

  case('pair_explicit')
    call fmr_discover_elastic_storage_application_request('explicit.cfg',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_SOURCE_CONFLICT .and. .not.request%generated_prior_requested,'A5 explicit pair')
    write(*,'(A)')'F_PE_ELASTIC31_A5_PAIR_EXPLICIT_CONFLICT=PASS'

  case('pair_external')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_SOURCE_CONFLICT .and. .not.request%generated_prior_requested,'A5 external pair')
    write(*,'(A)')'F_PE_ELASTIC31_A5_PAIR_EXTERNAL_CONFLICT=PASS'

  case('triple')
    call fmr_discover_elastic_storage_application_request('explicit.cfg',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_SOURCE_CONFLICT .and. .not.request%generated_prior_requested,'A6')
    write(*,'(A)')'F_PE_ELASTIC31_A6_TRIPLE_CONFLICT=PASS'

  case('badcli')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED .and. &
         diag%cli_status==FMR_ELAS_CLI_SOURCE_MULTIPLE .and. .not.request%generated_prior_requested,'A7')
    write(*,'(A)')'F_PE_ELASTIC31_A7_CLI_PROVENANCE=PASS'

  case('badenv')
    call fmr_discover_elastic_storage_application_request('',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_SOURCE_READ_REJECTED .and. &
         diag%environment_status==FMR_ELAS_ENV_SOURCE_TOO_LONG .and. .not.request%generated_prior_requested,'A8')
    write(*,'(A)')'F_PE_ELASTIC31_A8_ENV_PROVENANCE=PASS'

  case('reject')
    call fmr_discover_elastic_storage_application_request('elastic31-missing.cfg',request,diag)
    call req(diag%status==FMR_ELAS_DISCOVERY_REQUEST_REJECTED .and. .not.request%generated_prior_requested,'A9')
    write(*,'(A)')'F_PE_ELASTIC31_A9_LOADER_PROVENANCE=PASS'

  case default
    call req(.false.,'unknown scenario')
  end select

contains
  subroutine write_text(path,text)
    character(len=*),intent(in)::path,text
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)')text
    close(unit)
  end subroutine write_text

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC31_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic31_request_discovery
