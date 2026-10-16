module mod_b111_soil_n_organic_turnover_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, soil_n_transfer_t
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t, &
       b111_organic_turnover_result_t, evaluate_b111_organic_turnover, B111_ORG_TURNOVER_OK
  use mod_b111_soil_n_organic_mineralization_transfer, only: b111_organic_n_mineralization_receipt_t, &
       build_b111_organic_n_mineralization_transfer, B111_ORGN_TRANSFER_OK
  implicit none
  private

  integer,parameter,public::B111_ORGN_TURNOVER_OK=0
  integer,parameter,public::B111_ORGN_TURNOVER_INVALID=1
  integer,parameter,public::B111_ORGN_TURNOVER_OM_FAILED=2
  integer,parameter,public::B111_ORGN_TURNOVER_N_FAILED=3

  type,public::b111_organic_n_turnover_receipt_t
    integer::status=B111_ORGN_TURNOVER_INVALID
    type(b111_organic_turnover_result_t)::organic
    type(b111_organic_n_mineralization_receipt_t)::nitrogen
  end type

  public::build_b111_organic_n_turnover_transfer

contains

  subroutine build_b111_organic_n_turnover_transfer(owner_params,committed,dt,turnover_params,transfer,receipt)
    type(soil_n_inventory_parameters_t),intent(in)::owner_params
    type(soil_n_pool_state_t),intent(in)::committed
    real(real64),intent(in)::dt
    type(b111_organic_turnover_parameters_t),intent(in)::turnover_params
    type(soil_n_transfer_t),intent(out)::transfer
    type(b111_organic_n_turnover_receipt_t),intent(out)::receipt

    transfer=soil_n_transfer_t()
    receipt=b111_organic_n_turnover_receipt_t()
    if(.not.owner_params%valid().or..not.committed%valid())return

    call evaluate_b111_organic_turnover(committed%fom_kg_m3,committed%biomass_kg_m3, &
         committed%humus_kg_m3,dt,turnover_params,receipt%organic)
    if(receipt%organic%status/=B111_ORG_TURNOVER_OK)then
      receipt%status=B111_ORGN_TURNOVER_OM_FAILED
      return
    end if

    call build_b111_organic_n_mineralization_transfer(owner_params,committed,receipt%organic%fom_kg_m3, &
         receipt%organic%biomass_kg_m3,receipt%organic%humus_kg_m3,transfer,receipt%nitrogen)
    if(receipt%nitrogen%status/=B111_ORGN_TRANSFER_OK)then
      transfer=soil_n_transfer_t()
      receipt%status=B111_ORGN_TURNOVER_N_FAILED
      return
    end if
    receipt%status=B111_ORGN_TURNOVER_OK
  end subroutine
end module
