module mod_direct_soil_age_substep
  use,intrinsic::iso_fortran_env,only:real64
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_solute_compartment_state,only:solute_compartment_state_t
  use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t, &
       b111_age_tracer_substep_receipt_t,advance_b111_age_tracer_substep,B111_AGE_SUBSTEP_OK
  implicit none
  private
  integer,parameter,public::DIRECT_AGE_OK=0,DIRECT_AGE_INVALID=1,DIRECT_AGE_TRANSPORT=2,DIRECT_AGE_BALANCE=3
  type,public::direct_soil_age_receipt_t
    integer::status=DIRECT_AGE_INVALID
    type(b111_age_tracer_substep_receipt_t)::transport
    real(real64),allocatable::direct_input_cm_day(:)
    real(real64)::total_direct_input_cm_day=0d0
    real(real64)::age_before_cm_day=0d0,age_after_cm_day=0d0
    real(real64)::balance_residual_cm_day=0d0,tolerance_cm_day=0d0
  end type
  public::advance_direct_soil_age_substep
contains
  ! Explicit transport-then-input split. The literal accepted transport provider
  ! sees committed age only; direct input participates in subsequent microsteps.
  subroutine advance_direct_soil_age_substep(committed,f,qssdi_cm_day,incoming_age_day,candidate,receipt)
    type(solute_compartment_state_t),intent(in)::committed
    type(b111_age_tracer_substep_forcing_t),intent(in)::f
    real(real64),intent(in)::qssdi_cm_day(:),incoming_age_day
    type(solute_compartment_state_t),intent(out)::candidate
    type(direct_soil_age_receipt_t),intent(out)::receipt
    type(solute_compartment_state_t)::transported
    real(real64),allocatable::amount(:)
    real(real64)::after,total
    integer::n
    candidate=committed;receipt=direct_soil_age_receipt_t()
    if(.not.committed%valid())return
    if(.not.allocated(committed%age_amount))return
    n=size(committed%age_amount)
    if(size(qssdi_cm_day)/=n.or.n<1)return
    if(.not.all(ieee_is_finite(qssdi_cm_day)))return
    if(.not.ieee_is_finite(incoming_age_day).or..not.ieee_is_finite(f%dt_day))return
    if(any(qssdi_cm_day<0d0).or.any(qssdi_cm_day>1d6))return
    if(incoming_age_day<0d0.or.incoming_age_day>1000d0.or.f%dt_day<=0d0.or.f%dt_day>1d3)return
    amount=qssdi_cm_day*incoming_age_day*f%dt_day
    total=sum(amount)
    if(.not.all(ieee_is_finite(amount)).or..not.ieee_is_finite(total))return
    call advance_b111_age_tracer_substep(committed,f,transported,receipt%transport)
    if(receipt%transport%status/=B111_AGE_SUBSTEP_OK)then
      receipt%status=DIRECT_AGE_TRANSPORT;return
    end if
    ! No arithmetic on the zero-source candidate preserves the old provider's
    ! exact endpoint, including signed zeros and every other compartment store.
    if(any(amount/=0d0))transported%age_amount=transported%age_amount+amount
    if(.not.transported%valid().or.any(transported%age_amount>1d12))return
    after=sum(transported%age_amount)
    if(.not.ieee_is_finite(after))return
    receipt%direct_input_cm_day=amount
    receipt%total_direct_input_cm_day=total
    receipt%age_before_cm_day=receipt%transport%age_before_cm_day
    receipt%age_after_cm_day=after
    receipt%balance_residual_cm_day=after-receipt%age_before_cm_day- &
       receipt%transport%production_amount_cm_day-receipt%transport%drain_input_cm_day- &
       receipt%transport%bottom_input_cm_day+receipt%transport%root_export_cm_day+ &
       receipt%transport%drain_export_cm_day+receipt%transport%bottom_export_cm_day- &
       receipt%transport%pond_to_soil_cm_day-total
    receipt%tolerance_cm_day=8192d0*epsilon(1d0)*max(1d0,abs(receipt%age_before_cm_day),abs(after), &
       total,abs(receipt%transport%production_amount_cm_day),abs(receipt%transport%drain_input_cm_day), &
       abs(receipt%transport%bottom_input_cm_day),abs(receipt%transport%root_export_cm_day), &
       abs(receipt%transport%drain_export_cm_day),abs(receipt%transport%bottom_export_cm_day), &
       abs(receipt%transport%pond_to_soil_cm_day))
    if(.not.ieee_is_finite(receipt%balance_residual_cm_day).or. &
       abs(receipt%balance_residual_cm_day)>receipt%tolerance_cm_day)then
      receipt%status=DIRECT_AGE_BALANCE;return
    end if
    candidate=transported;receipt%status=DIRECT_AGE_OK
  end subroutine
end module
