module mod_fmr_runtime_core
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: FMR_BACKEND_DETERMINISTIC_TEST = 1
  integer, parameter, public :: FMR_BACKEND_SERIALIZED_REFERENCE = 2
  integer, parameter, public :: FMR_BACKEND_PARALLEL_REFERENCE = 3
  integer, parameter, public :: FMR_EXECUTION_EASY = 1
  integer, parameter, public :: FMR_EXECUTION_DIFFICULT = 2
  integer, parameter, public :: FMR_EXECUTION_TERMINAL = 3

  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_NONE = 0_int64
  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY = 1_int64

  ! Qualified optional physical-state topology identities.  The layout ID is a
  ! template capability identity; it does not imply that every column using the
  ! template currently allocates the corresponding optional state.
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_BASE = 0_int64
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_SNOW = 60605_int64
  integer(int64), parameter, public :: &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE = 390501_int64
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER = 43107_int64
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION = 404001_int64
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION = 404002_int64

  type, public :: fmr_logical_column_t
    integer(int64) :: column_id = 0_int64
    integer(int64) :: template_id = 0_int64
    integer(int64) :: parameter_ref = 0_int64
    integer(int64) :: state_handle = 0_int64
    integer(int64) :: forcing_handle = 0_int64
    integer :: execution_class = FMR_EXECUTION_EASY
    integer :: backend_id = FMR_BACKEND_DETERMINISTIC_TEST
  end type fmr_logical_column_t

  type, public :: fmr_template_t
    integer(int64) :: template_id = 0_int64
    integer(int64) :: physics_topology_id = 0_int64
    integer(int64) :: vertical_layout_id = 0_int64
    integer(int64) :: state_layout_id = 0_int64
    integer(int64) :: solver_interface_id = 0_int64
    ! Physical/feature-dependent optional state topology, e.g. snow.  F-KT
    ! numerical continuation is deliberately a separate axis so solver policy
    ! cannot overload or reinterpret the physical feature layout.
    integer(int64) :: optional_state_layout_id = 0_int64
    integer(int64) :: numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    integer :: compatible_backend_id = 0
  end type fmr_template_t

  type, public :: fmr_column_diagnostics_t
    integer(int64) :: column_id = 0_int64
    integer(int64) :: template_id = 0_int64
    integer :: backend = 0
    integer :: execution_class = 0
    integer(int64) :: committed_revision = -1_int64
    real(real64) :: committed_time = 0.0_real64
    logical :: committed_time_bound = .false.
    integer :: checkpoint_captures = 0
    integer :: checkpoint_replays = 0
    integer :: runtime_attempts = 0
    integer :: attempts = 0
    integer :: retries = 0
    integer :: accepted = 0
    integer :: rejected = 0
    integer, allocatable :: worker_assignments(:)
    integer(int64) :: synthetic_cost = 0_int64
    character(len=32) :: failure_classification = 'NONE'
    real(real64) :: unrounded_mass_residual = 0.0_real64
  end type fmr_column_diagnostics_t

  type, public :: fmr_serialized_execution_plan_t
    private
    logical :: initialized = .false.
    integer(int64), allocatable :: column_ids(:)
    integer(int64), allocatable :: column_template_ids(:)
    integer(int64), allocatable :: state_handles(:)
    integer(int64), allocatable :: template_ids(:)
    integer, allocatable :: order(:)
    integer, allocatable :: template_indices(:)
    integer(int64) :: max_state_handle = 0_int64
  contains
    procedure, public :: ready => execution_plan_ready
    procedure, public :: matches => execution_plan_matches
    procedure, public :: column_count => execution_plan_column_count
    procedure, public :: order_index => execution_plan_order_index
    procedure, public :: template_index => execution_plan_template_index
    procedure, public :: clear => execution_plan_clear
  end type fmr_serialized_execution_plan_t

  type, public :: fmr_aggregate_diagnostics_t
    integer :: columns = 0
    integer :: templates = 0
    integer :: batches = 0
    integer :: workers = 0
    integer :: attempts = 0
    integer :: retries = 0
    integer :: failures = 0
    integer(int64), allocatable :: work_distribution(:)
    integer(int64) :: max_cost = 0_int64
    real(real64) :: mean_cost = 0.0_real64
    real(real64) :: p95_cost = 0.0_real64
    real(real64) :: aggregate_unrounded_mass_residual = 0.0_real64
  end type fmr_aggregate_diagnostics_t

  type, public :: fmr_memory_report_t
    integer(int64) :: logical_runtime_metadata_bytes_per_column = 0_int64
    integer(int64) :: committed_physical_state_bytes_per_column = 0_int64
    integer(int64) :: committed_carrier_bytes_per_column = 0_int64
    integer(int64) :: shared_immutable_parameter_bytes = 0_int64
    integer(int64) :: optional_state_overhead_bytes = 0_int64
    integer(int64) :: worker_scratch_bytes_per_worker = 0_int64
  end type fmr_memory_report_t

  public :: fmr_assignment_compatible
  public :: fmr_build_execution_order
  public :: fmr_build_serialized_execution_plan
  public :: fmr_count_templates
  public :: fmr_metadata_bytes_per_column
  public :: fmr_optional_state_layout_known

contains

  subroutine fmr_build_serialized_execution_plan(columns, templates, state_count, plan, valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    type(fmr_serialized_execution_plan_t), intent(out) :: plan
    logical, intent(out) :: valid
    integer :: i

    valid = .false.
    if (.not. execution_plan_registry_valid(columns, templates, state_count)) return
    allocate(plan%column_ids(size(columns)), plan%column_template_ids(size(columns)), &
         plan%state_handles(size(columns)), plan%template_indices(size(columns)), &
         plan%template_ids(size(templates)))
    if (size(columns) > 0) then
      plan%column_ids = columns%column_id
      plan%column_template_ids = columns%template_id
      plan%state_handles = columns%state_handle
      plan%max_state_handle = maxval(columns%state_handle)
    end if
    if (size(templates) > 0) plan%template_ids = templates%template_id
    call fmr_build_execution_order(columns, plan%order)
    do i = 1, size(columns)
      plan%template_indices(i) = execution_plan_find_template(columns(i)%template_id, templates)
    end do
    plan%initialized = .true.
    valid = .true.
  end subroutine fmr_build_serialized_execution_plan

  logical function execution_plan_ready(self) result(ready)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    ready = self%initialized .and. allocated(self%column_ids) .and. &
         allocated(self%column_template_ids) .and. allocated(self%state_handles) .and. &
         allocated(self%template_ids) .and. allocated(self%order) .and. allocated(self%template_indices)
  end function execution_plan_ready

  logical function execution_plan_matches(self, columns, templates, state_count) result(matches)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    integer :: i
    matches = .false.
    if (.not. self%ready()) return
    if (size(columns) /= size(self%column_ids)) return
    if (size(templates) /= size(self%template_ids)) return
    if (int(state_count,int64) < self%max_state_handle) return
    do i = 1, size(columns)
      if (columns(i)%column_id /= self%column_ids(i)) return
      if (columns(i)%template_id /= self%column_template_ids(i)) return
      if (columns(i)%state_handle /= self%state_handles(i)) return
    end do
    do i = 1, size(templates)
      if (templates(i)%template_id /= self%template_ids(i)) return
    end do
    matches = .true.
  end function execution_plan_matches

  integer function execution_plan_column_count(self) result(value)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    value = 0
    if (allocated(self%column_ids)) value = size(self%column_ids)
  end function execution_plan_column_count

  integer function execution_plan_order_index(self, position) result(index)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    integer, intent(in) :: position
    index = 0
    if (.not. allocated(self%order)) return
    if (position < 1 .or. position > size(self%order)) return
    index = self%order(position)
  end function execution_plan_order_index

  integer function execution_plan_template_index(self, column_index) result(index)
    class(fmr_serialized_execution_plan_t), intent(in) :: self
    integer, intent(in) :: column_index
    index = 0
    if (.not. allocated(self%template_indices)) return
    if (column_index < 1 .or. column_index > size(self%template_indices)) return
    index = self%template_indices(column_index)
  end function execution_plan_template_index

  subroutine execution_plan_clear(self)
    class(fmr_serialized_execution_plan_t), intent(inout) :: self
    if (allocated(self%column_ids)) deallocate(self%column_ids)
    if (allocated(self%column_template_ids)) deallocate(self%column_template_ids)
    if (allocated(self%state_handles)) deallocate(self%state_handles)
    if (allocated(self%template_ids)) deallocate(self%template_ids)
    if (allocated(self%order)) deallocate(self%order)
    if (allocated(self%template_indices)) deallocate(self%template_indices)
    self%max_state_handle = 0_int64
    self%initialized = .false.
  end subroutine execution_plan_clear

  logical function execution_plan_registry_valid(columns, templates, state_count) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    integer, intent(in) :: state_count
    integer :: i, j
    valid = .false.
    if (state_count < 0) return
    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do
    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
        if (columns(j)%state_handle == columns(i)%state_handle) return
      end do
      if (columns(i)%state_handle < 1_int64 .or. columns(i)%state_handle > int(state_count,int64)) return
    end do
    valid = .true.
  end function execution_plan_registry_valid

  integer function execution_plan_find_template(template_id, templates) result(index)
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
  end function execution_plan_find_template

  pure logical function fmr_optional_state_layout_known(layout_id) result(known)
    integer(int64), intent(in) :: layout_id

    select case (layout_id)
    case (FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_SNOW, &
          FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, &
          FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER, &
          FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION)
      known = .true.
    case default
      known = .false.
    end select
  end function fmr_optional_state_layout_known

  logical function fmr_assignment_compatible(template, physics_topology_id, state_layout_id, backend_id)
    type(fmr_template_t), intent(in) :: template
    integer(int64), intent(in) :: physics_topology_id, state_layout_id
    integer, intent(in) :: backend_id

    fmr_assignment_compatible = template%template_id > 0_int64 .and. &
         template%physics_topology_id == physics_topology_id .and. &
         template%state_layout_id == state_layout_id .and. &
         template%compatible_backend_id == backend_id
  end function fmr_assignment_compatible

  subroutine fmr_build_execution_order(columns, order)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer, allocatable, intent(out) :: order(:)
    integer :: i, j, key

    allocate(order(size(columns)))
    do i = 1, size(columns)
      order(i) = i
    end do

    do i = 2, size(order)
      key = order(i)
      j = i - 1
      do while (j >= 1)
        if (.not. column_after(columns(order(j)), columns(key))) exit
        order(j + 1) = order(j)
        j = j - 1
      end do
      order(j + 1) = key
    end do
  end subroutine fmr_build_execution_order

  logical function column_after(left, right)
    type(fmr_logical_column_t), intent(in) :: left, right

    if (left%template_id /= right%template_id) then
      column_after = left%template_id > right%template_id
    else
      column_after = left%column_id > right%column_id
    end if
  end function column_after

  integer function fmr_count_templates(columns) result(count)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer(int64), allocatable :: ids(:)
    integer :: i, j
    logical :: seen

    count = 0
    allocate(ids(size(columns)))
    ids = 0_int64
    do i = 1, size(columns)
      seen = .false.
      do j = 1, count
        if (ids(j) == columns(i)%template_id) then
          seen = .true.
          exit
        end if
      end do
      if (.not. seen) then
        count = count + 1
        ids(count) = columns(i)%template_id
      end if
    end do
  end function fmr_count_templates

  integer(int64) function fmr_metadata_bytes_per_column() result(value)
    type(fmr_logical_column_t) :: probe
    value = int(storage_size(probe) / 8, int64)
  end function fmr_metadata_bytes_per_column

end module mod_fmr_runtime_core
