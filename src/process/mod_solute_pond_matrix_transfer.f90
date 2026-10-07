module mod_solute_pond_matrix_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private
  integer,parameter,public::SOLPOND_OK=0,SOLPOND_INVALID=1,SOLPOND_OVERDRAW=2,SOLPOND_BALANCE=3
  type,public::solute_pond_matrix_receipt_t
    integer::status=SOLPOND_OK
    real(real64)::transferred_mass=0d0
    real(real64)::combined_before=0d0
    real(real64)::combined_after=0d0
    real(real64)::balance_residual=0d0
  end type
  public::apply_pond_to_matrix_transfer
contains
  subroutine apply_pond_to_matrix_transfer(committed_mobile,committed_companion,transfer_mass, &
       water_content,node_thickness_cm,candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::transfer_mass,water_content(:),node_thickness_cm(:)
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(solute_pond_matrix_receipt_t),intent(out)::receipt
    real(real64)::scale,tol
    integer::n
    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=solute_pond_matrix_receipt_t()
    receipt%status=SOLPOND_INVALID
    if(.not.ieee_is_finite(transfer_mass).or.transfer_mass<0d0)return
    if(.not.allocated(committed_mobile%mass_mg_cm2).or..not.allocated(committed_mobile%concentration_mg_cm3))return
    if(.not.committed_companion%valid())return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n.or.size(water_content)/=n.or.size(node_thickness_cm)/=n)return
    if(.not.all(ieee_is_finite(water_content)).or.any(water_content<=0d0).or. &
       .not.all(ieee_is_finite(node_thickness_cm)).or.any(node_thickness_cm<=0d0))return
    if(transfer_mass>committed_companion%pond_mass+128d0*epsilon(1d0)*max(1d0,committed_companion%pond_mass))then
      receipt%status=SOLPOND_OVERDRAW
      return
    end if
    receipt%combined_before=sum(committed_mobile%mass_mg_cm2)+committed_companion%pond_mass
    candidate_companion%pond_mass=committed_companion%pond_mass-transfer_mass
    candidate_mobile%mass_mg_cm2(1)=committed_mobile%mass_mg_cm2(1)+transfer_mass
    candidate_mobile%concentration_mg_cm3=candidate_mobile%mass_mg_cm2/(water_content*node_thickness_cm)
    if(candidate_companion%pond_mass<0d0.or..not.all(ieee_is_finite(candidate_mobile%concentration_mg_cm3)))then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SOLPOND_OVERDRAW
      return
    end if
    receipt%transferred_mass=transfer_mass
    receipt%combined_after=sum(candidate_mobile%mass_mg_cm2)+candidate_companion%pond_mass
    receipt%balance_residual=receipt%combined_after-receipt%combined_before
    scale=max(1d0,abs(receipt%combined_before),abs(receipt%combined_after))
    tol=1024d0*epsilon(1d0)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SOLPOND_BALANCE
      return
    end if
    receipt%status=SOLPOND_OK
  end subroutine
end module
