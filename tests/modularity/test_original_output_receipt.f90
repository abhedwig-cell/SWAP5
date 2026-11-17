program test_original_output_receipt
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_original_output_receipt
  implicit none
  type(output_receipt_frame_t)::a,b,old
  real(real64)::stock(6),pair(12),flow(16)
  integer::status
  stock=[1d0,0d0,0d0,0d0,0d0,0d0];pair=77d0;flow=88d0
  call begin_output_receipt(a,stock,status)
  call require(status==OUTPUT_RECEIPT_OK,'real production begin')
  call begin_output_receipt(b,2d0*stock,status)
  call observe_output_increment(a,1,.5d0,status)
  call observe_output_increment(b,1,.25d0,status)
  call observe_output_increment(a,6,.125d0,status)
  call observe_output_increment(a,9,-.0625d0,status)
  call finish_output_receipt(a,1.5d0*stock,pair,flow,status)
  call require(status==OUTPUT_RECEIPT_OK.and.all(pair==[1.5d0*stock,stock]),'actual endpoint pair cm')
  call require(flow(1)==.5d0.and.flow(6)==.125d0.and.flow(9)==-.0625d0,'actual signed increments cm')
  call require(b%active.and.b%flow_cm(1)==.25d0,'interleaved independent frame')
  call begin_output_receipt(a,stock,status)
  call require(status==OUTPUT_RECEIPT_OK.and.all(a%flow_cm==0d0),'A B A clear daily frame')
  old=a
  call observe_output_increment(a,17,1d0,status)
  call require(status==OUTPUT_RECEIPT_INVALID.and.all(a%flow_cm==old%flow_cm),'invalid slot preserves frame')
  call observe_output_increment(a,1,ieee_value(0d0,ieee_quiet_nan),status)
  call require(status==OUTPUT_RECEIPT_INVALID.and.all(a%flow_cm==old%flow_cm),'nonfinite increment preserves frame')
  stock(1)=-1d0
  call begin_output_receipt(a,stock,status)
  call require(status==OUTPUT_RECEIPT_INVALID.and.all(a%start_stock_cm==old%start_stock_cm),'invalid origin preserves frame')
  pair=77d0;flow=88d0
  call finish_output_receipt(a,stock,pair,flow,status)
  call require(status==OUTPUT_RECEIPT_INVALID.and.all(pair==77d0).and.all(flow==88d0).and.a%active,'invalid endpoint preserves output and frame')
  call observe_output_increment(a,1,huge(1d0),status)
  call require(status==OUTPUT_RECEIPT_OK,'representable maximum')
  old=a
  call observe_output_increment(a,1,huge(1d0),status)
  call require(status==OUTPUT_RECEIPT_OVERFLOW.and.all(a%flow_cm==old%flow_cm),'overflow refused before mutation')
  print *,'ORIGINAL_OUTPUT_RECEIPT_INCREMENT_UNITS_NONMUTATION_ABA=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
