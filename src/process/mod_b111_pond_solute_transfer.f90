module mod_b111_pond_solute_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_pond_solute_exchange, only: b111_pond_solute_result_t, &
       evaluate_b111_pond_solute_exchange, B111_POND_SOL_OK
  implicit none
  private

  integer,parameter,public::B111_POND_TRANSFER_OK=0
  integer,parameter,public::B111_POND_TRANSFER_INVALID=1
  integer,parameter,public::B111_POND_TRANSFER_NEGATIVE=2
  integer,parameter,public::B111_POND_TRANSFER_BALANCE=3

  type,public::b111_pond_transfer_receipt_t
    integer::status=B111_POND_TRANSFER_INVALID
    real(real64)::external_input=0.0_real64
    real(real64)::internal_to_top=0.0_real64
    real(real64)::balance_residual=0.0_real64
  end type

  public::apply_b111_pond_solute_transfer

contains

  subroutine apply_b111_pond_solute_transfer(committed_mobile,committed_companion,water_content, &
       node_thickness_cm,rain_rate,rain_c,irr_rate,irr_c,qtop,macropore_area,pond_end,dt, &
       candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::water_content(:),node_thickness_cm(:)
    real(real64),intent(in)::rain_rate,rain_c,irr_rate,irr_c,qtop,macropore_area,pond_end,dt
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_pond_transfer_receipt_t),intent(out)::receipt
    type(b111_pond_solute_result_t)::pond
    real(real64)::before,after,expected,scale,tol
    integer::n

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_pond_transfer_receipt_t()
    if(.not.allocated(committed_mobile%mass_mg_cm2).or..not.allocated(committed_mobile%concentration_mg_cm3))return
    if(.not.committed_companion%valid())return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n.or.size(water_content)/=n.or. &
       size(node_thickness_cm)/=n)return
    if(.not.all(ieee_is_finite(water_content)).or..not.all(ieee_is_finite(node_thickness_cm)))return
    if(any(water_content<=0.0_real64).or.any(node_thickness_cm<=0.0_real64))return

    call evaluate_b111_pond_solute_exchange(committed_companion%pond_mass,rain_rate,rain_c,irr_rate,irr_c, &
         qtop,macropore_area,pond_end,dt,pond)
    if(pond%status/=B111_POND_SOL_OK)return

    before=sum(committed_mobile%mass_mg_cm2)+committed_companion%solute_total()
    candidate_mobile%mass_mg_cm2(1)=candidate_mobile%mass_mg_cm2(1)+pond%soil_transfer
    candidate_companion%pond_mass=pond%mass_after
    if(candidate_mobile%mass_mg_cm2(1)<0.0_real64.or.candidate_companion%pond_mass<0.0_real64)then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=B111_POND_TRANSFER_NEGATIVE
      return
    end if
    candidate_mobile%concentration_mg_cm3=candidate_mobile%mass_mg_cm2/(water_content*node_thickness_cm)
    if(.not.all(ieee_is_finite(candidate_mobile%concentration_mg_cm3)))then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      return
    end if

    receipt%external_input=pond%rain_input+pond%irrigation_input
    receipt%internal_to_top=pond%soil_transfer
    after=sum(candidate_mobile%mass_mg_cm2)+candidate_companion%solute_total()
    expected=before+receipt%external_input
    receipt%balance_residual=after-expected
    scale=max(1.0_real64,abs(before),abs(after),abs(expected))
    tol=1024.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=B111_POND_TRANSFER_BALANCE
      return
    end if
    receipt%status=B111_POND_TRANSFER_OK
  end subroutine
end module
