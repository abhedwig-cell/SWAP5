program test_fpe_elastic29_environment_source
  use mod_fmr_elastic_storage_environment_source, only: &
       fmr_read_elastic_storage_environment_source, FMR_ELAS_ENV_SOURCE_OK, &
       FMR_ELAS_ENV_SOURCE_INACTIVE, FMR_ELAS_ENV_SOURCE_TOO_LONG
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t, fmr_elastic_storage_request_source_selection_t, &
       fmr_resolve_elastic_storage_request_source, FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT, &
       FMR_ELAS_REQUEST_ARBITRATION_OK, FMR_ELAS_REQUEST_ARBITRATION_INACTIVE, &
       FMR_ELAS_REQUEST_ARBITRATION_CONFLICT
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_loader, only: &
       fmr_elastic_storage_request_loader_diagnostics_t, fmr_load_elastic_storage_application_request, &
       FMR_ELAS_REQUEST_LOADER_OK, FMR_ELAS_REQUEST_LOADER_INACTIVE
  implicit none

  character(len=32) :: scenario
  type(fmr_elastic_storage_request_path_candidate_t) :: env, ex, cli
  type(fmr_elastic_storage_request_source_selection_t) :: sel
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_loader_diagnostics_t) :: ldiag
  integer :: status

  call get_command_argument(1, scenario)
  ex=fmr_elastic_storage_request_path_candidate_t()
  cli=fmr_elastic_storage_request_path_candidate_t()

  select case(trim(scenario))
  case('absent')
    call fmr_read_elastic_storage_environment_source(env,status)
    call req(status==FMR_ELAS_ENV_SOURCE_INACTIVE .and. .not.env%supplied,'A1 absent')
    call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
    call req(status==FMR_ELAS_REQUEST_ARBITRATION_INACTIVE .and. .not.sel%active,'A8 arbitration')
    call fmr_load_elastic_storage_application_request(sel%path,request,ldiag)
    call req(ldiag%status==FMR_ELAS_REQUEST_LOADER_INACTIVE .and. .not.request%generated_prior_requested,'A8 loader')
    write(*,'(A)')'F_PE_ELASTIC29_A1_ABSENT_INACTIVE=PASS'
    write(*,'(A)')'F_PE_ELASTIC29_A8_DEFAULT_OFF=PASS'

  case('present')
    call write_text('elastic29-valid.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
    call fmr_read_elastic_storage_environment_source(env,status)
    call req(status==FMR_ELAS_ENV_SOURCE_OK .and. env%supplied,'A2 status')
    call req(trim(env%path)=='elastic29-valid.cfg','A2 path')
    call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
    call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%source==FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT,'A3')
    call fmr_load_elastic_storage_application_request(trim(sel%path),request,ldiag)
    call req(ldiag%status==FMR_ELAS_REQUEST_LOADER_OK .and. request%generated_prior_requested,'A7')
    call execute_command_line('rm -f elastic29-valid.cfg')
    write(*,'(A)')'F_PE_ELASTIC29_A2_PRESENT_IDENTITY=PASS'
    write(*,'(A)')'F_PE_ELASTIC29_A3_ARBITRATION=PASS'
    write(*,'(A)')'F_PE_ELASTIC29_A7_REQUEST_COMPOSITION=PASS'

  case('conflict')
    call fmr_read_elastic_storage_environment_source(env,status)
    call req(status==FMR_ELAS_ENV_SOURCE_OK .and. env%supplied,'A4 env')
    ex%supplied=.true.; ex%path='explicit.cfg'
    call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
    call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A4 conflict')
    write(*,'(A)')'F_PE_ELASTIC29_A4_CONFLICT_PRESERVED=PASS'

  case('empty')
    call fmr_read_elastic_storage_environment_source(env,status)
    call req(status==FMR_ELAS_ENV_SOURCE_INACTIVE .and. .not.env%supplied,'A5 empty')
    write(*,'(A)')'F_PE_ELASTIC29_A5_EMPTY_INACTIVE=PASS'

  case('toolong')
    call fmr_read_elastic_storage_environment_source(env,status)
    call req(status==FMR_ELAS_ENV_SOURCE_TOO_LONG .and. .not.env%supplied,'A6 toolong')
    write(*,'(A)')'F_PE_ELASTIC29_A6_TOO_LONG_FAIL_CLOSED=PASS'

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
      write(*,'(A,1X,A)')'F_PE_ELASTIC29_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic29_environment_source
