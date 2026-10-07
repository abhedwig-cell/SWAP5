module mod_fmr_b111_soil_n_amendment_group
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state, only: soil_n_receipt_t,soil_n_transfer_t
  use mod_b111_soil_n_addition, only: b111_soil_n_split_parameters_t
  use mod_b111_soil_n_amendment_group, only: b111_amendment_group_t,b111_amendment_group_receipt_t, &
       build_b111_due_amendment_group,B111_AMEND_GROUP_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, &
       apply_fmr_b111_soil_n_management_event,FMR_SOIL_N_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_AMEND_OK=0
  integer,parameter,public::FMR_B111_AMEND_INVALID=1
  integer,parameter,public::FMR_B111_AMEND_BUILD_FAILED=2
  integer,parameter,public::FMR_B111_AMEND_APPLY_FAILED=3

  type,public::fmr_b111_amendment_receipt_t
    integer::status=FMR_B111_AMEND_INVALID
    type(b111_amendment_group_receipt_t)::group
    type(soil_n_receipt_t)::owner
  end type

  public::prepare_fmr_b111_amendment_candidate

contains

  subroutine prepare_fmr_b111_amendment_candidate(committed,group,current_time,depth_m,split,candidate,receipt)
    type(fmr_b111_soil_n_state_t),intent(in)::committed
    type(b111_amendment_group_t),intent(in)::group
    real(real64),intent(in)::current_time,depth_m
    type(b111_soil_n_split_parameters_t),intent(in)::split
    type(fmr_b111_soil_n_state_t),intent(out)::candidate
    type(fmr_b111_amendment_receipt_t),intent(out)::receipt
    type(soil_n_transfer_t)::transfer
    integer::status

    candidate=committed
    receipt=fmr_b111_amendment_receipt_t()
    call build_b111_due_amendment_group(group,current_time,depth_m,split,transfer,receipt%group)
    if(receipt%group%status/=B111_AMEND_GROUP_OK)then
      receipt%status=FMR_B111_AMEND_BUILD_FAILED
      return
    end if
    call apply_fmr_b111_soil_n_management_event(committed,group%event_id,transfer,candidate,status,receipt%owner)
    if(status/=FMR_SOIL_N_OK)then
      candidate=committed
      receipt%status=FMR_B111_AMEND_APPLY_FAILED
      return
    end if
    receipt%status=FMR_B111_AMEND_OK
  end subroutine
end module
