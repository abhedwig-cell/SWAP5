module mod_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  implicit none
  private

  type, public :: process_hydraulic_view_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
  end type process_hydraulic_view_t

  public :: build_process_hydraulic_view
  public :: validate_process_hydraulic_view

contains

  subroutine reset_process_hydraulic_view(view)
    type(process_hydraulic_view_t), intent(inout) :: view

    if (allocated(view%pressure_head)) deallocate(view%pressure_head)
    if (allocated(view%water_content)) deallocate(view%water_content)
    view%active_nodes = 0
    view%ponding_depth = 0.0_real64
    view%groundwater_level = 0.0_real64
  end subroutine reset_process_hydraulic_view

  subroutine build_process_hydraulic_view(state, view, ok)
    type(soil_water_physical_state_t), intent(in) :: state
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    integer :: n

    call reset_process_hydraulic_view(view)
    ok = .false.

    n = state%active_nodes
    if (n <= 0) return
    if (.not. allocated(state%pressure_head)) return
    if (.not. allocated(state%water_content)) return
    if (size(state%pressure_head) /= n) return
    if (size(state%water_content) /= n) return

    allocate(view%pressure_head(n), view%water_content(n))
    view%active_nodes = n
    view%pressure_head = state%pressure_head
    view%water_content = state%water_content
    view%ponding_depth = state%ponding_depth
    view%groundwater_level = state%groundwater_level
    ok = .true.
  end subroutine build_process_hydraulic_view

  subroutine validate_process_hydraulic_view(view, ok)
    type(process_hydraulic_view_t), intent(in) :: view
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = view%active_nodes
    if (n <= 0) return
    if (.not. allocated(view%pressure_head)) return
    if (.not. allocated(view%water_content)) return
    if (size(view%pressure_head) /= n) return
    if (size(view%water_content) /= n) return
    ok = .true.
  end subroutine validate_process_hydraulic_view

end module mod_process_hydraulic_view
