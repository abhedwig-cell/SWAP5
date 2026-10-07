module mod_kernel_transactions
  implicit none
  type :: kernel_committed_state_t
    integer :: marker = 0
  end type kernel_committed_state_t
end module mod_kernel_transactions

module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type :: fmr_b110_physical_forcing_t
    real(real64), allocatable :: subsurface_irrigation_source(:)
  end type fmr_b110_physical_forcing_t
end module mod_fmr_serialized_reference_backend

module mod_fmr_process_hydraulic_view_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
contains
  subroutine fmr_build_committed_process_hydraulic_view(committed, view, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(process_hydraulic_view_t), intent(out) :: view
    logical, intent(out) :: ok
    allocate(view%pressure_head(3), view%water_content(3))
    view%active_nodes = 3
    view%pressure_head = [-50.0_real64,-75.0_real64,-60.0_real64]
    view%water_content = [0.25_real64,0.25_real64,0.25_real64]
    view%ponding_depth = 0.0_real64
    view%groundwater_level = -2.0_real64
    ok = committed%marker == 1
  end subroutine fmr_build_committed_process_hydraulic_view
end module mod_fmr_process_hydraulic_view_binding
