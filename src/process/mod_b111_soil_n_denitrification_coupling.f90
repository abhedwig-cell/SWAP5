module mod_b111_soil_n_denitrification_coupling
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_transfer_t
  use mod_soil_n_reaction_transfer, only: build_denitrification_transfer, SOIL_N_REACTION_OK
  implicit none
  private

  integer, parameter, public :: B111_DENITR_COUPLING_OK=0
  integer, parameter, public :: B111_DENITR_COUPLING_INVALID=1

  type, public :: b111_denitrification_coupling_receipt_t
    integer :: status=B111_DENITR_COUPLING_INVALID
    real(real64) :: water_fraction_average=0.0_real64
    real(real64) :: denitrified_n_kg_m2=0.0_real64
  end type

  public :: build_b111_denitrification_transfer

contains

  subroutine build_b111_denitrification_transfer(nf,dz_m,dt_day,wfrac_t,wfrac_t0, &
       rate_constant_per_day,cno3_average_kg_m3,transfer,receipt)
    integer,intent(in)::nf
    real(real64),intent(in)::dz_m,dt_day,wfrac_t,wfrac_t0,rate_constant_per_day,cno3_average_kg_m3
    type(soil_n_transfer_t),intent(out)::transfer
    type(b111_denitrification_coupling_receipt_t),intent(out)::receipt
    integer::status

    transfer=soil_n_transfer_t()
    receipt=b111_denitrification_coupling_receipt_t()
    if(nf<1)return
    if(.not.all(ieee_is_finite([dz_m,dt_day,wfrac_t,wfrac_t0,rate_constant_per_day,cno3_average_kg_m3])))return
    if(dz_m<=0.0_real64.or.dt_day<=0.0_real64.or.min(wfrac_t,wfrac_t0,rate_constant_per_day, &
         cno3_average_kg_m3)<0.0_real64)return

    receipt%water_fraction_average=0.5_real64*(wfrac_t+wfrac_t0)
    receipt%denitrified_n_kg_m2=receipt%water_fraction_average*rate_constant_per_day* &
         cno3_average_kg_m3*dz_m*dt_day
    if(.not.ieee_is_finite(receipt%denitrified_n_kg_m2).or.receipt%denitrified_n_kg_m2<0.0_real64)return

    call build_denitrification_transfer(nf,receipt%denitrified_n_kg_m2,transfer,status)
    if(status/=SOIL_N_REACTION_OK)return
    receipt%status=B111_DENITR_COUPLING_OK
  end subroutine

end module
