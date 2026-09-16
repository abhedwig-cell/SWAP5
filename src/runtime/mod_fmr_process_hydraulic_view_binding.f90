module mod_fmr_process_hydraulic_view_binding
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  implicit none
  private

  public :: fmr_build_committed_process_hydraulic_view

contains

  subroutine fmr_build_committed_process_hydraulic_view(committed, view, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot
    integer :: n
    logical :: available

    view = process_hydraulic_view_t()
    ok = .false.

    ! The kernel snapshot is already a detached transaction clone. Transfer the
    ! clone-owned allocatables into the existing owning process view instead of
    ! copying the complete profile through another temporary state.
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

      view%active_nodes = n
      call move_alloc(physical%pressure_head, view%pressure_head)
      call move_alloc(physical%water_content, view%water_content)
      view%ponding_depth = physical%ponding_depth
      view%groundwater_level = physical%groundwater_level
      ok = .true.
    class default
      return
    end select
  end subroutine fmr_build_committed_process_hydraulic_view

end module mod_fmr_process_hydraulic_view_binding
