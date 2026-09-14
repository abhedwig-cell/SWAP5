module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fmr_b110_physical_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
  contains
    procedure :: clone => eb_r06_b110_clone
  end type fmr_b110_physical_state_t

  public :: fmr_new_b110_committed_state

contains

  subroutine eb_r06_b110_clone(self, copy)
    class(fmr_b110_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_physical_state_t :: copy)
    select type (typed => copy)
    type is (fmr_b110_physical_state_t)
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
  end subroutine eb_r06_b110_clone

  subroutine fmr_new_b110_committed_state(committed, lineage_id, physical, initial_time, initialized)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: physical
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: initialized
    class(transaction_state_t), allocatable :: state

    allocate(fmr_b110_physical_state_t :: state)
    select type (typed => state)
    type is (fmr_b110_physical_state_t)
      typed = physical
    end select
    call committed%initialize(lineage_id, state, initialized, initial_time)
  end subroutine fmr_new_b110_committed_state

end module mod_fmr_serialized_reference_backend
