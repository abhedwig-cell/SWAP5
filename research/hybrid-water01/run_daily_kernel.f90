program run_daily_kernel
  use probe_kernel_donor
  implicit none
  type(kernel_executor_t) :: executor
  type(model_t), target :: model
  type(parameters_t) :: parameters
  type(forcing_t) :: forcing
  type(kernel_committed_state_t), allocatable :: committed(:)
  type(kernel_reference_floor_candidate_t) :: candidate
  type(kernel_reference_floor_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  class(transaction_state_t), allocatable :: initial
  integer :: columns, column, i, day, first, status
  real(real64) :: components(6), pressure(112), stock, t0, t1, accepted_time
  logical :: ok

  read(*,*) columns
  if (columns < 1) error stop 'Expected at least one column'
  allocate(committed(columns))
  call executor%bind_model(model)
  model%daily_pipe = .true.
  do i=1,columns
    read(*,*) first, stock, components, pressure
    allocate(initial, source=state_t(column=i, ticket=first, stock=stock, &
                                    component_stock=components, pressure=pressure))
    call committed(i)%initialize(int(i,int64),initial,ok,35795d0+first)
    if (.not. ok) error stop 'Column initialization failed'
    deallocate(initial)
  end do

  do
    read(*,*,iostat=status) column, day
    if (status /= 0) error stop 'Missing host command'
    if (column == 0) exit
    if (column < 1 .or. column > columns) error stop 'Invalid column'
    t0 = 35795d0 + day - 1
    t1 = t0 + 1
    call executor%sample_reference_floor_interval(parameters,committed(column),forcing,t0,t1,1e-6_real64, &
                                                  result,candidate,diagnostics)
    if (.not. candidate%ready() .or. .not. result%mass%complete) then
      call committed(column)%current_time(accepted_time,ok)
      if (.not. ok .or. accepted_time /= t0) error stop 'Refusal changed committed time'
      write(*,'(a,3(1x,i0),2(1x,es25.17e3))') 'DAILY_REFUSED', column, day, &
        committed(column)%current_revision(), result%mass%residual, result%bottom_outward_exchange_native
      flush(output_unit)
      error stop 'Daily donor candidate rejected'
    end if
    call executor%commit_reference_floor_candidate(committed(column),candidate,diagnostics,ok)
    if (.not. ok) error stop 'Daily commit failed'
    call committed(column)%current_time(accepted_time,ok)
    if (.not. ok .or. accepted_time /= t1) error stop 'Unexpected committed time'
    write(*,'(a,3(1x,i0),2(1x,es25.17e3))') 'DAILY_ACCEPTED', column, day, &
      committed(column)%current_revision(), result%mass%residual, result%bottom_outward_exchange_native
    flush(output_unit)
  end do
end program
