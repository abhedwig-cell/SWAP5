module mod_b111_solute_sorption_partition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_solute_sorption, only: b111_sorption_result_t, b111_sorption_partition_total, B111_SORP_OK
  implicit none
  private
  integer,parameter,public::B111_SORP_PARTITION_OK=0
  integer,parameter,public::B111_SORP_PARTITION_INVALID=1
  integer,parameter,public::B111_SORP_PARTITION_SOLVER=2
  integer,parameter,public::B111_SORP_PARTITION_BALANCE=3

  type,public::b111_sorption_partition_receipt_t
    integer::status=B111_SORP_PARTITION_OK
    real(real64)::combined_before=0d0
    real(real64)::combined_after=0d0
    real(real64)::balance_residual=0d0
    integer::max_iterations=0
  end type

  public::repartition_b111_solute_sorption

contains

  subroutine repartition_b111_solute_sorption(committed_mobile,committed_companion, &
       water_content,node_thickness_cm,bulk_density,kf,cref,frexp, &
       candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::water_content(:),node_thickness_cm(:),bulk_density(:),kf(:),cref(:),frexp(:)
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_sorption_partition_receipt_t),intent(out)::receipt

    type(b111_sorption_result_t)::part
    real(real64)::total_density,total_mass,scale,tol
    integer::n,i

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_sorption_partition_receipt_t()
    receipt%status=B111_SORP_PARTITION_INVALID

    if(.not.allocated(committed_mobile%mass_mg_cm2).or. &
       .not.allocated(committed_mobile%concentration_mg_cm3))return
    if(.not.committed_companion%valid())return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n)return
    if(size(committed_companion%sorbed_matrix_mass)/=n.or.size(water_content)/=n.or. &
       size(node_thickness_cm)/=n.or.size(bulk_density)/=n.or.size(kf)/=n.or.size(cref)/=n.or.size(frexp)/=n)return
    if(.not.all(ieee_is_finite(water_content)).or.any(water_content<0d0).or. &
       .not.all(ieee_is_finite(node_thickness_cm)).or.any(node_thickness_cm<=0d0).or. &
       .not.all(ieee_is_finite(bulk_density)).or.any(bulk_density<0d0).or. &
       .not.all(ieee_is_finite(kf)).or.any(kf<0d0).or. &
       .not.all(ieee_is_finite(cref)).or.any(cref<=0d0).or. &
       .not.all(ieee_is_finite(frexp)).or.any(frexp<=0d0))return

    receipt%combined_before=sum(committed_mobile%mass_mg_cm2)+sum(committed_companion%sorbed_matrix_mass)

    do i=1,n
      total_mass=committed_mobile%mass_mg_cm2(i)+committed_companion%sorbed_matrix_mass(i)
      if(total_mass<0d0.or..not.ieee_is_finite(total_mass))return
      total_density=total_mass/node_thickness_cm(i)
      call b111_sorption_partition_total(water_content(i),bulk_density(i),kf(i),cref(i),frexp(i), &
           total_density,committed_mobile%concentration_mg_cm3(i),part)
      if(part%status/=B111_SORP_OK)then
        candidate_mobile=committed_mobile
        candidate_companion=committed_companion
        receipt%status=B111_SORP_PARTITION_SOLVER
        return
      end if
      candidate_mobile%mass_mg_cm2(i)=part%dissolved_density*node_thickness_cm(i)
      candidate_companion%sorbed_matrix_mass(i)=part%sorbed_density*node_thickness_cm(i)
      candidate_mobile%concentration_mg_cm3(i)=part%concentration
      receipt%max_iterations=max(receipt%max_iterations,part%iterations)
    end do

    receipt%combined_after=sum(candidate_mobile%mass_mg_cm2)+sum(candidate_companion%sorbed_matrix_mass)
    receipt%balance_residual=receipt%combined_after-receipt%combined_before
    scale=max(1d0,abs(receipt%combined_before),abs(receipt%combined_after))
    tol=4096d0*epsilon(1d0)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate_mobile=committed_mobile
      candidate_companion=committed_companion
      receipt%status=B111_SORP_PARTITION_BALANCE
      return
    end if
    receipt%status=B111_SORP_PARTITION_OK
  end subroutine
end module
