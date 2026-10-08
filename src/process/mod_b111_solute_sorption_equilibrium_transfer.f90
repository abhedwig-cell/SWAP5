module mod_b111_solute_sorption_equilibrium_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_solute_sorption, only: b111_sorption_result_t, b111_sorption_partition_total, B111_SORP_OK
  implicit none
  private

  integer,parameter,public::B111_SORP_TRANSFER_OK=0
  integer,parameter,public::B111_SORP_TRANSFER_INVALID=1
  integer,parameter,public::B111_SORP_TRANSFER_PARTITION=2
  integer,parameter,public::B111_SORP_TRANSFER_BALANCE=3

  type,public::b111_sorption_equilibrium_receipt_t
    integer::status=B111_SORP_TRANSFER_INVALID
    real(real64)::mass_before=0.0_real64
    real(real64)::mass_after=0.0_real64
    real(real64)::balance_residual=0.0_real64
  end type

  public::apply_b111_sorption_equilibrium

contains

  subroutine apply_b111_sorption_equilibrium(committed_mobile,committed_companion,theta,dz,bdens,kf,cref,frexp, &
       candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::theta(:),dz(:),bdens(:),kf(:),cref,frexp
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_sorption_equilibrium_receipt_t),intent(out)::receipt
    type(b111_sorption_result_t)::partition
    real(real64)::total_density,scale,tol
    integer::i,n

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_sorption_equilibrium_receipt_t()
    if(.not.allocated(committed_mobile%mass_mg_cm2).or..not.allocated(committed_mobile%concentration_mg_cm3))return
    if(.not.committed_companion%valid())return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n.or.size(committed_companion%sorbed_matrix_mass)/=n)return
    if(size(theta)/=n.or.size(dz)/=n.or.size(bdens)/=n.or.size(kf)/=n)return
    if(.not.all(ieee_is_finite(theta)).or..not.all(ieee_is_finite(dz)).or. &
       .not.all(ieee_is_finite(bdens)).or..not.all(ieee_is_finite(kf)).or. &
       .not.all(ieee_is_finite([cref,frexp])))return
    if(any(theta<0.0_real64).or.any(dz<=0.0_real64).or.any(bdens<0.0_real64).or.any(kf<0.0_real64).or. &
       cref<=0.0_real64.or.frexp<=0.0_real64)return

    receipt%mass_before=sum(committed_mobile%mass_mg_cm2)+sum(committed_companion%sorbed_matrix_mass)
    do i=1,n
      total_density=(committed_mobile%mass_mg_cm2(i)+committed_companion%sorbed_matrix_mass(i))/dz(i)
      call b111_sorption_partition_total(theta(i),bdens(i),kf(i),cref,frexp,total_density, &
           committed_mobile%concentration_mg_cm3(i),partition)
      if(partition%status/=B111_SORP_OK)then
        candidate_mobile=committed_mobile
        candidate_companion=committed_companion
        receipt%status=B111_SORP_TRANSFER_PARTITION
        return
      end if
      candidate_mobile%mass_mg_cm2(i)=partition%dissolved_density*dz(i)
      candidate_companion%sorbed_matrix_mass(i)=partition%sorbed_density*dz(i)
      candidate_mobile%concentration_mg_cm3(i)=partition%concentration
    end do

    receipt%mass_after=sum(candidate_mobile%mass_mg_cm2)+sum(candidate_companion%sorbed_matrix_mass)
    receipt%balance_residual=receipt%mass_after-receipt%mass_before
    scale=max(1.0_real64,abs(receipt%mass_before),abs(receipt%mass_after))
    tol=2048.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=B111_SORP_TRANSFER_BALANCE
      return
    end if
    receipt%status=B111_SORP_TRANSFER_OK
  end subroutine
end module
