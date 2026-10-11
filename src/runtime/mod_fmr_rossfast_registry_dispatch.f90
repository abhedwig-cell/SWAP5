module mod_fmr_rossfast_registry_dispatch
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_build_execution_order
  use mod_fmr_serialized_kernel_backend, only: fmr_serialized_kernel_backend_t, &
       fmr_serialized_kernel_execution_result_t, FMR_BACKEND_SERIALIZED_INJECTED_KERNEL, &
       FMR_SERIALIZED_KERNEL_OK
  use mod_rossfast_d3r_execution_policy, only: rossfast_d3r_select_transaction_window
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_forcing_t
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, ROSSFAST_TABLE_PROVIDER_OK
  use mod_rossfast_d3r_kernel_model_adapter, only: rossfast_d3r_kernel_parameters_t, &
       rossfast_d3r_kernel_model_adapter_t
  implicit none
  private

  integer, parameter, public :: FMR_ROSSFAST_DISPATCH_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_DISPATCH_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_ROSSFAST_DISPATCH_ROUTING_REJECTED = 2
  integer, parameter, public :: FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED = 3
  integer, parameter, public :: FMR_ROSSFAST_DISPATCH_EXECUTION_REJECTED = 4

  integer, parameter, public :: FMR_ROSSFAST_COLUMN_NOT_RUN = 0
  integer, parameter, public :: FMR_ROSSFAST_COLUMN_OK = 1
  integer, parameter, public :: FMR_ROSSFAST_COLUMN_ROUTING_REJECTED = 2
  integer, parameter, public :: FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED = 3
  integer, parameter, public :: FMR_ROSSFAST_COLUMN_EXECUTION_REJECTED = 4

  type, public :: fmr_rossfast_dispatch_result_t
    integer(int64) :: column_id = 0_int64
    integer :: dispatch_ordinal = 0
    integer :: status = FMR_ROSSFAST_COLUMN_NOT_RUN
    integer :: provider_status = -1
    type(fmr_serialized_kernel_execution_result_t) :: execution
  end type fmr_rossfast_dispatch_result_t

  type, public :: fmr_rossfast_registry_dispatcher_t
    private
    type(rossfast_d3r_table_registry_t) :: tables
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => fmr_rossfast_registry_dispatcher_initialize
    procedure, public :: execute_batch => fmr_rossfast_registry_dispatcher_execute_batch
  end type fmr_rossfast_registry_dispatcher_t

contains

  subroutine fmr_rossfast_registry_dispatcher_initialize(self, asset_root, valid)
    class(fmr_rossfast_registry_dispatcher_t), intent(out) :: self
    character(len=*), intent(in) :: asset_root
    logical, intent(out) :: valid

    self%initialized = .false.
    call bind_rossfast_d3r_table_registry(self%tables, asset_root, valid)
    self%initialized = valid
  end subroutine fmr_rossfast_registry_dispatcher_initialize

  subroutine fmr_rossfast_registry_dispatcher_execute_batch(self, columns, templates, parameter_registry, &
                                                             forcing_registry, state_registry, numerical_config, &
                                                             t0, t1, results, dispatch_status)
    class(fmr_rossfast_registry_dispatcher_t), intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), intent(in) :: parameter_registry(:)
    type(rossfast_d3r_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_rossfast_dispatch_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: dispatch_status

    type(rossfast_d3r_table_kernel_t), target :: trial_kernel
    type(rossfast_d3r_kernel_model_adapter_t), target :: model
    type(fmr_serialized_kernel_backend_t) :: backend
    integer, allocatable :: order(:)
    integer :: i, pos, idx, parameter_index, forcing_index, state_index, template_index
    integer :: provider_status
    logical :: valid

    allocate(results(size(columns)))
    do i = 1, size(columns)
      results(i) = fmr_rossfast_dispatch_result_t()
      results(i)%column_id = columns(i)%column_id
    end do

    dispatch_status = FMR_ROSSFAST_DISPATCH_INVALID_REQUEST
    if (.not. self%initialized .or. size(columns) == 0 .or. t1 <= t0) return

    if (.not. registry_structure_valid(columns, templates, parameter_registry, forcing_registry, state_registry)) then
      dispatch_status = FMR_ROSSFAST_DISPATCH_ROUTING_REJECTED
      do i = 1, size(results)
        results(i)%status = FMR_ROSSFAST_COLUMN_ROUTING_REJECTED
      end do
      return
    end if

    call fmr_build_execution_order(columns, order)

    ! Preflight every selected immutable table before any physical transaction.
    ! A missing or mismatched production asset therefore cannot yield a partial
    ! batch publication.
    do pos = 1, size(order)
      idx = order(pos)
      parameter_index = int(columns(idx)%parameter_ref)
      call self%tables%initialize_kernel(trial_kernel, parameter_registry(parameter_index)%material, &
           valid, provider_status)
      if (.not. valid .or. provider_status /= ROSSFAST_TABLE_PROVIDER_OK) then
        dispatch_status = FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED
        do i = 1, size(results)
          results(i)%status = FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
        end do
        results(idx)%provider_status = provider_status
        return
      end if
    end do

    dispatch_status = FMR_ROSSFAST_DISPATCH_OK
    do pos = 1, size(order)
      idx = order(pos)
      results(idx)%dispatch_ordinal = pos
      parameter_index = int(columns(idx)%parameter_ref)
      forcing_index = int(columns(idx)%forcing_handle)
      state_index = int(columns(idx)%state_handle)
      template_index = find_template_index(columns(idx)%template_id, templates)

      call self%tables%initialize_kernel(trial_kernel, parameter_registry(parameter_index)%material, &
           valid, provider_status)
      results(idx)%provider_status = provider_status
      if (.not. valid .or. provider_status /= ROSSFAST_TABLE_PROVIDER_OK) then
        results(idx)%status = FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
        dispatch_status = FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED
        cycle
      end if

      call model%bind_trial_kernel(trial_kernel, valid)
      if (.not. valid) then
        results(idx)%status = FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
        dispatch_status = FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED
        cycle
      end if
      call backend%initialize(model, valid)
      if (.not. valid) then
        results(idx)%status = FMR_ROSSFAST_COLUMN_PROVIDER_REJECTED
        dispatch_status = FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED
        cycle
      end if

      call backend%execute(columns(idx), templates(template_index), parameter_registry(parameter_index), &
           forcing_registry(forcing_index), state_registry(state_index), numerical_config, t0, t1, &
           results(idx)%execution, rossfast_d3r_select_transaction_window)
      if (results(idx)%execution%status == FMR_SERIALIZED_KERNEL_OK) then
        results(idx)%status = FMR_ROSSFAST_COLUMN_OK
      else
        results(idx)%status = FMR_ROSSFAST_COLUMN_EXECUTION_REJECTED
        dispatch_status = FMR_ROSSFAST_DISPATCH_EXECUTION_REJECTED
      end if
    end do
  end subroutine fmr_rossfast_registry_dispatcher_execute_batch

  logical function registry_structure_valid(columns, templates, parameters, forcings, states) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(rossfast_d3r_kernel_parameters_t), intent(in) :: parameters(:)
    type(rossfast_d3r_forcing_t), intent(in) :: forcings(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    logical, allocatable :: state_claimed(:)
    integer :: i, j, template_index, state_index

    valid = .false.
    if (size(templates) == 0 .or. size(parameters) == 0 .or. size(forcings) == 0 .or. size(states) == 0) return

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      if (templates(i)%compatible_backend_id /= FMR_BACKEND_SERIALIZED_INJECTED_KERNEL) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    allocate(state_claimed(size(states)))
    state_claimed = .false.
    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64 .or. columns(i)%template_id <= 0_int64) return
      if (columns(i)%backend_id /= FMR_BACKEND_SERIALIZED_INJECTED_KERNEL) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
      end do
      template_index = find_template_index(columns(i)%template_id, templates)
      if (template_index <= 0) return
      if (columns(i)%parameter_ref < 1_int64 .or. &
          columns(i)%parameter_ref > int(size(parameters), int64)) return
      if (columns(i)%forcing_handle < 1_int64 .or. &
          columns(i)%forcing_handle > int(size(forcings), int64)) return
      if (columns(i)%state_handle < 1_int64 .or. &
          columns(i)%state_handle > int(size(states), int64)) return
      state_index = int(columns(i)%state_handle)
      if (state_claimed(state_index)) return
      state_claimed(state_index) = .true.
    end do
    valid = .true.
  end function registry_structure_valid

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

end module mod_fmr_rossfast_registry_dispatch
