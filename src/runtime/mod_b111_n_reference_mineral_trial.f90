! Candidate staging only: a validated accepted Reference receipt drives the
! mineral N owner, with net hydraulic water and gross chemical rain separate.
module mod_b111_n_reference_mineral_trial
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_b111_n_gross_direct_binding,only:direct_gross_n_rate_from_reference,N_DIRECT_OK
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,mineral_receipt_t, &
   advance_mineral_day,MINERAL_OK
 implicit none
 private
 integer,parameter,public::N_TRIAL_OK=0,N_TRIAL_REJECT=1
 public::trial_mineral_from_reference_gross,trial_mineral_gross_days
contains
 subroutine trial_mineral_from_reference_gross(committed,t,water_end,outflow,in_bottom, &
      in_lateral,root_water,candidate,receipt,status)
  type(mineral_state_t),intent(in)::committed
  type(fmr_water_flux_substep_trace_t),intent(in)::t
  real(real64),intent(in)::water_end,outflow,in_bottom,in_lateral,root_water
  type(mineral_state_t),intent(out)::candidate
  type(mineral_receipt_t),intent(out)::receipt
  integer,intent(out)::status
  real(real64)::gross,net
  integer::code
  candidate=committed
  receipt=mineral_receipt_t()
  status=N_TRIAL_REJECT
  if(.not.all(ieee_is_finite([water_end,outflow,in_bottom,in_lateral,root_water])))return
  call direct_gross_n_rate_from_reference(t,gross,code)
  if(code/=N_DIRECT_OK)return
  ! Reference qtop uses upward-positive cm/day. N owner expects
  ! downward-positive signed m/day and alone owns its hard water closure.
  net=-0.01d0*t%top_flux
  call advance_mineral_day(candidate,t%t0,t%t1,water_end,outflow, &
      in_bottom,in_lateral,root_water,receipt,surface_water=net, &
      gross_surface_n_carrier=gross)
  if(receipt%status/=MINERAL_OK)then
    candidate=committed
    return
  end if
  status=N_TRIAL_OK
 end subroutine
 subroutine trial_mineral_gross_days(committed,steps,water_end,outflow,in_bottom, &
      in_lateral,root_water,candidate,receipts,status)
  type(mineral_state_t),intent(in)::committed
  type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
  real(real64),intent(in)::water_end(:),outflow(:),in_bottom(:),in_lateral(:),root_water(:)
  type(mineral_state_t),intent(out)::candidate
  type(mineral_receipt_t),allocatable,intent(out)::receipts(:)
  integer,intent(out)::status
  type(mineral_state_t)::trial,next
  integer::i,code,n
  candidate=committed
  status=N_TRIAL_REJECT
  n=size(steps)
  if(n<1.or.n>3660)return
  if(any([size(water_end),size(outflow),size(in_bottom), &
      size(in_lateral),size(root_water)]/=n))return
  allocate(receipts(n))
  trial=committed
  do i=1,n
    call trial_mineral_from_reference_gross(trial,steps(i),water_end(i),outflow(i), &
         in_bottom(i),in_lateral(i),root_water(i),next,receipts(i),code)
    if(code/=N_TRIAL_OK)return
    trial=next
  end do
  candidate=trial
  status=N_TRIAL_OK
 end subroutine
end module
