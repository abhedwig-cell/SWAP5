module mod_fmr_bartholomeus_contract
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_bartholomeus_activation
  use mod_bartholomeus_parameter_contract
  implicit none
  private
  type, public :: fmr_bartholomeus_parameters_t
    type(fmr_bartholomeus_selection_t) :: selection
    type(BartholomeusImmutableDataset) :: soil
    type(BartholomeusCropParameters) :: crop
    real(real64) :: specific_root_length_m_kg = 0.0_real64
  end type
  public :: valid_fmr_bartholomeus_parameters
contains
  logical function valid_fmr_bartholomeus_parameters(parameters,active_nodes) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    integer,intent(in)::active_nodes
    integer::route,wmode
    call select_fmr_bartholomeus_route(parameters%selection,route,wmode)
    ok=route==FMR_BARTHOLOMEUS_DISABLED
    if(ok) return
    if(route/=FMR_BARTHOLOMEUS_ACTIVE) return
    if(.not.ieee_is_finite(parameters%specific_root_length_m_kg)) return
    if(parameters%specific_root_length_m_kg<=0) return
    if(.not.ieee_is_finite(1.0_real64/parameters%specific_root_length_m_kg)) return
    ok=validate_bartholomeus_parameters(parameters%soil,parameters%crop,active_nodes)
  end function
end module
