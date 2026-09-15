program test_ross09_explicit_application_model_config_binding
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_EXECUTION_DIFFICULT
  use mod_fmr_serialized_kernel_backend, only: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t, &
       FMR_APPLICATION_MODEL_ROSSFAST_D3R
  use mod_fmr_rossfast_application_config, only: fmr_rossfast_application_config_t, &
       FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL, FMR_ROSSFAST_CONFIG_OK, &
       FMR_ROSSFAST_CONFIG_MISSING, FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY, &
       FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT, &
       FMR_ROSSFAST_CONFIG_SELECTION_FAILED, fmr_bind_rossfast_application_config
  implicit none

  type(fmr_rossfast_application_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:), runtime_templates(:)
  type(fmr_logical_column_t), allocatable :: runtime_columns(:)
  type(fmr_rossfast_application_config_t) :: config
  integer :: status

  call make_valid_request(columns, templates)

  config = fmr_rossfast_application_config_t()
  config%supplied = .true.
  config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
  config%value = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_OK, 'explicit RossFast config rejected')
  call require(allocated(runtime_columns), 'runtime columns not materialized')
  call require(allocated(runtime_templates), 'runtime templates not materialized')
  call require(size(runtime_columns) == 2, 'runtime column count changed')
  call require(size(runtime_templates) == 1, 'runtime template count changed')
  call require(all(runtime_columns%backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL), &
               'RossFast backend identity not materialized')
  call require(runtime_templates(1)%compatible_backend_id == FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
               'template backend identity not materialized')
  call require(runtime_templates(1)%physics_topology_id == templates(1)%physics_topology_id, &
               'template topology metadata changed')
  call require(runtime_templates(1)%vertical_layout_id == templates(1)%vertical_layout_id, &
               'template vertical layout metadata changed')
  call require(runtime_templates(1)%state_layout_id == templates(1)%state_layout_id, &
               'template state layout metadata changed')
  call require(runtime_templates(1)%solver_interface_id == templates(1)%solver_interface_id, &
               'template solver interface metadata changed')
  call require(runtime_columns(1)%parameter_ref == columns(1)%parameter_ref, 'parameter handle changed')
  call require(runtime_columns(2)%state_handle == columns(2)%state_handle, 'state handle changed')
  call require(runtime_columns(2)%forcing_handle == columns(2)%forcing_handle, 'forcing handle changed')
  call require(runtime_columns(2)%execution_class == FMR_EXECUTION_DIFFICULT, 'execution class changed')

  config = fmr_rossfast_application_config_t()
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_MISSING, 'missing config did not fail closed')
  call require(.not. allocated(runtime_columns), 'missing config leaked runtime columns')
  call require(.not. allocated(runtime_templates), 'missing config leaked runtime templates')

  config%supplied = .true.
  config%key = 'MODEL'
  config%value = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY, 'unknown config key did not fail closed')
  call require(.not. allocated(runtime_columns), 'unknown key leaked runtime columns')

  config%key = FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL
  config%value = 'rossfast_d3r'
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, 'case-normalized model key was captured')
  call require(.not. allocated(runtime_columns), 'unsupported model leaked runtime columns')

  config%value = 'RICHARDS'
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL, 'reference model was captured by RossFast config')

  config%value = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  columns(1)%model_key = FMR_APPLICATION_MODEL_ROSSFAST_D3R
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT, 'pre-bound application column was overwritten')
  call require(.not. allocated(runtime_columns), 'column conflict leaked runtime columns')

  call make_valid_request(columns, templates)
  columns(2)%state_handle = 0_int64
  call fmr_bind_rossfast_application_config(config, columns, templates, runtime_columns, runtime_templates, status)
  call require(status == FMR_ROSSFAST_CONFIG_SELECTION_FAILED, 'downstream invalid request did not fail closed')
  call require(.not. allocated(runtime_columns), 'failed downstream selection leaked runtime columns')
  call require(.not. allocated(runtime_templates), 'failed downstream selection leaked runtime templates')

  print '(a)', 'ROSS09_EXPLICIT_APPLICATION_MODEL_CONFIG_BINDING PASS'

contains

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
    cols(2)%execution_class = FMR_EXECUTION_DIFFICULT
  end subroutine make_valid_request

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'ROSS09_FAIL '//trim(message)
      error stop 109
    end if
  end subroutine require

end program test_ross09_explicit_application_model_config_binding
