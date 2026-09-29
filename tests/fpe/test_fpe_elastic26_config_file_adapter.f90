program test_fpe_elastic26_config_file_adapter
  use mod_fmr_elastic_storage_application_config, only: &
       fmr_elastic_storage_application_config_t, fmr_elastic_storage_application_request_t, &
       fmr_bind_elastic_storage_application_config, FMR_ELAS_CONFIG_OK, &
       FMR_ELAS_CONFIG_UNSUPPORTED_KEY, FMR_ELAS_CONFIG_UNSUPPORTED_VALUE, &
       FMR_ELAS_CONFIG_KEY_SOURCE, FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO
  use mod_fmr_elastic_storage_application_config_file_adapter, only: &
       fmr_read_elastic_storage_application_config_file, &
       FMR_ELAS_CONFIG_FILE_OK, FMR_ELAS_CONFIG_FILE_MISSING_PATH, &
       FMR_ELAS_CONFIG_FILE_OPEN_FAILED, FMR_ELAS_CONFIG_FILE_INVALID_SYNTAX, &
       FMR_ELAS_CONFIG_FILE_MULTIPLE_ASSIGNMENTS, FMR_ELAS_CONFIG_FILE_TOO_LARGE
  implicit none

  type(fmr_elastic_storage_application_config_t) :: config
  type(fmr_elastic_storage_application_request_t) :: request
  integer :: status, semantic_status, unit
  character(len=4097) :: huge
  character(len=*), parameter :: valid_file = 'tests/fpe/_elastic26_valid.tmp'
  character(len=*), parameter :: blank_file = 'tests/fpe/_elastic26_blank.tmp'
  character(len=*), parameter :: bad_file = 'tests/fpe/_elastic26_bad.tmp'
  character(len=*), parameter :: multi_file = 'tests/fpe/_elastic26_multi.tmp'
  character(len=*), parameter :: unsupported_file = 'tests/fpe/_elastic26_unsupported.tmp'
  character(len=*), parameter :: huge_file = 'tests/fpe/_elastic26_huge.tmp'

  call write_lines(valid_file, [character(len=96) :: &
       'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR'])
  call fmr_read_elastic_storage_application_config_file(valid_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_OK .and. config%supplied, 'A1 status')
  call req(trim(config%key) == FMR_ELAS_CONFIG_KEY_SOURCE, 'A1 key')
  call req(trim(config%value) == FMR_ELAS_CONFIG_VALUE_GENERATED_BOFEK_BRO, 'A1 value')
  write(*,'(A)') 'F_PE_ELASTIC26_A1_EXACT_FILE=PASS'

  call write_lines(blank_file, [character(len=96) :: '', &
       'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR', ''])
  call fmr_read_elastic_storage_application_config_file(blank_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_OK .and. config%supplied, 'A2 blank')
  write(*,'(A)') 'F_PE_ELASTIC26_A2_BLANK_LINES=PASS'

  call fmr_read_elastic_storage_application_config_file('', config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_MISSING_PATH .and. .not. config%supplied, 'A3 empty path')
  call fmr_read_elastic_storage_application_config_file('tests/fpe/_elastic26_missing.tmp', config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_OPEN_FAILED .and. .not. config%supplied, 'A3 missing')
  write(*,'(A)') 'F_PE_ELASTIC26_A3_PATH_FAIL_CLOSED=PASS'

  call write_lines(bad_file, [character(len=96) :: 'ELASTIC_STORAGE_SOURCE'])
  call fmr_read_elastic_storage_application_config_file(bad_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_INVALID_SYNTAX .and. .not. config%supplied, 'A4 malformed')
  write(*,'(A)') 'F_PE_ELASTIC26_A4_SYNTAX_FAIL_CLOSED=PASS'

  call write_lines(multi_file, [character(len=96) :: &
       'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR', &
       'OTHER_KEY=OTHER_VALUE'])
  call fmr_read_elastic_storage_application_config_file(multi_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_MULTIPLE_ASSIGNMENTS .and. .not. config%supplied, 'A5 multiple')
  write(*,'(A)') 'F_PE_ELASTIC26_A5_MULTIPLE_FAIL_CLOSED=PASS'

  huge = repeat('X', len(huge))
  open(newunit=unit, file=huge_file, status='replace', action='write')
  write(unit,'(A)') huge
  close(unit)
  call fmr_read_elastic_storage_application_config_file(huge_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_TOO_LARGE .and. .not. config%supplied, 'A6 huge')
  write(*,'(A)') 'F_PE_ELASTIC26_A6_SIZE_FAIL_CLOSED=PASS'

  call write_lines(unsupported_file, [character(len=96) :: 'OTHER_KEY=OTHER_VALUE'])
  call fmr_read_elastic_storage_application_config_file(unsupported_file, config, status)
  call req(status == FMR_ELAS_CONFIG_FILE_OK .and. config%supplied, 'A7 parser accepts')
  call fmr_bind_elastic_storage_application_config(config, request, semantic_status)
  call req(semantic_status == FMR_ELAS_CONFIG_UNSUPPORTED_KEY .and. .not. request%generated_prior_requested, 'A7 semantic')
  config%key = FMR_ELAS_CONFIG_KEY_SOURCE
  config%value = 'OTHER_VALUE'
  call fmr_bind_elastic_storage_application_config(config, request, semantic_status)
  call req(semantic_status == FMR_ELAS_CONFIG_UNSUPPORTED_VALUE .and. .not. request%generated_prior_requested, 'A7 value')
  write(*,'(A)') 'F_PE_ELASTIC26_A7_OWNERSHIP_SEPARATION=PASS'

  call fmr_read_elastic_storage_application_config_file(valid_file, config, status)
  call fmr_bind_elastic_storage_application_config(config, request, semantic_status)
  call req(status == FMR_ELAS_CONFIG_FILE_OK .and. semantic_status == FMR_ELAS_CONFIG_OK, 'A8 status')
  call req(request%generated_prior_requested, 'A8 request')
  write(*,'(A)') 'F_PE_ELASTIC26_A8_ELASTIC25_COMPOSITION=PASS'

  call cleanup(valid_file)
  call cleanup(blank_file)
  call cleanup(bad_file)
  call cleanup(multi_file)
  call cleanup(unsupported_file)
  call cleanup(huge_file)

  write(*,'(A)') 'F_PE_ELASTIC26=PASS'

contains

  subroutine write_lines(path, lines)
    character(len=*), intent(in) :: path
    character(len=*), intent(in) :: lines(:)
    integer :: u, i
    open(newunit=u, file=path, status='replace', action='write')
    do i = 1, size(lines)
      write(u,'(A)') trim(lines(i))
    end do
    close(u)
  end subroutine write_lines

  subroutine cleanup(path)
    character(len=*), intent(in) :: path
    integer :: u, ios
    logical :: exists
    inquire(file=path, exist=exists)
    if (.not. exists) return
    open(newunit=u, file=path, status='old', iostat=ios)
    if (ios == 0) close(u, status='delete')
  end subroutine cleanup

  subroutine req(cond, msg)
    logical, intent(in) :: cond
    character(len=*), intent(in) :: msg
    if (.not. cond) then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC26_FAIL', trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic26_config_file_adapter
