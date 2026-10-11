program test_fpe_elastic61_mode7_error_envelope
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_mode7_temporal_head_envelope, only: &
       fmr_mode7_head_envelope_assessment_t, assess_fmr_mode7_temporal_head_envelope, &
       FMR_MODE7_HEAD_ALPHA, FMR_MODE7_HEAD_ENVELOPE_OK, FMR_MODE7_HEAD_ENVELOPE_INVALID
  implicit none

  type(fmr_mode7_head_envelope_assessment_t) :: a
  real(real64) :: budget, threshold_bound, nanv

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  call require(transfer(FMR_MODE7_HEAD_ALPHA,0_int64) == &
       transfer(0.17320259355765216_real64,0_int64), 'A1 exact alpha')
  write(*,'(A,ES26.17E3)') 'ELASTIC61_ALPHA=',FMR_MODE7_HEAD_ALPHA
  write(*,'(A)') 'F_PE_ELASTIC61_A1_ALPHA=PASS'

  budget = 0.01_real64
  threshold_bound = budget/FMR_MODE7_HEAD_ALPHA

  call assess_fmr_mode7_temporal_head_envelope(0.5_real64*threshold_bound,budget,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_OK.and.a%complete.and.a%accepted,'A2 below')
  call require(a%estimated_head_error_cm == FMR_MODE7_HEAD_ALPHA*(0.5_real64*threshold_bound),'A2 formula')
  call require(a%normalized_error == a%estimated_head_error_cm/budget,'A2 normalized')

  call assess_fmr_mode7_temporal_head_envelope(threshold_bound,budget,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_OK.and.a%complete.and.a%accepted,'A3 equal')
  call require(abs(a%normalized_error-1.0_real64) <= 8.0_real64*epsilon(1.0_real64),'A3 equal ratio')

  call assess_fmr_mode7_temporal_head_envelope(1.01_real64*threshold_bound,budget,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_OK.and.a%complete.and..not.a%accepted,'A3 above')
  write(*,'(A)') 'F_PE_ELASTIC61_A2_FORMULA=PASS'
  write(*,'(A)') 'F_PE_ELASTIC61_A3_THRESHOLD=PASS'

  call assess_fmr_mode7_temporal_head_envelope(0.0_real64,0.0_real64,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_OK.and.a%complete.and.a%accepted,'A4 zero exact')
  call require(a%normalized_error==0.0_real64,'A4 zero ratio')
  call assess_fmr_mode7_temporal_head_envelope(1.0_real64,0.0_real64,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_OK.and.a%complete.and..not.a%accepted,'A4 zero reject')
  write(*,'(A)') 'F_PE_ELASTIC61_A4_ZERO=PASS'

  call assess_fmr_mode7_temporal_head_envelope(-1.0_real64,1.0_real64,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_INVALID.and..not.a%complete.and..not.a%accepted,'A5 neg bound')
  call assess_fmr_mode7_temporal_head_envelope(1.0_real64,-1.0_real64,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_INVALID.and..not.a%complete.and..not.a%accepted,'A5 neg budget')
  call assess_fmr_mode7_temporal_head_envelope(nanv,1.0_real64,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_INVALID.and..not.a%complete,'A5 nan bound')
  call assess_fmr_mode7_temporal_head_envelope(1.0_real64,nanv,a)
  call require(a%status==FMR_MODE7_HEAD_ENVELOPE_INVALID.and..not.a%complete,'A5 nan budget')
  write(*,'(A)') 'F_PE_ELASTIC61_A5_FAIL_CLOSED=PASS'

  write(*,'(A)') 'F_PE_ELASTIC61=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC61_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_elastic61_mode7_error_envelope
