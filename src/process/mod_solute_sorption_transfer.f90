module mod_solute_sorption_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private
  integer, parameter, public :: SORPTION_TRANSFER_OK=0
  integer, parameter, public :: SORPTION_TRANSFER_INVALID=1
  integer, parameter, public :: SORPTION_TRANSFER_NEGATIVE=2
  integer, parameter, public :: SORPTION_TRANSFER_BALANCE=3
  type, public :: sorption_transfer_receipt_t
    integer :: status=SORPTION_TRANSFER_OK
    real(real64) :: dissolved_before=0.0_real64
    real(real64) :: dissolved_after=0.0_real64
    real(real64) :: sorbed_before=0.0_real64
    real(real64) :: sorbed_after=0.0_real64
    real(real64) :: balance_residual=0.0_real64
  end type
  public :: apply_matrix_sorption_transfer
contains
  subroutine apply_matrix_sorption_transfer(committed_mobile,committed_companion, &
      water_content,node_thickness_cm,sorbed_delta,candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::water_content(:),node_thickness_cm(:),sorbed_delta(:)
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(sorption_transfer_receipt_t),intent(out)::receipt
    integer::n
    real(real64)::scale,tol
    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=sorption_transfer_receipt_t()
    receipt%status=SORPTION_TRANSFER_INVALID
    if(.not.allocated(committed_mobile%mass_mg_cm2).or. &
       .not.allocated(committed_mobile%concentration_mg_cm3)) return
    if(.not.committed_companion%valid()) return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n) return
    if(size(committed_companion%sorbed_matrix_mass)/=n.or.size(water_content)/=n.or. &
       size(node_thickness_cm)/=n.or.size(sorbed_delta)/=n) return
    if(.not.all(ieee_is_finite(committed_mobile%mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(committed_mobile%concentration_mg_cm3)).or. &
       .not.all(ieee_is_finite(water_content)).or..not.all(ieee_is_finite(node_thickness_cm)).or. &
       .not.all(ieee_is_finite(sorbed_delta))) return
    if(any(committed_mobile%mass_mg_cm2<0.0_real64).or.any(water_content<=0.0_real64).or. &
       any(node_thickness_cm<=0.0_real64)) return
    candidate_mobile%mass_mg_cm2=committed_mobile%mass_mg_cm2-sorbed_delta
    candidate_companion%sorbed_matrix_mass=committed_companion%sorbed_matrix_mass+sorbed_delta
    if(any(candidate_mobile%mass_mg_cm2<0.0_real64).or. &
       any(candidate_companion%sorbed_matrix_mass<0.0_real64)) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SORPTION_TRANSFER_NEGATIVE
      return
    end if
    candidate_mobile%concentration_mg_cm3=candidate_mobile%mass_mg_cm2/(water_content*node_thickness_cm)
    if(.not.all(ieee_is_finite(candidate_mobile%concentration_mg_cm3))) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      return
    end if
    receipt%dissolved_before=sum(committed_mobile%mass_mg_cm2)
    receipt%dissolved_after=sum(candidate_mobile%mass_mg_cm2)
    receipt%sorbed_before=sum(committed_companion%sorbed_matrix_mass)
    receipt%sorbed_after=sum(candidate_companion%sorbed_matrix_mass)
    receipt%balance_residual=(receipt%dissolved_after+receipt%sorbed_after)- &
         (receipt%dissolved_before+receipt%sorbed_before)
    scale=max(1.0_real64,receipt%dissolved_before+receipt%sorbed_before, &
         receipt%dissolved_after+receipt%sorbed_after)
    tol=1024.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SORPTION_TRANSFER_BALANCE
      return
    end if
    receipt%status=SORPTION_TRANSFER_OK
  end subroutine
end module
