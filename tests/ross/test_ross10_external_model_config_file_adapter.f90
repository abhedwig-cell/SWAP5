program test_ross10_external_model_config_file_adapter
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_kernel_backend, only: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t, &
       FMR_ROSSFAST_CONFIG_OK, FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY, &
       FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, fmr_bind_rossfast_application_config
  use mod_rossfast_application_config_file_adapter, only: &
       FMR_ROSSFAST_CONFIG_FILE_OK, FMR_ROSSFAST_CONFIG_FILE_MISSING_PATH, &
       FMR_ROSSFAST_CONFIG_FILE_OPEN_FAILED, FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX, &
       FMR_ROSSFAST_CONFIG_FILE_MULTIPLE_ASSIGNMENTS, FMR_ROSSFAST_CONFIG_FILE_TOO_LARGE, &
       fmr_read_rossfast_application_config_file
  implicit none

  character(len=1024) :: fixture_root
  type(fmr_rossfast_application_config_t) :: config
  type(fmr_rossfast_application_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:), runtime_templates(:)
  type(fmr_logical_column_t), allocatable :: runtime_columns(:)
  integer :: file_status, binding_status

  if (command_argument_count() /= 1) error stop 110
  call get_command_argument(1, fixture_root)

  call read_fixture('valid.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_OK, 'valid config file rejected')
  call require(config%supplied, 'valid config did not become supplied typed config')
  call require(trim(config%key) == 'SOIL_WATER_MODEL', 'valid config key changed')
  call require(trim(config%value) == 'ROSSFAST_D3R', 'valid config value changed')
  call make_valid_request(columns, templates)
  call fmr_bind_rossfast_application_config(config, columns, templates, &
                                             runtime_columns, runtime_templates, binding_status)
  call require(binding_status == FMR_ROSSFAST_CONFIG_OK, 'valid file did not bind through F-ROSS09')
  call require(allocated(runtime_columns), 'valid file did not materialize runtime columns')
  call require(allocated(runtime_templates), 'valid file did not materialize runtime templates')
  call require(all(runtime_columns%backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL), &
               'valid file did not select the restricted RossFast backend')

  call read_fixture('spaced.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_OK, 'spaced assignment rejected')
  call require(trim(config%key) == 'SOIL_WATER_MODEL', 'spaced key normalization failed')
  call require(trim(config%value) == 'ROSSFAST_D3R', 'spaced value normalization failed')

  call read_fixture('lowercase.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_OK, 'lowercase file syntax rejected too early')
  call make_valid_request(columns, templates)
  call fmr_bind_rossfast_application_config(config, columns, templates, &
                                             runtime_columns, runtime_templates, binding_status)
  call require(binding_status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, &
               'file adapter weakened F-ROSS09 case-sensitive model semantics')
  call require(.not. allocated(runtime_columns), 'lowercase model leaked runtime columns')

  call read_fixture('unknown-key.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_OK, 'unknown key file syntax rejected too early')
  call make_valid_request(columns, templates)
  call fmr_bind_rossfast_application_config(config, columns, templates, &
                                             runtime_columns, runtime_templates, binding_status)
  call require(binding_status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY, &
               'file adapter bypassed F-ROSS09 key validation')
  call require(.not. allocated(runtime_columns), 'unknown key leaked runtime columns')

  call read_fixture('malformed.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX, &
               'malformed assignment did not fail closed')
  call require(.not. config%supplied, 'malformed assignment leaked typed configuration')

  call read_fixture('duplicate.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_MULTIPLE_ASSIGNMENTS, &
               'multiple assignments were silently accepted')
  call require(.not. config%supplied, 'multiple assignments leaked partial configuration')

  call read_fixture('empty.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_INVALID_SYNTAX, 'empty file did not fail closed')
  call require(.not. config%supplied, 'empty file leaked typed configuration')

  call read_fixture('oversized.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_TOO_LARGE, 'oversized file did not fail closed')
  call require(.not. config%supplied, 'oversized file leaked typed configuration')

  call fmr_read_rossfast_application_config_file('', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_MISSING_PATH, 'missing path did not fail closed')
  call require(.not. config%supplied, 'missing path leaked typed configuration')

  call read_fixture('does-not-exist.cfg', config, file_status)
  call require(file_status == FMR_ROSSFAST_CONFIG_FILE_OPEN_FAILED, 'missing file did not fail closed')
  call require(.not. config%supplied, 'missing file leaked typed configuration')

  print '(a)', 'ROSS10_EXTERNAL_MODEL_CONFIG_FILE_ADAPTER PASS'

contains

  subroutine read_fixture(name, out_config, out_status)
    character(len=*), intent(in) :: name
    type(fmr_rossfast_application_config_t), intent(out) :: out_config
    integer, intent(out) :: out_status

    call fmr_read_rossfast_application_config_file(trim(fixture_root)//'/'//trim(name), &
                                                   out_config, out_status)
  end subroutine read_fixture

  subroutine make_valid_request(cols, tmpls)
    type(fmr_rossfast_application_column_t), allocatable, intent(out) :: cols(:)
    type(fmr_template_t), allocatable, intent(out) :: tmpls(:)

    allocate(cols(2), tmpls(1))
    tmpls(1) = fmr_template_t()
    tmpls(1)%template_id = 101_int64
    tmpls(1)%physics_topology_id = 201_int64
    tmpls(1)%vertical_layout_id = 301_int64
    tmpls(1)%state_layout_id = 401_int64
    tmpls(1)%solver_interface_id = 501_int64
    tmpls(1)%compatible_backend_id = 0

    cols(1) = fmr_rossfast_application_column_t()
    cols(1)%column_id = 1_int64
    cols(1)%template_id = tmpls(1)%template_id
    cols(1)%parameter_ref = 11_int64
    cols(1)%state_handle = 21_int64
    cols(1)%forcing_handle = 31_int64

    cols(2) = fmr_rossfast_application_column_t()
    cols(2)%column_id = 2_int64
    cols(2)%template_id = tmpls(1)%template_id
    cols(2)%parameter_ref = 12_int64
    cols(2)%state_handle = 22_int64
    cols(2)%forcing_handle = 32_int64
  end subroutine make_valid_request

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'ROSS10_FAIL '//trim(message)
      error stop 110
    end if
  end subroutine require

end program test_ross10_external_model_config_file_adapter
