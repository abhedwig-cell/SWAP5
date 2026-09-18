module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  ! Qualification-only compile fixture for PUB-ME D6.
  !
  ! D6 exercises the exact current-canonical kernel, candidate-bound surface
  ! materialization, accepted commit receipt and accepted-publication modules.
  ! Those modules require the public FMR hydraulic state dynamic type, but not
  ! the serialized backend's unrelated snow/thermal/drainage/RossFast runtime.
  !
  ! This carrier mirrors only the stable hydraulic base fields consumed by
  ! mod_fmr_process_hydraulic_view_binding and the D6 fixture. It is never
  ! production source and is not used to qualify serialized-backend behavior.
  type, extends(transaction_state_t), public :: fmr_b110_physical_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
  contains
    procedure :: clone => d6_fmr_b110_state_clone
  end type fmr_b110_physical_state_t

contains

  subroutine d6_fmr_b110_state_clone(self, copy)
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
  end subroutine d6_fmr_b110_state_clone

end module mod_fmr_serialized_reference_backend
