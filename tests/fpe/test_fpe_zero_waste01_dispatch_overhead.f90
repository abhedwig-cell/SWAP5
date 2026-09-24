program test_fpe_zero_waste01_dispatch_overhead
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_serialized_execution_plan_t, fmr_build_serialized_execution_plan, fmr_build_execution_order, &
       FMR_BACKEND_SERIALIZED_REFERENCE
  implicit none

  type(fmr_logical_column_t), allocatable :: columns(:), work_columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  integer(int64), allocatable :: receipt_ids(:)
  integer :: n, tcount, quad_reps, linear_reps
  character(len=32) :: arg

  call get_command_argument(1, arg)
  read(arg,*) n
  if (n <= 0) error stop 'dispatch overhead benchmark requires N > 0'

  tcount = min(10, n)
  select case (n)
  case (:100)
    quad_reps = 2000
    linear_reps = 5000
  case (101:1000)
    quad_reps = 50
    linear_reps = 500
  case default
    quad_reps = 2
    linear_reps = 50
  end select

  allocate(columns(n), work_columns(n), templates(tcount), receipt_ids(n))
  call initialize_templates(templates)
  call initialize_canonical_columns(columns, templates)
  receipt_ids = columns%column_id

  call benchmark_registry(columns, templates, quad_reps)
  call benchmark_plan_match(columns, templates, linear_reps)
  call benchmark_order(columns, 'canonical', linear_reps)

  work_columns = columns
  call reverse_columns(work_columns)
  call benchmark_order(work_columns, 'reverse', quad_reps)

  work_columns = columns
  call mix_columns(work_columns)
  call benchmark_order(work_columns, 'mixed', quad_reps)

  call benchmark_diagnostics(columns, linear_reps)
  call benchmark_diagnostics_lean(columns, linear_reps)
  call benchmark_receipt_validation(columns, receipt_ids, quad_reps)
  call benchmark_receipt_lookup(columns, receipt_ids, quad_reps)
  call benchmark_template_lookup(columns, templates, linear_reps)

contains

  subroutine initialize_templates(items)
    type(fmr_template_t), intent(out) :: items(:)
    integer :: i
    do i = 1, size(items)
      items(i)%template_id = 1000_int64 + int(i, int64)
      items(i)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine initialize_templates

  subroutine initialize_canonical_columns(items, tmpls)
    type(fmr_logical_column_t), intent(out) :: items(:)
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer :: i, block, per_template
    per_template = (size(items) + size(tmpls) - 1) / size(tmpls)
    do i = 1, size(items)
      block = min(size(tmpls), 1 + (i-1)/per_template)
      items(i)%column_id = 1000000_int64 + int(i, int64)
      items(i)%template_id = tmpls(block)%template_id
      items(i)%parameter_ref = 1_int64
      items(i)%state_handle = int(i, int64)
      items(i)%forcing_handle = int(i, int64)
      items(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine initialize_canonical_columns

  subroutine reverse_columns(items)
    type(fmr_logical_column_t), intent(inout) :: items(:)
    type(fmr_logical_column_t) :: tmp
    integer :: i, j
    do i = 1, size(items)/2
      j = size(items) + 1 - i
      tmp = items(i); items(i) = items(j); items(j) = tmp
    end do
  end subroutine reverse_columns

  subroutine mix_columns(items)
    type(fmr_logical_column_t), intent(inout) :: items(:)
    type(fmr_logical_column_t), allocatable :: tmp(:)
    integer :: i, left, right, pos
    allocate(tmp(size(items)))
    left = 1; right = size(items); pos = 1
    do while (left <= right)
      tmp(pos) = items(right); pos = pos + 1; right = right - 1
      if (left <= right) then
        tmp(pos) = items(left); pos = pos + 1; left = left + 1
      end if
    end do
    items = tmp
  end subroutine mix_columns

  logical function registry_structure_valid_mirror(cols, tmpls, state_count) result(valid)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer, intent(in) :: state_count
    integer :: i, j

    valid = .false.
    do i = 1, size(tmpls)
      if (tmpls(i)%template_id <= 0_int64) return
      do j = i + 1, size(tmpls)
        if (tmpls(j)%template_id == tmpls(i)%template_id) return
      end do
    end do
    do i = 1, size(cols)
      if (cols(i)%column_id <= 0_int64) return
      do j = i + 1, size(cols)
        if (cols(j)%column_id == cols(i)%column_id) return
        if (cols(j)%state_handle == cols(i)%state_handle) return
      end do
      if (cols(i)%state_handle < 1_int64 .or. cols(i)%state_handle > int(state_count, int64)) return
    end do
    valid = .true.
  end function registry_structure_valid_mirror

  logical function receipt_request_valid_mirror(cols, ids) result(valid)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    integer(int64), intent(in) :: ids(:)
    integer :: i, j
    valid = .true.
    do i = 1, size(ids)
      if (ids(i) <= 0_int64) then
        valid = .false.; return
      end if
      if (.not. any(cols%column_id == ids(i))) then
        valid = .false.; return
      end if
      do j = i + 1, size(ids)
        if (ids(j) == ids(i)) then
          valid = .false.; return
        end if
      end do
    end do
  end function receipt_request_valid_mirror

  integer function find_receipt_slot_mirror(column_id, ids) result(slot)
    integer(int64), intent(in) :: column_id
    integer(int64), intent(in) :: ids(:)
    integer :: i
    slot = 0
    do i = 1, size(ids)
      if (ids(i) == column_id) then
        slot = i
        return
      end if
    end do
  end function find_receipt_slot_mirror

  integer function find_template_index_mirror(template_id, tmpls) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer :: i
    index = 0
    do i = 1, size(tmpls)
      if (tmpls(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index_mirror

  subroutine benchmark_registry(cols, tmpls, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer, intent(in) :: reps
    integer(int64) :: c0, c1, rate, checksum, pair_checks
    integer :: r
    logical :: valid
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      valid = registry_structure_valid_mirror(cols, tmpls, size(cols))
      if (valid) checksum = checksum + 1_int64
    end do
    call system_clock(c1)
    pair_checks = int(size(cols),int64) * int(size(cols)-1,int64)
    call emit('registry_validation','valid',size(cols),reps,c0,c1,rate,checksum,pair_checks)
  end subroutine benchmark_registry

  subroutine benchmark_plan_match(cols, tmpls, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer, intent(in) :: reps
    type(fmr_serialized_execution_plan_t) :: plan
    integer(int64) :: c0, c1, rate, checksum
    integer :: r
    logical :: valid, matches

    call fmr_build_serialized_execution_plan(cols, tmpls, size(cols), plan, valid)
    if (.not. valid .or. .not. plan%ready()) error stop 'dispatch overhead plan construction failed'

    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      matches = plan%matches(cols, tmpls, size(cols))
      if (matches) checksum = checksum + 1_int64
    end do
    call system_clock(c1)
    call emit('execution_plan_match','exact_identity',size(cols),reps,c0,c1,rate,checksum, &
         4_int64*int(size(cols),int64) + int(size(tmpls),int64))
  end subroutine benchmark_plan_match

  subroutine benchmark_order(cols, label, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    character(len=*), intent(in) :: label
    integer, intent(in) :: reps
    integer, allocatable :: order(:)
    integer(int64) :: c0, c1, rate, checksum, max_pair_work
    integer :: r
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      call fmr_build_execution_order(cols, order)
      checksum = checksum + int(order(1),int64) + int(order(size(order)),int64)
    end do
    call system_clock(c1)
    max_pair_work = int(size(cols),int64) * int(size(cols)-1,int64) / 2_int64
    call emit('execution_order',label,size(cols),reps,c0,c1,rate,checksum,max_pair_work)
  end subroutine benchmark_order

  subroutine benchmark_diagnostics(cols, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    integer, intent(in) :: reps
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    integer(int64) :: c0, c1, rate, checksum
    integer :: r, i
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      allocate(diagnostics(size(cols)))
      do i = 1, size(cols)
        diagnostics(i)%column_id = cols(i)%column_id
        diagnostics(i)%template_id = cols(i)%template_id
        diagnostics(i)%backend = cols(i)%backend_id
        diagnostics(i)%execution_class = cols(i)%execution_class
        allocate(diagnostics(i)%worker_assignments(1))
        diagnostics(i)%worker_assignments(1) = 1
      end do
      checksum = checksum + diagnostics(size(cols))%column_id
      deallocate(diagnostics)
    end do
    call system_clock(c1)
    call emit('diagnostics_worker_init','worker_assignments_len1',size(cols),reps,c0,c1,rate,checksum,int(size(cols),int64))
  end subroutine benchmark_diagnostics

  subroutine benchmark_diagnostics_lean(cols, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    integer, intent(in) :: reps
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    integer(int64) :: c0, c1, rate, checksum
    integer :: r, i
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      allocate(diagnostics(size(cols)))
      do i = 1, size(cols)
        diagnostics(i)%column_id = cols(i)%column_id
        diagnostics(i)%template_id = cols(i)%template_id
        diagnostics(i)%backend = cols(i)%backend_id
        diagnostics(i)%execution_class = cols(i)%execution_class
      end do
      checksum = checksum + diagnostics(size(cols))%column_id
      deallocate(diagnostics)
    end do
    call system_clock(c1)
    call emit('diagnostics_worker_init','no_worker_assignment_materialization',size(cols),reps, &
         c0,c1,rate,checksum,int(size(cols),int64))
  end subroutine benchmark_diagnostics_lean

  subroutine benchmark_receipt_validation(cols, ids, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    integer(int64), intent(in) :: ids(:)
    integer, intent(in) :: reps
    integer(int64) :: c0, c1, rate, checksum, approx_checks
    integer :: r
    logical :: valid
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      valid = receipt_request_valid_mirror(cols, ids)
      if (valid) checksum = checksum + 1_int64
    end do
    call system_clock(c1)
    approx_checks = int(size(ids),int64)*int(size(cols),int64) + &
         int(size(ids),int64)*int(size(ids)-1,int64)/2_int64
    call emit('receipt_validation','R_equals_N',size(cols),reps,c0,c1,rate,checksum,approx_checks)
  end subroutine benchmark_receipt_validation

  subroutine benchmark_receipt_lookup(cols, ids, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    integer(int64), intent(in) :: ids(:)
    integer, intent(in) :: reps
    integer(int64) :: c0, c1, rate, checksum, approx_checks
    integer :: r, i, slot
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      do i = 1, size(cols)
        slot = find_receipt_slot_mirror(cols(i)%column_id, ids)
        checksum = checksum + int(slot,int64)
      end do
    end do
    call system_clock(c1)
    approx_checks = int(size(cols),int64)*int(size(cols)+1,int64)/2_int64
    call emit('receipt_lookup','R_equals_N',size(cols),reps,c0,c1,rate,checksum,approx_checks)
  end subroutine benchmark_receipt_lookup

  subroutine benchmark_template_lookup(cols, tmpls, reps)
    type(fmr_logical_column_t), intent(in) :: cols(:)
    type(fmr_template_t), intent(in) :: tmpls(:)
    integer, intent(in) :: reps
    integer(int64) :: c0, c1, rate, checksum
    integer :: r, i, idx
    checksum = 0_int64
    call system_clock(c0, rate)
    do r = 1, reps
      do i = 1, size(cols)
        idx = find_template_index_mirror(cols(i)%template_id, tmpls)
        checksum = checksum + int(idx,int64)
      end do
    end do
    call system_clock(c1)
    call emit('template_lookup','T_le_10',size(cols),reps,c0,c1,rate,checksum,int(size(tmpls),int64))
  end subroutine benchmark_template_lookup

  subroutine emit(metric, shape, nvalue, reps, c0, c1, rate, checksum, work_count)
    character(len=*), intent(in) :: metric, shape
    integer, intent(in) :: nvalue, reps
    integer(int64), intent(in) :: c0, c1, rate, checksum, work_count
    real(real64) :: seconds, ns_per_dispatch
    seconds = real(c1-c0,real64)/real(rate,real64)
    ns_per_dispatch = 1.0e9_real64*seconds/real(reps,real64)
    write(*,'(A,A,A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,I0,A,I0)') &
         'ZW_DISPATCH,metric=',trim(metric),',shape=',trim(shape),',n=',nvalue,',reps=',reps, &
         ',seconds=',seconds,',ns_per_dispatch=',ns_per_dispatch,',checksum=',checksum,',work_count=',work_count
  end subroutine emit

end program test_fpe_zero_waste01_dispatch_overhead
