module mod_bartholomeus_factor_provider
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t, valid_bartholomeus_runtime_view
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters, &
       validate_bartholomeus_parameters
  use mod_bartholomeus_response, only: BartholomeusResponseInput
  use mod_bartholomeus_response_assembly, only: assemble_bartholomeus_response_inputs
  use mod_bartholomeus_waterfilm_provider, only: evaluate_bartholomeus_waterfilm, BARTHOLOMEUS_WATERFILM_OK, &
       BARTHOLOMEUS_WATERFILM_REFERENCE
  use mod_bartholomeus_no_stress_gate, only: bartholomeus_macro_supply_bound_no_stress
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
    if(.not.valid_bartholomeus_runtime_view(view)) return
    if(.not.validate_bartholomeus_parameters(data,crop,view%rooted_nodes)) return
    if(.not.ieee_is_finite(atmospheric_ctop)) return
    if(atmospheric_ctop<0) return
    if(size(w_root)/=view%rooted_nodes .or. size(w_root_z0)/=view%rooted_nodes) return
    if(any(.not.ieee_is_finite(w_root)) .or. any(.not.ieee_is_finite(w_root_z0))) return
    if(any(w_root<0) .or. any(w_root_z0<0)) return
    ! PERF02: fail-closed sufficient condition. Only the admitted REFERENCE mode
    ! may bypass waterfilm, and only when every rooted node is proven no-stress.
    if(waterfilm_mode==BARTHOLOMEUS_WATERFILM_REFERENCE) then
      if(bartholomeus_macro_supply_bound_no_stress(view,data,crop,w_root,w_root_z0,atmospheric_ctop)) then
        allocate(factors(view%rooted_nodes)); factors=1.0_real64; ok=.true.; return
      end if
    end if
    call evaluate_bartholomeus_waterfilm(view,data,waterfilm_mode,waterfilm,status)
    if(status/=BARTHOLOMEUS_WATERFILM_OK) return
    call evaluate_bartholomeus_factors(view,data,crop,w_root,w_root_z0,waterfilm,atmospheric_ctop,factors,ok)
  end subroutine
end module
