program test_fpe_elastic28_request_source_arbitration
  use mod_fmr_elastic_storage_request_source_arbitration, only: &
       fmr_elastic_storage_request_path_candidate_t, fmr_elastic_storage_request_source_selection_t, &
       fmr_resolve_elastic_storage_request_source, &
       FMR_ELAS_REQUEST_SOURCE_NONE, FMR_ELAS_REQUEST_SOURCE_EXPLICIT, &
       FMR_ELAS_REQUEST_SOURCE_CLI, FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT, &
       FMR_ELAS_REQUEST_ARBITRATION_OK, FMR_ELAS_REQUEST_ARBITRATION_INACTIVE, &
       FMR_ELAS_REQUEST_ARBITRATION_CONFLICT, FMR_ELAS_REQUEST_ARBITRATION_INVALID_SOURCE
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_loader, only: &
       fmr_elastic_storage_request_loader_diagnostics_t, fmr_load_elastic_storage_application_request, &
       FMR_ELAS_REQUEST_LOADER_OK, FMR_ELAS_REQUEST_LOADER_INACTIVE
  implicit none

  type(fmr_elastic_storage_request_path_candidate_t) :: ex, cli, env
  type(fmr_elastic_storage_request_source_selection_t) :: sel
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_loader_diagnostics_t) :: ldiag
  integer :: status

  ex=fmr_elastic_storage_request_path_candidate_t()
  cli=fmr_elastic_storage_request_path_candidate_t()
  env=fmr_elastic_storage_request_path_candidate_t()

  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_INACTIVE .and. .not.sel%active .and. &
       sel%source==FMR_ELAS_REQUEST_SOURCE_NONE,'A1')
  write(*,'(A)')'F_PE_ELASTIC28_A1_ZERO_INACTIVE=PASS'

  ex%supplied=.true.; ex%path='explicit.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%source==FMR_ELAS_REQUEST_SOURCE_EXPLICIT .and. &
       trim(sel%path)=='explicit.cfg','A2 explicit')
  ex=fmr_elastic_storage_request_path_candidate_t()
  cli%supplied=.true.; cli%path='cli.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%source==FMR_ELAS_REQUEST_SOURCE_CLI .and. &
       trim(sel%path)=='cli.cfg','A2 cli')
  cli=fmr_elastic_storage_request_path_candidate_t()
  env%supplied=.true.; env%path='env.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%source==FMR_ELAS_REQUEST_SOURCE_ENVIRONMENT .and. &
       trim(sel%path)=='env.cfg','A2 env')
  write(*,'(A)')'F_PE_ELASTIC28_A2_SINGLE_SOURCE=PASS'

  ex%supplied=.true.; ex%path='a.cfg'
  cli%supplied=.true.; cli%path='b.cfg'
  env=fmr_elastic_storage_request_path_candidate_t()
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A3 pair1')
  cli=fmr_elastic_storage_request_path_candidate_t()
  env%supplied=.true.; env%path='c.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A3 pair2')
  ex=fmr_elastic_storage_request_path_candidate_t()
  cli%supplied=.true.; cli%path='b.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A3 pair3')
  ex%supplied=.true.; ex%path='a.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A3 triple')
  write(*,'(A)')'F_PE_ELASTIC28_A3_CONFLICT_FAIL_CLOSED=PASS'

  ex=fmr_elastic_storage_request_path_candidate_t()
  cli=fmr_elastic_storage_request_path_candidate_t()
  env=fmr_elastic_storage_request_path_candidate_t()
  ex%supplied=.true.; ex%path='   '
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_INVALID_SOURCE .and. .not.sel%active,'A4 blank')
  write(*,'(A)')'F_PE_ELASTIC28_A4_INVALID_SOURCE=PASS'

  ex%path=' leading.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. sel%path(1:1)==' ','A5 leading preserve')
  ex%path='trailing.cfg   '
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. trim(sel%path)=='trailing.cfg','A5 trailing')
  write(*,'(A)')'F_PE_ELASTIC28_A5_PATH_IDENTITY=PASS'

  ex=fmr_elastic_storage_request_path_candidate_t()
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call fmr_load_elastic_storage_application_request(sel%path,request,ldiag)
  call req(ldiag%status==FMR_ELAS_REQUEST_LOADER_INACTIVE .and. .not.request%generated_prior_requested,'A6')
  write(*,'(A)')'F_PE_ELASTIC28_A6_ELASTIC27_INACTIVE=PASS'

  call write_text('elastic28-valid.cfg','ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR')
  ex%supplied=.true.; ex%path='elastic28-valid.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call fmr_load_elastic_storage_application_request(trim(sel%path),request,ldiag)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_OK .and. ldiag%status==FMR_ELAS_REQUEST_LOADER_OK .and. &
       request%generated_prior_requested,'A7')
  write(*,'(A)')'F_PE_ELASTIC28_A7_ELASTIC27_VALID=PASS'

  cli%supplied=.true.; cli%path='does-not-exist.cfg'
  call fmr_resolve_elastic_storage_request_source(ex,cli,env,sel,status)
  call req(status==FMR_ELAS_REQUEST_ARBITRATION_CONFLICT .and. .not.sel%active,'A8 conflict')
  write(*,'(A)')'F_PE_ELASTIC28_A8_NO_AMBIGUOUS_FILE_ACCESS=PASS'

  call execute_command_line('rm -f elastic28-valid.cfg')
  write(*,'(A)')'F_PE_ELASTIC28=PASS'

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
      write(*,'(A,1X,A)')'F_PE_ELASTIC28_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic28_request_source_arbitration
