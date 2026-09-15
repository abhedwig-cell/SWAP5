module mod_fpe11_current_kernel_view_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  type, extends(transaction_state_t) :: fpe11_test_physical_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
  contains
    procedure :: clone => fpe11_test_state_clone
  end type fpe11_test_physical_state_t

  public :: fpe11_initialize_committed
  public :: fpe11_committed_fingerprint
  public :: fpe11_build_committed_process_hydraulic_view

contains

  subroutine fpe11_test_state_clone(self, copy)
    class(fpe11_test_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fpe11_test_physical_state_t :: copy)
    select type (typed => copy)
    type is (fpe11_test_physical_state_t)
      typed%active_nodes = self%active_nodes
      if (allocated(self%pressure_head)) then
        allocate(typed%pressure_head(size(self%pressure_head)))
        typed%pressure_head = self%pressure_head
      end if
      if (allocated(self%water_content)) then
        allocate(typed%water_content(size(self%water_content)))
        typed%water_content = self%water_content
      end if
      typed%ponding_depth = self%ponding_depth
      typed%groundwater_level = self%groundwater_level
    end select
  end subroutine fpe11_test_state_clone

  subroutine fpe11_initialize_committed(committed, lineage, n, offset, ponding, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage
    integer, intent(in) :: n
    real(real64), intent(in) :: offset, ponding
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: initial
    integer :: i

    ok = .false.
    if (n <= 0) return
    allocate(fpe11_test_physical_state_t :: initial)
    select type (s => initial)
    type is (fpe11_test_physical_state_t)
      s%active_nodes = n
      allocate(s%pressure_head(n), s%water_content(n))
      do i = 1, n
        s%pressure_head(i) = -25.0_real64 - offset - 3.0_real64*real(i-1, real64)
        s%water_content(i) = 0.18_real64 + 0.01_real64*offset + &
             0.08_real64*real(mod(i,7), real64)/6.0_real64
      end do
      s%ponding_depth = ponding
      s%groundwater_level = -250.0_real64 - offset
    end select
    call committed%initialize(lineage, initial, ok, 0.0_real64)
  end subroutine fpe11_initialize_committed

  subroutine fpe11_build_committed_process_hydraulic_view(committed, view, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot

    view = process_hydraulic_view_t()
    ok = .false.
    call committed%snapshot(snapshot, ok)
    if (.not. ok .or. .not. allocated(snapshot)) return
    select type (physical => snapshot)
    type is (fpe11_test_physical_state_t)
      if (physical%active_nodes <= 0) return
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= physical%active_nodes .or. &
          size(physical%water_content) /= physical%active_nodes) return
      view%active_nodes = physical%active_nodes
      call move_alloc(physical%pressure_head, view%pressure_head)
      call move_alloc(physical%water_content, view%water_content)
      view%ponding_depth = physical%ponding_depth
      view%groundwater_level = physical%groundwater_level
      ok = .true.
    class default
      ok = .false.
    end select
  end subroutine fpe11_build_committed_process_hydraulic_view

  subroutine fpe11_committed_fingerprint(committed, fingerprint, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: fingerprint
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: snapshot
    integer :: i

    fingerprint = 0.0_real64
    ok = .false.
    call committed%snapshot(snapshot, ok)
    if (.not. ok .or. .not. allocated(snapshot)) return
    select type (physical => snapshot)
    type is (fpe11_test_physical_state_t)
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) then
        ok = .false.; return
      end if
      fingerprint = physical%ponding_depth + 1.0e-3_real64*physical%groundwater_level
      do i = 1, physical%active_nodes
        fingerprint = fingerprint + real(i,real64)*physical%pressure_head(i) + &
             17.0_real64*real(i,real64)*physical%water_content(i)
      end do
      ok = .true.
    class default
      ok = .false.
    end select
  end subroutine fpe11_committed_fingerprint

end module mod_fpe11_current_kernel_view_binding

module mod_fmr_process_hydraulic_view_binding
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fpe11_current_kernel_view_binding, only: fpe11_build_committed_process_hydraulic_view
  implicit none
  private
  public :: fmr_build_committed_process_hydraulic_view
contains
  subroutine fmr_build_committed_process_hydraulic_view(committed, view, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    call fpe11_build_committed_process_hydraulic_view(committed, view, ok)
  end subroutine fmr_build_committed_process_hydraulic_view
end module mod_fmr_process_hydraulic_view_binding
