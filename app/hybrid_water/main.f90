program swap5_hybrid_water
  use probe_kernel_donor
  use mod_fmr_soil_water_application_host, only: fmr_resolve_soil_water_application_model, &
       fmr_soil_water_application_selection_t, FMR_APPLICATION_HOST_OK, FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
  implicit none
  character(len=32), parameter :: hybrid_model_keys(3) = &
       [character(len=32) :: 'HYBRID_ANDELST_WATER', 'HYBRID_GRASSGROWTH_WATER', 'HYBRID_HUPSEL_WATER']
  character(len=32) :: requested_model, protocol
  type(fmr_soil_water_application_selection_t) :: selection
  type(kernel_executor_t) :: executor
  type(model_t), target :: model
  type(parameters_t) :: parameters
  type(forcing_t) :: forcing
  type(kernel_committed_state_t), allocatable :: committed(:)
  logical, allocatable :: refused(:)
  type(kernel_reference_floor_candidate_t) :: candidate
  type(kernel_reference_floor_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  class(transaction_state_t), allocatable :: initial
  integer :: columns, column, i, day, first, status, nodes
  real(real64) :: components(6), stock, t0, t1, accepted_time, water_tolerance
  real(real64), allocatable :: pressure(:), clock_origin(:)
  logical :: ok, explicit_project

  if (command_argument_count() < 1 .or. command_argument_count() > 2) error stop 'An explicit soil water model is required'
  call get_command_argument(1, requested_model, status=status)
  if (status /= 0) error stop 'Invalid soil water model argument'
  call fmr_resolve_soil_water_application_model(requested_model, hybrid_model_keys, selection, status)
  if (status /= FMR_APPLICATION_HOST_OK .or. .not. selection%explicit_selection .or. &
      selection%route /= FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE .or. selection%registered_index < 1) &
    error stop 'Soil water model is unavailable in this application'
  explicit_project = command_argument_count()==2
  if (explicit_project) then
    call get_command_argument(2,protocol,status=status)
    if (status/=0 .or. trim(protocol)/='explicit-project') error stop 'Unknown project protocol'
  else if (selection%registered_index/=1) then
    error stop 'Explicit project metadata required'
  end if
  water_tolerance=1e-6_real64
  if (selection%registered_index>=2) water_tolerance=1e-10_real64
  write(*,'(a,1x,a)') 'DAILY_MODEL', trim(selection%model_key)
  flush(output_unit)

  read(*,*) columns
  if (columns < 1) error stop 'Expected at least one column'
  allocate(committed(columns),clock_origin(columns))
  allocate(refused(columns), source=.false.)
  call executor%bind_model(model)
  model%daily_pipe = .true.
  do i=1,columns
    nodes=112; clock_origin(i)=35795d0
    if (explicit_project) read(*,*) nodes,clock_origin(i)
    if (nodes<1 .or. nodes>10000) error stop 'Invalid project grid'
    if (.not.ieee_is_finite(clock_origin(i))) error stop 'Invalid project clock'
    allocate(pressure(nodes))
    read(*,*) first, stock, components, pressure
    if (first<0 .or. .not.all(ieee_is_finite([stock,components,pressure]))) error stop 'Invalid initial state'
    allocate(initial, source=state_t(column=i, ticket=first, stock=stock, &
                                    component_stock=components, pressure=pressure))
    call committed(i)%initialize(int(i,int64),initial,ok,clock_origin(i)+first)
    if (.not. ok) error stop 'Column initialization failed'
    deallocate(initial,pressure)
  end do

  do
    read(*,*,iostat=status) column, day
    if (status /= 0) error stop 'Missing host command'
    if (column == 0) exit
    if (column < 1 .or. column > columns) error stop 'Invalid column'
    if (refused(column)) error stop 'Column was refused'
    call committed(column)%current_time(t0,ok)
    if (.not. ok .or. t0 /= clock_origin(column) + day - 1) error stop 'Requested day does not follow the accepted clock'
    t1 = t0 + 1
    call executor%sample_reference_floor_interval(parameters,committed(column),forcing,t0,t1,water_tolerance, &
                                                  result,candidate,diagnostics)
    if (.not. candidate%ready() .or. .not. result%mass%complete) then
      call committed(column)%current_time(accepted_time,ok)
      if (.not. ok .or. accepted_time /= t0) error stop 'Refusal changed committed time'
      write(*,'(a,3(1x,i0),2(1x,es25.17e3))') 'DAILY_REFUSED', column, day, &
        committed(column)%current_revision(), result%mass%residual, result%bottom_outward_exchange_native
      flush(output_unit)
      refused(column) = .true.
      cycle
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
