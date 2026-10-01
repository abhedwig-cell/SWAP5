module mod_bartholomeus_factor_provider
  use iso_fortran_env, only: real64
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters
  use mod_bartholomeus_response, only: BartholomeusResponseInput
  use mod_bartholomeus_response_assembly, only: assemble_bartholomeus_response_inputs
  use mod_bartholomeus_waterfilm_provider, only: evaluate_bartholomeus_waterfilm, BARTHOLOMEUS_WATERFILM_OK
  use mod_bartholomeus_profile_response, only: bartholomeus_profile_factors
  implicit none
  private
  public :: evaluate_bartholomeus_factors
  public :: evaluate_bartholomeus_factors_from_state

contains
  subroutine evaluate_bartholomeus_factors(view,data,crop,w_root,w_root_z0,waterfilm,atmospheric_ctop,factors,ok)
    type(bartholomeus_runtime_view_t),intent(in)::view
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    real(real64),intent(in)::w_root(:),w_root_z0(:),waterfilm(:),atmospheric_ctop
    real(real64),allocatable,intent(out)::factors(:)
    logical,intent(out)::ok
    type(BartholomeusResponseInput),allocatable::input(:)

    ok=.false.
    call assemble_bartholomeus_response_inputs(view,data,crop,w_root,w_root_z0,waterfilm,input,ok)
    if(.not.ok) return
    call bartholomeus_profile_factors(input,atmospheric_ctop,factors,ok)
  end subroutine

  subroutine evaluate_bartholomeus_factors_from_state(view,data,crop,w_root,w_root_z0,atmospheric_ctop,waterfilm_mode,factors,ok)
    type(bartholomeus_runtime_view_t),intent(in)::view
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    real(real64),intent(in)::w_root(:),w_root_z0(:),atmospheric_ctop
    integer,intent(in)::waterfilm_mode
    real(real64),allocatable,intent(out)::factors(:)
    logical,intent(out)::ok
    real(real64),allocatable::waterfilm(:)
    integer::status

    ok=.false.
    call evaluate_bartholomeus_waterfilm(view,data,waterfilm_mode,waterfilm,status)
    if(status/=BARTHOLOMEUS_WATERFILM_OK) return
    call evaluate_bartholomeus_factors(view,data,crop,w_root,w_root_z0,waterfilm,atmospheric_ctop,factors,ok)
  end subroutine
end module
