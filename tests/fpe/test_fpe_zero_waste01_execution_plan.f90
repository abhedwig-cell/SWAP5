program test_fpe_zero_waste01_execution_plan
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_build_execution_order, &
       FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_execution_plan, only: fmr_serialized_execution_plan_t, fmr_build_serialized_execution_plan
  implicit none

  type(fmr_logical_column_t) :: columns(4), work_columns(4)
  type(fmr_template_t) :: templates(2), work_templates(2)
  type(fmr_serialized_execution_plan_t) :: plan
  integer, allocatable :: expected_order(:)
  integer :: i
  logical :: ok

  call configure(templates, columns)
  call fmr_build_serialized_execution_plan(columns, templates, 4, plan, ok)
  call require(ok .and. plan%ready(), 'valid plan builds and is ready')
  call require(plan%column_count() == 4, 'column count retained')
  call fmr_build_execution_order(columns, expected_order)
  do i = 1, 4
    call require(plan%order_index(i) == expected_order(i), 'execution order matches production helper')
  end do
  call require(plan%template_index(1) == 2 .and. plan%template_index(2) == 1 .and. &
       plan%template_index(3) == 2 .and. plan%template_index(4) == 1, 'template indices pre-resolved')
  call require(plan%matches(columns, templates, 4), 'fresh plan matches source structure')

  work_columns = columns
  work_columns(1)%parameter_ref = 99_int64
  work_columns(2)%forcing_handle = 88_int64
  work_columns(3)%backend_id = -7
  work_columns(4)%execution_class = 123
  call require(plan%matches(work_columns, templates, 4), 'nonstructural routing and diagnostic fields do not stale plan')

  work_columns = columns
  work_columns(1)%column_id = work_columns(1)%column_id + 100_int64
  call require(.not. plan%matches(work_columns, templates, 4), 'column id drift stales plan')

  work_columns = columns
  work_columns(1)%template_id = work_columns(1)%template_id + 100_int64
  call require(.not. plan%matches(work_columns, templates, 4), 'column template id drift stales plan')

  work_columns = columns
  work_columns(1)%state_handle = 4_int64
  call require(.not. plan%matches(work_columns, templates, 4), 'state handle drift stales plan')

  work_templates = templates
  work_templates(1)%template_id = work_templates(1)%template_id + 100_int64
  call require(.not. plan%matches(columns, work_templates, 4), 'template registry id drift stales plan')

  call require(plan%matches(columns, templates, 8), 'larger state registry remains compatible')
  call require(.not. plan%matches(columns, templates, 3), 'state registry below max handle stales plan')

  work_columns = columns
  work_columns(2)%column_id = work_columns(1)%column_id
  call fmr_build_serialized_execution_plan(work_columns, templates, 4, plan, ok)
  call require(.not. ok .and. .not. plan%ready(), 'duplicate column id rejected')

  work_columns = columns
  work_columns(2)%state_handle = work_columns(1)%state_handle
  call fmr_build_serialized_execution_plan(work_columns, templates, 4, plan, ok)
  call require(.not. ok .and. .not. plan%ready(), 'duplicate state handle rejected')

  work_templates = templates
  work_templates(2)%template_id = work_templates(1)%template_id
  call fmr_build_serialized_execution_plan(columns, work_templates, 4, plan, ok)
  call require(.not. ok .and. .not. plan%ready(), 'duplicate template id rejected')

  work_columns = columns
  work_columns(4)%state_handle = 5_int64
  call fmr_build_serialized_execution_plan(work_columns, templates, 4, plan, ok)
  call require(.not. ok .and. .not. plan%ready(), 'out of range state handle rejected')

  work_columns = columns
  work_columns(2)%template_id = 9999_int64
  call fmr_build_serialized_execution_plan(work_columns, templates, 4, plan, ok)
  call require(ok .and. plan%ready(), 'missing per-column template does not reject whole registry')
  call require(plan%template_index(2) == 0, 'missing template pre-resolves to routing miss')

  write(*,'(A)') 'FPE_ZERO_WASTE01_EXECUTION_PLAN_H19A=PASS'

contains

  subroutine configure(tmpls, cols)
    type(fmr_template_t), intent(out) :: tmpls(2)
    type(fmr_logical_column_t), intent(out) :: cols(4)

    tmpls(1)%template_id = 10_int64
    tmpls(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    tmpls(2)%template_id = 20_int64
    tmpls(2)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    cols(1)%column_id = 104_int64
    cols(1)%template_id = 20_int64
    cols(1)%state_handle = 1_int64
    cols(2)%column_id = 101_int64
    cols(2)%template_id = 10_int64
    cols(2)%state_handle = 2_int64
    cols(3)%column_id = 103_int64
    cols(3)%template_id = 20_int64
    cols(3)%state_handle = 3_int64
    cols(4)%column_id = 102_int64
    cols(4)%template_id = 10_int64
    cols(4)%state_handle = 4_int64
  end subroutine configure

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPE_ZERO_WASTE01_EXECUTION_PLAN_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_zero_waste01_execution_plan
