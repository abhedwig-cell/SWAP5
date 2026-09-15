module mod_fmr_rossfast_application_config
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_rossfast_application_selection, only: fmr_rossfast_application_column_t, &
       FMR_APPLICATION_MODEL_ROSSFAST_D3R, FMR_ROSSFAST_SELECTION_OK, &
       fmr_materialize_rossfast_d3r_registry
  implicit none
  private

  character(len=*), parameter, public :: FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL = 'SOIL_WATER_MODEL'

  integer, parameter, public :: FMR_ROSSFAST_CONFIG_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_MISSING = 1
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY = 2
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL = 3
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT = 4
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_INVALID_REQUEST = 5
  integer, parameter, public :: FMR_ROSSFAST_CONFIG_SELECTION_FAILED = 6

  type, public :: fmr_rossfast_application_config_t
    logical :: supplied = .false.
    character(len=32) :: key = ''
    character(len=32) :: value = ''
  end type fmr_rossfast_application_config_t

  public :: fmr_bind_rossfast_application_config

contains

  subroutine fmr_bind_rossfast_application_config(config, application_columns, application_templates, &
                                                   runtime_columns, runtime_templates, status)
    type(fmr_rossfast_application_config_t), intent(in) :: config
    type(fmr_rossfast_application_column_t), intent(in) :: application_columns(:)
    type(fmr_template_t), intent(in) :: application_templates(:)
    type(fmr_logical_column_t), allocatable, intent(out) :: runtime_columns(:)
    type(fmr_template_t), allocatable, intent(out) :: runtime_templates(:)
    integer, intent(out) :: status
    type(fmr_rossfast_application_column_t), allocatable :: bound_columns(:)
    integer :: i, selection_status

    ! F-ROSS09 is an explicit configuration seam only.  Absence never selects
    ! RossFast implicitly, and this module does not inspect or reinterpret any
    ! legacy SWAP solver switch or legacy input-file grammar.
    status = FMR_ROSSFAST_CONFIG_MISSING
    if (.not. config%supplied) return

    if (trim(config%key) /= FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL) then
      status = FMR_ROSSFAST_CONFIG_UNSUPPORTED_KEY
      return
    end if

    if (trim(config%value) /= FMR_APPLICATION_MODEL_ROSSFAST_D3R) then
      status = FMR_ROSSFAST_CONFIG_UNSUPPORTED_MODEL
      return
    end if

    if (size(application_columns) == 0 .or. size(application_templates) == 0) then
      status = FMR_ROSSFAST_CONFIG_INVALID_REQUEST
      return
    end if

    ! The configuration seam owns model selection for this request.  Refuse
    ! pre-bound columns rather than silently overriding a conflicting source of
    ! routing authority.
    do i = 1, size(application_columns)
      if (len_trim(application_columns(i)%model_key) /= 0) then
        status = FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT
        return
      end if
    end do

    allocate(bound_columns(size(application_columns)))
    bound_columns = application_columns
    do i = 1, size(bound_columns)
      bound_columns(i)%model_key = FMR_APPLICATION_MODEL_ROSSFAST_D3R
    end do

    call fmr_materialize_rossfast_d3r_registry(bound_columns, application_templates, &
                                                runtime_columns, runtime_templates, selection_status)
    if (selection_status /= FMR_ROSSFAST_SELECTION_OK) then
      if (allocated(runtime_columns)) deallocate(runtime_columns)
      if (allocated(runtime_templates)) deallocate(runtime_templates)
      status = FMR_ROSSFAST_CONFIG_SELECTION_FAILED
      return
    end if

    status = FMR_ROSSFAST_CONFIG_OK
  end subroutine fmr_bind_rossfast_application_config

end module mod_fmr_rossfast_application_config
