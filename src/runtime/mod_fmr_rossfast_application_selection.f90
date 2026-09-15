module mod_fmr_rossfast_application_selection
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_EXECUTION_EASY, FMR_EXECUTION_DIFFICULT, FMR_EXECUTION_TERMINAL
  use mod_fmr_serialized_kernel_backend, only: FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
  implicit none
  private

  character(len=*), parameter, public :: FMR_APPLICATION_MODEL_ROSSFAST_D3R = 'ROSSFAST_D3R'

  integer, parameter, public :: FMR_ROSSFAST_SELECTION_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_SELECTION_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_ROSSFAST_SELECTION_UNSUPPORTED_MODEL = 2
  integer, parameter, public :: FMR_ROSSFAST_SELECTION_TEMPLATE_CONFLICT = 3

  type, public :: fmr_rossfast_application_column_t
    character(len=32) :: model_key = ''
    integer(int64) :: column_id = 0_int64
    integer(int64) :: template_id = 0_int64
    integer(int64) :: parameter_ref = 0_int64
    integer(int64) :: state_handle = 0_int64
    integer(int64) :: forcing_handle = 0_int64
    integer :: execution_class = FMR_EXECUTION_EASY
  end type fmr_rossfast_application_column_t

  public :: fmr_materialize_rossfast_d3r_registry

contains

  subroutine fmr_materialize_rossfast_d3r_registry(application_columns, application_templates, &
                                                    runtime_columns, runtime_templates, status)
    type(fmr_rossfast_application_column_t), intent(in) :: application_columns(:)
    type(fmr_template_t), intent(in) :: application_templates(:)
    type(fmr_logical_column_t), allocatable, intent(out) :: runtime_columns(:)
    type(fmr_template_t), allocatable, intent(out) :: runtime_templates(:)
    integer, intent(out) :: status
    integer :: i, j, template_index

    status = FMR_ROSSFAST_SELECTION_INVALID_REQUEST
    if (size(application_columns) == 0 .or. size(application_templates) == 0) return

    ! Validate the complete application request before materializing any runtime
    ! routing object.  This keeps model selection atomic and prevents a mixed or
    ! malformed application batch from partially acquiring backend authority.
    do i = 1, size(application_templates)
      if (application_templates(i)%template_id <= 0_int64) return
      if (application_templates(i)%compatible_backend_id /= 0) then
        status = FMR_ROSSFAST_SELECTION_TEMPLATE_CONFLICT
        return
      end if
      do j = i + 1, size(application_templates)
        if (application_templates(j)%template_id == application_templates(i)%template_id) return
      end do
    end do

    do i = 1, size(application_columns)
      if (trim(application_columns(i)%model_key) /= FMR_APPLICATION_MODEL_ROSSFAST_D3R) then
        status = FMR_ROSSFAST_SELECTION_UNSUPPORTED_MODEL
        return
      end if
      if (application_columns(i)%column_id <= 0_int64 .or. &
          application_columns(i)%template_id <= 0_int64 .or. &
          application_columns(i)%parameter_ref <= 0_int64 .or. &
          application_columns(i)%state_handle <= 0_int64 .or. &
          application_columns(i)%forcing_handle <= 0_int64) return
      if (application_columns(i)%execution_class /= FMR_EXECUTION_EASY .and. &
          application_columns(i)%execution_class /= FMR_EXECUTION_DIFFICULT .and. &
          application_columns(i)%execution_class /= FMR_EXECUTION_TERMINAL) return
      template_index = find_template_index(application_columns(i)%template_id, application_templates)
      if (template_index <= 0) return
      do j = i + 1, size(application_columns)
        if (application_columns(j)%column_id == application_columns(i)%column_id) return
      end do
    end do

    allocate(runtime_templates(size(application_templates)))
    runtime_templates = application_templates
    do i = 1, size(runtime_templates)
      runtime_templates(i)%compatible_backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
    end do

    allocate(runtime_columns(size(application_columns)))
    do i = 1, size(application_columns)
      runtime_columns(i) = fmr_logical_column_t()
      runtime_columns(i)%column_id = application_columns(i)%column_id
      runtime_columns(i)%template_id = application_columns(i)%template_id
      runtime_columns(i)%parameter_ref = application_columns(i)%parameter_ref
      runtime_columns(i)%state_handle = application_columns(i)%state_handle
      runtime_columns(i)%forcing_handle = application_columns(i)%forcing_handle
      runtime_columns(i)%execution_class = application_columns(i)%execution_class
      runtime_columns(i)%backend_id = FMR_BACKEND_SERIALIZED_INJECTED_KERNEL
    end do

    status = FMR_ROSSFAST_SELECTION_OK
  end subroutine fmr_materialize_rossfast_d3r_registry

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i

    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

end module mod_fmr_rossfast_application_selection
