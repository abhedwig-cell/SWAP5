module mod_ppa_wu05a3_candidate_mass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a2_macropore_state
  implicit none
  private
  type,public :: candidate_mass_account
    logical :: valid=.false.
    real(real64) :: top_input=0.0_real64,rapid_output=0.0_real64,storage_change=0.0_real64
    real(real64) :: macropore_internal=0.0_real64,matrix_internal=0.0_real64,budget_residual=0.0_real64
    real(real64),allocatable :: transfer_residual(:),domain_residual(:)
  end type
  public :: account_candidate_mass
contains
  subroutine account_candidate_mass(checkpoint,candidate,dt,top,exchange,drain,matrix_amount,tolerance,account,status)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in) :: checkpoint
    type(ppa_wu05a2_macropore_candidate_t),intent(in) :: candidate
    real(real64),intent(in) :: dt,top(:),exchange(:,:),drain(:),matrix_amount(:),tolerance
    type(candidate_mass_account),intent(out) :: account
    integer,intent(out) :: status
    integer :: nd,n
    real(real64),allocatable :: expected_matrix(:)
    status=1
    if(.not.candidate%valid .or. .not.checkpoint%payload%ready() .or. .not.candidate%payload%ready()) return
    if(checkpoint%lineage_id<=0 .or. checkpoint%revision<0) return
    if(candidate%origin_lineage_id/=checkpoint%lineage_id .or. &
        candidate%origin_revision/=checkpoint%revision) return
    nd=checkpoint%payload%n_domains; n=checkpoint%payload%n_compartments
    if(candidate%payload%n_domains/=nd .or. candidate%payload%n_compartments/=n) return
    if(size(top)/=nd .or. any(shape(exchange)/=[nd,n]) .or. size(drain)/=n .or. size(matrix_amount)/=n) return
    if(.not.ieee_is_finite(dt) .or. .not.ieee_is_finite(tolerance)) return
    if(dt<=0.0_real64 .or. tolerance<0.0_real64) return
    if(.not.all(ieee_is_finite(top)) .or. .not.all(ieee_is_finite(exchange)) .or. &
        .not.all(ieee_is_finite(drain)) .or. .not.all(ieee_is_finite(matrix_amount))) return
    if(any(drain<0.0_real64)) return
    expected_matrix=sum(exchange,dim=1)*dt
    account%transfer_residual=matrix_amount-expected_matrix
    account%top_input=sum(top)*dt
    account%rapid_output=sum(drain)*dt
    account%macropore_internal=-sum(expected_matrix)
    account%matrix_internal=sum(matrix_amount)
    account%storage_change=sum(candidate%payload%domain_water_storage-checkpoint%payload%domain_water_storage)
    account%budget_residual=account%storage_change- &
        (account%top_input-account%rapid_output+account%macropore_internal)
    account%domain_residual=candidate%payload%domain_water_storage-checkpoint%payload%domain_water_storage- &
        (top-sum(exchange,dim=2))*dt
    account%domain_residual(1)=account%domain_residual(1)+account%rapid_output
    if(.not.all(ieee_is_finite(account%transfer_residual)) .or. &
        .not.all(ieee_is_finite(account%domain_residual)) .or. &
        .not.ieee_is_finite(account%budget_residual)) return
    status=2
    if(any(abs(account%transfer_residual)>tolerance)) return
    status=3
    if(abs(account%budget_residual)>tolerance) return
    if(any(abs(account%domain_residual)>tolerance)) return
    if(any(abs(sum(candidate%payload%pore_water,dim=2)-candidate%payload%domain_water_storage)>tolerance)) return
    if(any(abs(sum(checkpoint%payload%pore_water,dim=2)-checkpoint%payload%domain_water_storage)>tolerance)) return
    account%valid=.true.
    status=0
  end subroutine
end module
