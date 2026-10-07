module mod_solute_decay_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private
  integer, parameter, public :: SOLDECAY_OK=0, SOLDECAY_INVALID=1
  integer, parameter, public :: SOLDECAY_OVERDRAW=2, SOLDECAY_BALANCE=3

  type, public :: solute_decay_receipt_t
    integer :: status=SOLDECAY_OK
    real(real64) :: dissolved_before=0.0_real64
    real(real64) :: sorbed_before=0.0_real64
    real(real64) :: dissolved_after=0.0_real64
    real(real64) :: sorbed_after=0.0_real64
    real(real64) :: removed_mass=0.0_real64
    real(real64) :: balance_residual=0.0_real64
  end type

  public :: apply_b111_decay_transfer

contains

  subroutine apply_b111_decay_transfer(committed_mobile, committed_companion, decay_fraction, &
       water_content, node_thickness_cm, candidate_mobile, candidate_companion, receipt)
    type(mobile_salt_state_t), intent(in) :: committed_mobile
    type(solute_compartment_state_t), intent(in) :: committed_companion
    real(real64), intent(in) :: decay_fraction(:), water_content(:), node_thickness_cm(:)
    type(mobile_salt_state_t), intent(out) :: candidate_mobile
    type(solute_compartment_state_t), intent(out) :: candidate_companion
    type(solute_decay_receipt_t), intent(out) :: receipt

    integer :: n,i
    real(real64) :: total_node,removed,dissolved_share,sorbed_share,scale,tol

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=solute_decay_receipt_t()
    receipt%status=SOLDECAY_INVALID

    if(.not.allocated(committed_mobile%mass_mg_cm2).or. &
       .not.allocated(committed_mobile%concentration_mg_cm3)) return
    if(.not.committed_companion%valid()) return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n) return
    if(size(committed_companion%sorbed_matrix_mass)/=n.or.size(decay_fraction)/=n.or. &
       size(water_content)/=n.or.size(node_thickness_cm)/=n) return
    if(.not.all(ieee_is_finite(decay_fraction)).or.any(decay_fraction<0.0_real64).or. &
       any(decay_fraction>1.0_real64)) return
    if(.not.all(ieee_is_finite(water_content)).or.any(water_content<=0.0_real64).or. &
       .not.all(ieee_is_finite(node_thickness_cm)).or.any(node_thickness_cm<=0.0_real64)) return

    receipt%dissolved_before=sum(committed_mobile%mass_mg_cm2)
    receipt%sorbed_before=sum(committed_companion%sorbed_matrix_mass)

    do i=1,n
      total_node=committed_mobile%mass_mg_cm2(i)+committed_companion%sorbed_matrix_mass(i)
      if(total_node<0.0_real64.or..not.ieee_is_finite(total_node)) return
      removed=decay_fraction(i)*total_node
      if(removed>total_node+128.0_real64*epsilon(1.0_real64)*max(1.0_real64,total_node)) then
        candidate_mobile=committed_mobile
        candidate_companion=committed_companion
        receipt%status=SOLDECAY_OVERDRAW
        return
      end if
      if(total_node>0.0_real64) then
        dissolved_share=committed_mobile%mass_mg_cm2(i)/total_node
        sorbed_share=committed_companion%sorbed_matrix_mass(i)/total_node
      else
        dissolved_share=0.0_real64
        sorbed_share=0.0_real64
      end if
      candidate_mobile%mass_mg_cm2(i)=committed_mobile%mass_mg_cm2(i)-removed*dissolved_share
      candidate_companion%sorbed_matrix_mass(i)=committed_companion%sorbed_matrix_mass(i)-removed*sorbed_share
      receipt%removed_mass=receipt%removed_mass+removed
    end do

    if(any(candidate_mobile%mass_mg_cm2<0.0_real64).or. &
       any(candidate_companion%sorbed_matrix_mass<0.0_real64)) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SOLDECAY_OVERDRAW
      return
    end if
    candidate_mobile%concentration_mg_cm3=candidate_mobile%mass_mg_cm2/(water_content*node_thickness_cm)
    if(.not.all(ieee_is_finite(candidate_mobile%concentration_mg_cm3))) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      return
    end if

    receipt%dissolved_after=sum(candidate_mobile%mass_mg_cm2)
    receipt%sorbed_after=sum(candidate_companion%sorbed_matrix_mass)
    receipt%balance_residual=(receipt%dissolved_after+receipt%sorbed_after+receipt%removed_mass)- &
         (receipt%dissolved_before+receipt%sorbed_before)
    scale=max(1.0_real64,receipt%dissolved_before+receipt%sorbed_before)
    tol=1024.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol) then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=SOLDECAY_BALANCE
      return
    end if
    receipt%status=SOLDECAY_OK
  end subroutine
end module
