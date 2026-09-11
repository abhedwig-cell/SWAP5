module mod_fmr_process_hydraulic_view_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  implicit none
  private

  public :: fmr_build_committed_process_hydraulic_view
  public :: fmr_detach_committed_soil_water_state

contains

  subroutine fmr_build_committed_process_hydraulic_view(committed, view, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot
    type(soil_water_physical_state_t) :: state
    integer :: n
    logical :: available

    view = process_hydraulic_view_t()
    ok = .false.

    call committed%snapshot(snapshot, available)
    if (.not. available) return

    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      n = physical%active_nodes
      if (n <= 0) return
      if (.not. allocated(physical%pressure_head)) return
      if (.not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= n) return
      if (size(physical%water_content) /= n) return

      state%active_nodes = n
      allocate(state%pressure_head(n), state%water_content(n))
      state%pressure_head = physical%pressure_head
      state%water_content = physical%water_content
      state%ponding_depth = physical%ponding_depth
      state%groundwater_level = physical%groundwater_level
      call build_process_hydraulic_view(state, view, ok)
    class default
      return
    end select
  end subroutine fmr_build_committed_process_hydraulic_view

  subroutine fmr_detach_committed_soil_water_state(committed, state, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(soil_water_physical_state_t), intent(out) :: state
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot
    integer :: n
    logical :: available

    state = soil_water_physical_state_t()
    ok = .false.

    ! The kernel snapshot is already a transactionally detached clone. Move the
    ! clone-owned allocatables into the process-facing state rather than making
    ! another full-profile copy. No pointer or alias to committed state escapes.
    call committed%snapshot(snapshot, available)
    if (.not. available) return

    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      n = physical%active_nodes
      if (n <= 0) return
      if (.not. allocated(physical%pressure_head)) return
      if (.not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= n) return
      if (size(physical%water_content) /= n) return

      state%active_nodes = n
      call move_alloc(physical%pressure_head, state%pressure_head)
      call move_alloc(physical%water_content, state%water_content)
      state%ponding_depth = physical%ponding_depth
      state%groundwater_level = physical%groundwater_level
      ok = .true.
    class default
      return
    end select
  end subroutine fmr_detach_committed_soil_water_state

end module mod_fmr_process_hydraulic_view_binding
