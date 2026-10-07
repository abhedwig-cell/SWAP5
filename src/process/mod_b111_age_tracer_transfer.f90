module mod_b111_age_tracer_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_age_tracer_production, only: b111_age_production_result_t, &
       evaluate_b111_age_production, B111_AGE_OK
  implicit none
  private

  integer,parameter,public::B111_AGE_TRANSFER_OK=0
  integer,parameter,public::B111_AGE_TRANSFER_INVALID=1

  type,public::b111_age_transfer_receipt_t
    integer::status=B111_AGE_TRANSFER_INVALID
    real(real64)::age_before=0.0_real64
    real(real64)::age_after=0.0_real64
    real(real64)::age_production=0.0_real64
    real(real64)::chemical_mass_before=0.0_real64
    real(real64)::chemical_mass_after=0.0_real64
  end type

  public::apply_b111_age_production_transfer

contains

  subroutine apply_b111_age_production_transfer(committed,theta_start,theta_end,dz,dt,candidate,receipt)
    type(solute_compartment_state_t),intent(in)::committed
    real(real64),intent(in)::theta_start(:),theta_end(:),dz(:),dt
    type(solute_compartment_state_t),intent(out)::candidate
    type(b111_age_transfer_receipt_t),intent(out)::receipt
    type(b111_age_production_result_t)::production

    candidate=committed
    receipt=b111_age_transfer_receipt_t()
    if(.not.committed%valid())return
    if(size(theta_start)/=size(committed%age_amount).or.size(theta_end)/=size(committed%age_amount).or. &
       size(dz)/=size(committed%age_amount))return
    call evaluate_b111_age_production(theta_start,theta_end,dz,dt,production)
    if(production%status/=B111_AGE_OK)return
    if(.not.allocated(production%production_amount))return

    receipt%age_before=sum(committed%age_amount)
    receipt%chemical_mass_before=committed%solute_total()
    candidate%age_amount=committed%age_amount+production%production_amount
    if(.not.candidate%valid())then
      candidate=committed
      return
    end if
    receipt%age_after=sum(candidate%age_amount)
    receipt%age_production=production%total_production
    receipt%chemical_mass_after=candidate%solute_total()
    if(.not.all(ieee_is_finite([receipt%age_before,receipt%age_after,receipt%age_production, &
       receipt%chemical_mass_before,receipt%chemical_mass_after])))then
      candidate=committed
      receipt=b111_age_transfer_receipt_t()
      return
    end if
    if(abs(receipt%age_after-receipt%age_before-receipt%age_production)> &
       1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(receipt%age_after)))then
      candidate=committed
      receipt=b111_age_transfer_receipt_t()
      return
    end if
    if(receipt%chemical_mass_after/=receipt%chemical_mass_before)then
      candidate=committed
      receipt=b111_age_transfer_receipt_t()
      return
    end if
    receipt%status=B111_AGE_TRANSFER_OK
  end subroutine
end module
