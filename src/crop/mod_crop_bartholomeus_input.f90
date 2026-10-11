module mod_crop_bartholomeus_input
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  type, public :: crop_bartholomeus_input_t
    ! Read-only publication of the crop owner's already constructed nodal
    ! wroot_node_top. No second crop lifecycle or normalized-root surrogate.
    real(real64), allocatable :: root_density_kg_m3(:)
    real(real64) :: air_temperature_c = 0.0_real64
  end type
  public :: publish_crop_bartholomeus_input, valid_crop_bartholomeus_input
contains
  subroutine publish_crop_bartholomeus_input(root_density_kg_m3,air_temperature_c,input,ok)
    real(real64), intent(in) :: root_density_kg_m3(:),air_temperature_c
    type(crop_bartholomeus_input_t), intent(out) :: input
    logical, intent(out) :: ok
    input%root_density_kg_m3=root_density_kg_m3
    input%air_temperature_c=air_temperature_c
    ok=valid_crop_bartholomeus_input(input,size(root_density_kg_m3))
    if(.not.ok) input=crop_bartholomeus_input_t()
  end subroutine
  pure logical function valid_crop_bartholomeus_input(input,active_nodes) result(ok)
    type(crop_bartholomeus_input_t), intent(in) :: input
    integer, intent(in) :: active_nodes
    ok=.false.
    if(active_nodes<0 .or. .not.allocated(input%root_density_kg_m3)) return
    if(size(input%root_density_kg_m3)>active_nodes) return
    if(any(.not.ieee_is_finite(input%root_density_kg_m3))) return
    if(any(input%root_density_kg_m3<0)) return
    if(.not.ieee_is_finite(input%air_temperature_c)) return
    if(input%air_temperature_c+273.0_real64<=0) return
    ok=.true.
  end function
end module
