module mod_fmr_micro_constant_lrv_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t
  use mod_crop_root_length_density_constant, only: evaluate_constant_absolute_root_length_density, &
       ROOT_LRV_CONSTANT_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: FMR_MICRO_CONSTANT_LRV_OK = 0
  integer, parameter, public :: FMR_MICRO_CONSTANT_LRV_INVALID_ROUTE = 1
  integer, parameter, public :: FMR_MICRO_CONSTANT_LRV_INVALID_GEOMETRY = 2

  public :: fmr_bind_constant_lrv_to_micro_forcing

contains

  subroutine fmr_bind_constant_lrv_to_micro_forcing(parameters, density_table, rooted_nodes, rooted_bottom_cm, &
                                                     forcing, status)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(wofost_rate_table_t), intent(in) :: density_table
    integer, intent(in) :: rooted_nodes
    real(real64), intent(in) :: rooted_bottom_cm
    type(fmr_b110_physical_forcing_t), intent(inout) :: forcing
    integer, intent(out) :: status

    real(real64), allocatable :: lrv(:)
    integer :: local_status

    status = FMR_MICRO_CONSTANT_LRV_INVALID_ROUTE
    if (.not. parameters%root_extraction_active) return
    if (.not. allocated(parameters%micro_de_willigen)) return
    if (parameters%active_nodes <= 0) return
    if (.not. allocated(parameters%z)) return
    if (size(parameters%z) /= parameters%active_nodes) return

    call evaluate_constant_absolute_root_length_density(density_table, parameters%z, rooted_nodes, &
         rooted_bottom_cm, lrv, local_status)
    if (local_status /= ROOT_LRV_CONSTANT_OK) then
      status = FMR_MICRO_CONSTANT_LRV_INVALID_GEOMETRY
      return
    end if

    if (allocated(forcing%micro_root_length_density)) deallocate(forcing%micro_root_length_density)
    allocate(forcing%micro_root_length_density(parameters%active_nodes))
    forcing%micro_root_length_density = lrv
    forcing%micro_rooted_nodes = rooted_nodes
    status = FMR_MICRO_CONSTANT_LRV_OK
  end subroutine fmr_bind_constant_lrv_to_micro_forcing

end module mod_fmr_micro_constant_lrv_binding
