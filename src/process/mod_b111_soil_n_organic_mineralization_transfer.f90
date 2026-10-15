module mod_b111_soil_n_organic_mineralization_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, soil_n_transfer_t
  implicit none
  private

  integer,parameter,public::B111_ORGN_TRANSFER_OK=0
  integer,parameter,public::B111_ORGN_TRANSFER_INVALID=1

  type,public::b111_organic_n_mineralization_receipt_t
    integer::status=B111_ORGN_TRANSFER_INVALID
    real(real64)::organic_n_before_kg_m2=0.0_real64
    real(real64)::organic_n_after_kg_m2=0.0_real64
    real(real64)::mineralized_n_kg_m2=0.0_real64
  end type

  public::build_b111_organic_n_mineralization_transfer

contains

  subroutine build_b111_organic_n_mineralization_transfer(params,committed, &
       candidate_fom_kg_m3,candidate_biomass_kg_m3,candidate_humus_kg_m3,transfer,receipt)
    type(soil_n_inventory_parameters_t),intent(in)::params
    type(soil_n_pool_state_t),intent(in)::committed
    real(real64),intent(in)::candidate_fom_kg_m3(:),candidate_biomass_kg_m3,candidate_humus_kg_m3
    type(soil_n_transfer_t),intent(out)::transfer
    type(b111_organic_n_mineralization_receipt_t),intent(out)::receipt
    real(real64)::before,after

    transfer=soil_n_transfer_t()
    receipt=b111_organic_n_mineralization_receipt_t()
    if(.not.params%valid().or..not.committed%valid())return
    if(size(candidate_fom_kg_m3)/=size(committed%fom_kg_m3).or. &
       size(candidate_fom_kg_m3)/=size(params%nfrac_fom))return
    if(.not.all(ieee_is_finite(candidate_fom_kg_m3)).or. &
       .not.all(ieee_is_finite([candidate_biomass_kg_m3,candidate_humus_kg_m3])))return
    if(any(candidate_fom_kg_m3<0.0_real64).or.candidate_biomass_kg_m3<0.0_real64.or. &
       candidate_humus_kg_m3<0.0_real64)return

    before=params%depth_m*(sum(committed%fom_kg_m3*params%nfrac_fom)+ &
         committed%biomass_kg_m3*params%nfrac_biomass+committed%humus_kg_m3*params%nfrac_humus)
    after=params%depth_m*(sum(candidate_fom_kg_m3*params%nfrac_fom)+ &
         candidate_biomass_kg_m3*params%nfrac_biomass+candidate_humus_kg_m3*params%nfrac_humus)
    if(.not.all(ieee_is_finite([before,after])))return

    allocate(transfer%fom_delta_kg_m3(size(candidate_fom_kg_m3)))
    transfer%fom_delta_kg_m3=candidate_fom_kg_m3-committed%fom_kg_m3
    transfer%biomass_delta_kg_m3=candidate_biomass_kg_m3-committed%biomass_kg_m3
    transfer%humus_delta_kg_m3=candidate_humus_kg_m3-committed%humus_kg_m3
    transfer%ammonium_n_delta_kg_m2=before-after

    receipt%organic_n_before_kg_m2=before
    receipt%organic_n_after_kg_m2=after
    receipt%mineralized_n_kg_m2=before-after
    receipt%status=B111_ORGN_TRANSFER_OK
  end subroutine

end module
