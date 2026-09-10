module mod_fmq25r_attack_state
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fmq25r_attack_state_t
    integer(int64) :: poison = 0_int64
  contains
    procedure :: clone => clone_attack
  end type fmq25r_attack_state_t

contains

  subroutine clone_attack(self, copy)
    class(fmq25r_attack_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmq25r_attack_state_t :: copy)
    select type (typed => copy)
    type is (fmq25r_attack_state_t)
      typed%poison = self%poison
    end select
  end subroutine clone_attack
end module mod_fmq25r_attack_state

program test_fmq25r_restart_state_schema_requalification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, &
       fmr_export_committed_restart, fmr_restore_committed_restart, FMR_RESTART_OK, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmq25r_attack_state, only: fmq25r_attack_state_t
  implicit none

  integer, parameter :: ncol = 3
  integer(int64), parameter :: parameter_set_identity = 925001_int64
  real(real64), parameter :: committed_time = 9250.375_real64
  type(fmr_logical_column_t) :: columns(ncol)
  type(fmr_template_t) :: templates(1), temporal_template, unknown_backend_template
  type(kernel_committed_state_t) :: source_states(ncol), targets(ncol)
  type(fmr_committed_restart_bundle_t) :: bundle, attacked
  type(fmr_b110_physical_state_t) :: physical
  logical :: ok, exported, restored
  integer :: status, i

  call configure_template(templates(1))
  call configure_columns(columns, templates(1))
  call configure_physical_state(physical)

  do i = 1, ncol
    physical%pressure_head = [-90.0_real64-real(i,real64), -120.0_real64-real(i,real64)]
    physical%water_content = [0.31_real64, 0.29_real64]
    physical%ponding_depth = 0.001_real64*real(i,real64)
    physical%groundwater_level = -175.0_real64-real(i,real64)
    call fmr_new_b110_committed_state(source_states(i), columns(i)%column_id, physical, committed_time, ok)
    call require(ok .and. source_states(i)%ready(), 'production committed state initialization')
  end do

  call fmr_export_committed_restart(columns, templates, source_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'production restart export')
  write(*,'(A)') 'FMQ25R_PRODUCTION_EXPORT_POSITIVE=PASS'

  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'production restart restore')
  call require(all_ready(targets), 'positive restore publishes complete registry')
  write(*,'(A)') 'FMQ25R_PRODUCTION_RESTORE_POSITIVE=PASS'

  targets = kernel_committed_state_t()
  attacked = bundle
  if (allocated(attacked%records(ncol)%physical_state)) deallocate(attacked%records(ncol)%physical_state)
  allocate(fmq25r_attack_state_t :: attacked%records(ncol)%physical_state)
  select type (bad => attacked%records(ncol)%physical_state)
  type is (fmq25r_attack_state_t)
    bad%poison = 925999_int64
  end select

  call fmr_restore_committed_restart(attacked, parameter_set_identity, columns, templates, targets, restored, status)
  call require(.not. restored, 'wrong concrete state type rejected')
  call require(status == FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'wrong concrete state rejection class')
  call require(all_unready(targets), 'late wrong-type record keeps entire target registry unpublished')
  write(*,'(A)') 'FMQ25R_MALFORMED_CONCRETE_STATE_REJECTED=PASS'
  write(*,'(A)') 'FMQ25R_WHOLE_REGISTRY_ATOMICITY=PASS'

  temporal_template = templates(1)
  temporal_template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  call require(.not. fmr_restart_state_matches_template(physical, temporal_template), &
       'base physical state not admitted as temporal-history state')
  write(*,'(A)') 'FMQ25R_NUMERICAL_CONTINUATION_TYPE_DISCRIMINATOR=PASS'

  unknown_backend_template = templates(1)
  unknown_backend_template%compatible_backend_id = 9925
  call require(.not. fmr_restart_state_matches_template(physical, unknown_backend_template), &
       'unknown backend fails closed')
  write(*,'(A)') 'FMQ25R_UNKNOWN_BACKEND_FAIL_CLOSED=PASS'

  call require(fmr_restart_state_matches_template(physical, templates(1)), 'registered production state family admitted')
  write(*,'(A)') 'FMQ25R_REGISTERED_STATE_FAMILY_POSITIVE=PASS'
  write(*,'(A)') 'FMQ25R_RESTART_STATE_SCHEMA_REQUALIFICATION PASS'

contains

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 92501_int64
    template%physics_topology_id = 925011_int64
    template%vertical_layout_id = 925012_int64
    template%state_layout_id = 925013_int64
    template%solver_interface_id = 925014_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_columns(values, template)
    type(fmr_logical_column_t), intent(out) :: values(:)
    type(fmr_template_t), intent(in) :: template
    integer :: j
    do j = 1, size(values)
      values(j)%column_id = 925100_int64 + int(19*j,int64)
      values(j)%template_id = template%template_id
      values(j)%parameter_ref = 1_int64
      values(j)%state_handle = int(j,int64)
      values(j)%forcing_handle = int(j,int64)
      values(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine configure_columns

  subroutine configure_physical_state(state)
    type(fmr_b110_physical_state_t), intent(out) :: state
    state%active_nodes = 2
    allocate(state%pressure_head(2), state%water_content(2))
    state%pressure_head = [-90.0_real64, -120.0_real64]
    state%water_content = [0.31_real64, 0.29_real64]
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -175.0_real64
  end subroutine configure_physical_state

  logical function all_ready(states) result(ready)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: j
    ready = .true.
    do j = 1, size(states)
      if (.not. states(j)%ready()) then
        ready = .false.
        return
      end if
    end do
  end function all_ready

  logical function all_unready(states) result(unready)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: j
    unready = .true.
    do j = 1, size(states)
      if (states(j)%ready()) then
        unready = .false.
        return
      end if
    end do
  end function all_unready

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FMQ25R_FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmq25r_restart_state_schema_requalification
