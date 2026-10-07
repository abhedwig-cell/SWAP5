module mod_soil_n_pool_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::SOIL_N_OK=0,SOIL_N_INVALID=1,SOIL_N_NEGATIVE=2,SOIL_N_BALANCE=3

  type,public::soil_n_inventory_parameters_t
    real(real64)::depth_m=0d0
    real(real64),allocatable::nfrac_fom(:)
    real(real64)::nfrac_biomass=0d0
    real(real64)::nfrac_humus=0d0
  contains
    procedure::valid=>soil_n_params_valid
  end type

  type,public::soil_n_pool_state_t
    real(real64),allocatable::fom_kg_m3(:)
    real(real64)::biomass_kg_m3=0d0
    real(real64)::humus_kg_m3=0d0
    real(real64)::ammonium_n_kg_m2=0d0
    real(real64)::nitrate_n_kg_m2=0d0
  contains
    procedure::valid=>soil_n_state_valid
    procedure::nitrogen_total=>soil_n_nitrogen_total
  end type

  type,public::soil_n_transfer_t
    real(real64),allocatable::fom_delta_kg_m3(:)
    real(real64)::biomass_delta_kg_m3=0d0
    real(real64)::humus_delta_kg_m3=0d0
    real(real64)::ammonium_n_delta_kg_m2=0d0
    real(real64)::nitrate_n_delta_kg_m2=0d0
    real(real64)::external_n_input_kg_m2=0d0
    real(real64)::external_n_output_kg_m2=0d0
  end type

  type,public::soil_n_receipt_t
    integer::status=SOIL_N_OK
    real(real64)::nitrogen_before_kg_m2=0d0
    real(real64)::nitrogen_after_kg_m2=0d0
    real(real64)::external_n_input_kg_m2=0d0
    real(real64)::external_n_output_kg_m2=0d0
    real(real64)::balance_residual_kg_m2=0d0
  end type

  public::initialize_soil_n_pool_state,apply_soil_n_transfer
contains
  pure logical function soil_n_params_valid(self) result(ok)
    class(soil_n_inventory_parameters_t),intent(in)::self
    ok=.false.
    if(self%depth_m<=0d0.or..not.ieee_is_finite(self%depth_m))return
    if(.not.allocated(self%nfrac_fom).or.size(self%nfrac_fom)<1)return
    if(.not.all(ieee_is_finite(self%nfrac_fom)).or.any(self%nfrac_fom<0d0))return
    if(.not.ieee_is_finite(self%nfrac_biomass).or..not.ieee_is_finite(self%nfrac_humus))return
    if(self%nfrac_biomass<0d0.or.self%nfrac_humus<0d0)return
    ok=.true.
  end function

  pure logical function soil_n_state_valid(self) result(ok)
    class(soil_n_pool_state_t),intent(in)::self
    ok=.false.
    if(.not.allocated(self%fom_kg_m3).or.size(self%fom_kg_m3)<1)return
    if(.not.all(ieee_is_finite(self%fom_kg_m3)).or.any(self%fom_kg_m3<0d0))return
    if(.not.all(ieee_is_finite([self%biomass_kg_m3,self%humus_kg_m3, &
         self%ammonium_n_kg_m2,self%nitrate_n_kg_m2])))return
    ok=min(self%biomass_kg_m3,self%humus_kg_m3,self%ammonium_n_kg_m2,self%nitrate_n_kg_m2)>=0d0
  end function

  pure real(real64) function soil_n_nitrogen_total(self,params) result(total)
    class(soil_n_pool_state_t),intent(in)::self
    type(soil_n_inventory_parameters_t),intent(in)::params
    total=-huge(1d0)
    if(.not.self%valid().or..not.params%valid())return
    if(size(self%fom_kg_m3)/=size(params%nfrac_fom))return
    total=self%ammonium_n_kg_m2+self%nitrate_n_kg_m2+params%depth_m*( &
         sum(self%fom_kg_m3*params%nfrac_fom)+self%biomass_kg_m3*params%nfrac_biomass+ &
         self%humus_kg_m3*params%nfrac_humus)
  end function

  subroutine initialize_soil_n_pool_state(params,fom,biomass,humus,ammonium_n,nitrate_n,state,status)
    type(soil_n_inventory_parameters_t),intent(in)::params
    real(real64),intent(in)::fom(:),biomass,humus,ammonium_n,nitrate_n
    type(soil_n_pool_state_t),intent(out)::state
    integer,intent(out)::status
    state=soil_n_pool_state_t();status=SOIL_N_INVALID
    if(.not.params%valid().or.size(fom)/=size(params%nfrac_fom))return
    state%fom_kg_m3=fom;state%biomass_kg_m3=biomass;state%humus_kg_m3=humus
    state%ammonium_n_kg_m2=ammonium_n;state%nitrate_n_kg_m2=nitrate_n
    if(.not.state%valid())then;status=SOIL_N_NEGATIVE;return;end if
    status=SOIL_N_OK
  end subroutine

  subroutine apply_soil_n_transfer(params,committed,transfer,candidate,receipt,tolerance)
    type(soil_n_inventory_parameters_t),intent(in)::params
    type(soil_n_pool_state_t),intent(in)::committed
    type(soil_n_transfer_t),intent(in)::transfer
    type(soil_n_pool_state_t),intent(out)::candidate
    type(soil_n_receipt_t),intent(out)::receipt
    real(real64),intent(in),optional::tolerance
    real(real64)::tol,scale
    candidate=committed;receipt=soil_n_receipt_t();receipt%status=SOIL_N_INVALID
    if(.not.params%valid().or..not.committed%valid())return
    if(size(committed%fom_kg_m3)/=size(params%nfrac_fom))return
    if(.not.allocated(transfer%fom_delta_kg_m3).or.size(transfer%fom_delta_kg_m3)/=size(committed%fom_kg_m3))return
    if(.not.all(ieee_is_finite(transfer%fom_delta_kg_m3)).or. &
       .not.all(ieee_is_finite([transfer%biomass_delta_kg_m3,transfer%humus_delta_kg_m3, &
        transfer%ammonium_n_delta_kg_m2,transfer%nitrate_n_delta_kg_m2, &
        transfer%external_n_input_kg_m2,transfer%external_n_output_kg_m2])))return
    if(transfer%external_n_input_kg_m2<0d0.or.transfer%external_n_output_kg_m2<0d0)return
    candidate%fom_kg_m3=committed%fom_kg_m3+transfer%fom_delta_kg_m3
    candidate%biomass_kg_m3=committed%biomass_kg_m3+transfer%biomass_delta_kg_m3
    candidate%humus_kg_m3=committed%humus_kg_m3+transfer%humus_delta_kg_m3
    candidate%ammonium_n_kg_m2=committed%ammonium_n_kg_m2+transfer%ammonium_n_delta_kg_m2
    candidate%nitrate_n_kg_m2=committed%nitrate_n_kg_m2+transfer%nitrate_n_delta_kg_m2
    if(.not.candidate%valid())then;candidate=committed;receipt%status=SOIL_N_NEGATIVE;return;end if
    receipt%nitrogen_before_kg_m2=committed%nitrogen_total(params)
    receipt%nitrogen_after_kg_m2=candidate%nitrogen_total(params)
    receipt%external_n_input_kg_m2=transfer%external_n_input_kg_m2
    receipt%external_n_output_kg_m2=transfer%external_n_output_kg_m2
    receipt%balance_residual_kg_m2=receipt%nitrogen_after_kg_m2-receipt%nitrogen_before_kg_m2- &
         receipt%external_n_input_kg_m2+receipt%external_n_output_kg_m2
    tol=1d-12;if(present(tolerance))tol=max(0d0,tolerance)
    scale=max(1d0,abs(receipt%nitrogen_before_kg_m2),abs(receipt%nitrogen_after_kg_m2), &
         receipt%external_n_input_kg_m2,receipt%external_n_output_kg_m2)
    if(abs(receipt%balance_residual_kg_m2)>tol*scale)then
      candidate=committed;receipt%status=SOIL_N_BALANCE;return
    end if
    receipt%status=SOIL_N_OK
  end subroutine
end module
