module mod_fmr_irrigation_joint_restart
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_irrigation_process, only: irrigation_state_t
  use mod_fmr_irrigation_restart, only: irrigation_restart_record_t, &
       export_irrigation_restart, restore_irrigation_restart, IRRIGATION_RESTART_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, &
       fmr_export_committed_restart, fmr_restore_committed_restart, FMR_RESTART_OK
  implicit none
  private
  integer, parameter, public :: IRRIGATION_JOINT_RESTART_OK = 0
  integer, parameter, public :: IRRIGATION_JOINT_RESTART_INVALID = 1
  type, public :: irrigation_joint_record_t
    integer(int64) :: column_id = 0_int64
    type(irrigation_restart_record_t) :: management
  end type
  type, public :: irrigation_joint_restart_t
    integer :: schema = 0
    type(fmr_committed_restart_bundle_t) :: physical
    type(irrigation_joint_record_t), allocatable :: management(:)
  end type
  public :: export_irrigation_joint_restart, restore_irrigation_joint_restart
contains
  subroutine export_irrigation_joint_restart(columns,templates,physical_states,management_states, &
       parameter_set_identity,bundle,status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(in) :: physical_states(:)
    type(irrigation_state_t), intent(in) :: management_states(:)
    integer(int64), intent(in) :: parameter_set_identity
    type(irrigation_joint_restart_t), intent(out) :: bundle
    integer, intent(out) :: status
    type(irrigation_joint_restart_t) :: candidate
    logical :: exported
    integer :: i,j,code

    bundle = irrigation_joint_restart_t()
    status = IRRIGATION_JOINT_RESTART_INVALID
    if (size(columns) < 1 .or. size(management_states) /= size(columns)) return
    call fmr_export_committed_restart(columns,templates,physical_states,parameter_set_identity, &
         candidate%physical,exported,code)
    if (.not. exported .or. code /= FMR_RESTART_OK) return
    allocate(candidate%management(size(columns)))
    do i=1,size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j=1,i-1
        if (columns(j)%column_id == columns(i)%column_id) return
      end do
      candidate%management(i)%column_id = columns(i)%column_id
      call export_irrigation_restart(management_states(i),candidate%management(i)%management,code)
      if (code /= IRRIGATION_RESTART_OK) return
    end do
    candidate%schema = 1
    bundle = candidate
    status = IRRIGATION_JOINT_RESTART_OK
  end subroutine

  subroutine restore_irrigation_joint_restart(bundle,parameter_set_identity,columns,templates, &
       physical_states,management_states,restored,status)
    type(irrigation_joint_restart_t), intent(in) :: bundle
    integer(int64), intent(in) :: parameter_set_identity
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(inout) :: physical_states(:)
    type(irrigation_state_t), intent(inout) :: management_states(:)
    logical, intent(out) :: restored
    integer, intent(out) :: status
    type(kernel_committed_state_t), allocatable :: proposed_physical(:)
    type(irrigation_state_t), allocatable :: proposed_management(:)
    integer :: i,j,k,code
    logical :: physical_restored

    restored = .false.
    status = IRRIGATION_JOINT_RESTART_INVALID
    if (bundle%schema /= 1 .or. .not. allocated(bundle%management)) return
    if (size(columns) < 1 .or. size(bundle%management) /= size(columns) .or. &
        size(management_states) /= size(columns) .or. size(physical_states) /= size(columns)) return
    do i=1,size(physical_states)
      if (physical_states(i)%ready()) return
    end do
    allocate(proposed_management(size(columns)),proposed_physical(size(physical_states)))
    do i=1,size(columns)
      if (columns(i)%column_id <= 0_int64) return
      k=0
      do j=1,size(bundle%management)
        if (bundle%management(j)%column_id == columns(i)%column_id) then
          if (k /= 0) return
          k=j
        end if
      end do
      if (k == 0) return
      call restore_irrigation_restart(bundle%management(k)%management,proposed_management(i),code)
      if (code /= IRRIGATION_RESTART_OK) return
    end do
    call fmr_restore_committed_restart(bundle%physical,parameter_set_identity,columns,templates, &
         proposed_physical,physical_restored,code)
    if (.not. physical_restored .or. code /= FMR_RESTART_OK) return
    physical_states = proposed_physical
    management_states = proposed_management
    restored = .true.
    status = IRRIGATION_JOINT_RESTART_OK
  end subroutine
end module
