program test_fpe_elastic30_cli_source
  use mod_fmr_elastic_storage_cli_source, only: &
       fmr_read_elastic_storage_cli_source, FMR_ELAS_CLI_SOURCE_OK, &
       FMR_ELAS_CLI_SOURCE_INACTIVE, FMR_ELAS_CLI_SOURCE_MULTIPLE, &
       FMR_ELAS_CLI_SOURCE_INVALID_SYNTAX, FMR_ELAS_CLI_SOURCE_TOO_LONG
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t, fmr_elastic_storage_request_source_selection_t, &
       fmr_resolve_elastic_storage_request_source, FMR_ELAS_REQUEST_SOURCE_CLI, &
       FMR_ELAS_REQUEST_ARBITRATION_OK, FMR_ELAS_REQUEST_ARBITRATION_CONFLICT
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_loader, only: &
       fmr_elastic_storage_request_loader_diagnostics_t, fmr_load_elastic_storage_application_request, &
       FMR_ELAS_REQUEST_LOADER_OK
  implicit none

  character(len=32) :: scenario
  type(fmr_elastic_storage_request_path_candidate_t) :: cli, ex, env
  type(fmr_elastic_storage_request_source_selection_t) :: sel
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_loader_diagnostics_t) :: ldiag
  integer :: status

  call get_command_argument(1, scenario)
  ex=fmr_elastic_storage_request_path_candidate_t()
  env=fmr_elastic_storage_request_path_candidate_t()

  select case(trim(scenario))
  case('absent')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_INACTIVE .and. .not.cli%supplied,'A1 absent')
    write(*,'(A)')'F_PE_ELASTIC30_A1_ABSENT_INACTIVE=PASS'

  case('present')
    call write_text('elastic30-valid.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_OK .and. cli%supplied,'A2 status')
    call req(trim(cli%path)=='elastic30-valid.cfg','A2 path')
    call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
    call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%source==FMR_ELAS_REQUEST_SOURCE_CLI,'A7 arbitration')
    call fmr_load_elastic_storage_application_request(trim(sel%path),request,ldiag)
    call req(ldiag%status==FMR_ELAS_REQUEST_LOADER_OK .and. request%generated_prior_requested,'A7 request')
    call execute_command_line('rm -f elastic30-valid.cfg')
    write(*,'(A)')'F_PE_ELASTIC30_A2_PRESENT_IDENTITY=PASS'
    write(*,'(A)')'F_PE_ELASTIC30_A7_REQUEST_COMPOSITION=PASS'

  case('unrelated')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_INACTIVE .and. .not.cli%supplied,'A3 unrelated')
    write(*,'(A)')'F_PE_ELASTIC30_A3_UNRELATED_IGNORED=PASS'

  case('duplicate')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_MULTIPLE .and. .not.cli%supplied,'A4 duplicate')
    write(*,'(A)')'F_PE_ELASTIC30_A4_DUPLICATE_FAIL_CLOSED=PASS'

  case('empty')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_INVALID_SYNTAX .and. .not.cli%supplied,'A5 empty')
    write(*,'(A)')'F_PE_ELASTIC30_A5_EMPTY_FAIL_CLOSED=PASS'

  case('toolong')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_TOO_LONG .and. .not.cli%supplied,'A6 toolong')
    write(*,'(A)')'F_PE_ELASTIC30_A6_TOO_LONG_FAIL_CLOSED=PASS'

  case('conflict')
    call fmr_read_elastic_storage_cli_source(cli,status)
    call req(status==FMR_ELAS_CLI_SOURCE_OK .and. cli%supplied,'A8 cli')
    env%supplied=.true.; env%path='env.cfg'
    call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
    call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A8 conflict')
    write(*,'(A)')'F_PE_ELASTIC30_A8_CONFLICT_PRESERVED=PASS'

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
      write(*,'(A,1X,A)')'F_PE_ELASTIC30_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic30_cli_source
