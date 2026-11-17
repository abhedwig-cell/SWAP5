module mod_original_output_receipt
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,parameter,public::OUTPUT_RECEIPT_OK=0,OUTPUT_RECEIPT_INVALID=1,OUTPUT_RECEIPT_INACTIVE=2,OUTPUT_RECEIPT_OVERFLOW=3
  type,public::output_receipt_frame_t
    real(real64)::start_stock_cm(6)=0.0_real64
    real(real64)::flow_cm(16)=0.0_real64
    logical::active=.false.
  end type
  public::begin_output_receipt,observe_output_increment,finish_output_receipt
contains
  pure subroutine begin_output_receipt(frame,stock_cm,status)
    type(output_receipt_frame_t),intent(inout)::frame
    real(real64),intent(in)::stock_cm(6)
    integer,intent(out)::status
    status=OUTPUT_RECEIPT_INVALID
    if(.not.all(ieee_is_finite(stock_cm)))return
    if(any(stock_cm<0.0_real64))return
    status=OUTPUT_RECEIPT_INACTIVE
    if(frame%active)return
    frame%start_stock_cm=stock_cm
    frame%flow_cm=0.0_real64
    frame%active=.true.
    status=OUTPUT_RECEIPT_OK
  end subroutine

  pure subroutine observe_output_increment(frame,slot,increment_cm,status)
    type(output_receipt_frame_t),intent(inout)::frame
    integer,intent(in)::slot
    real(real64),intent(in)::increment_cm
    integer,intent(out)::status
    real(real64)::previous
    status=OUTPUT_RECEIPT_INVALID
    if(slot<1.or.slot>16)return
    if(.not.ieee_is_finite(increment_cm))return
    status=OUTPUT_RECEIPT_INACTIVE
    if(.not.frame%active)return
    previous=frame%flow_cm(slot)
    if(.not.ieee_is_finite(previous))then
      status=OUTPUT_RECEIPT_INVALID
      return
    end if
    status=OUTPUT_RECEIPT_OVERFLOW
    if(increment_cm>0.0_real64)then
      if(previous>huge(previous)-increment_cm)return
    else if(increment_cm<0.0_real64)then
      if(previous<-huge(previous)-increment_cm)return
    end if
    frame%flow_cm(slot)=previous+increment_cm
    status=OUTPUT_RECEIPT_OK
  end subroutine

  pure subroutine finish_output_receipt(frame,end_stock_cm,stock_pair_cm,flow_cm,status)
    type(output_receipt_frame_t),intent(inout)::frame
    real(real64),intent(in)::end_stock_cm(6)
    real(real64),intent(inout)::stock_pair_cm(12),flow_cm(16)
    integer,intent(out)::status
    status=OUTPUT_RECEIPT_INVALID
    if(.not.all(ieee_is_finite(end_stock_cm)))return
    if(any(end_stock_cm<0.0_real64))return
    if(.not.all(ieee_is_finite(frame%start_stock_cm)).or..not.all(ieee_is_finite(frame%flow_cm)))return
    status=OUTPUT_RECEIPT_INACTIVE
    if(.not.frame%active)return
    stock_pair_cm=[end_stock_cm,frame%start_stock_cm]
    flow_cm=frame%flow_cm
    frame%active=.false.
    status=OUTPUT_RECEIPT_OK
  end subroutine
end module
