program test_cde_interval_receipt
  use iso_fortran_env,only:real64,int64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use hybrid_cde_interval_receipt
  implicit none
  real(real64) :: ledger(9),first(9),stock,flow(6),before(6),nan
  integer(int64) :: counts(6),prior_counts(6)
  integer :: status,i
  logical :: live
  nan=ieee_value(0d0,ieee_quiet_nan)
  call cde_day_observe(1,1d0,status)
  if(status/=CDE_DAY_STATE)error stop 'unframed increment accepted'
  call cde_day_begin(10d0,status)
  if(status/=CDE_DAY_OK)error stop 'begin refused'
  call cde_day_observe(1,0.5d0,status)
  call cde_day_observe(1,0.5d0,status)
  call cde_day_observe(2,0.5d0,status)
  call cde_day_observe(3,-0.25d0,status)
  do i=4,6
    call cde_day_observe(i,0.25d0,status)
  end do
  call cde_day_diagnostics(stock,before,prior_counts,live)
  if(stock/=10d0.or..not.live.or.any(prior_counts/=[2_int64,1_int64,1_int64,1_int64,1_int64,1_int64])) &
    error stop 'actual observation counts differ'
  call cde_day_begin(20d0,status)
  if(status/=CDE_DAY_STATE)error stop 'live frame replaced'
  call cde_day_begin(nan,status)
  if(status/=CDE_DAY_INPUT)error stop 'nonfinite stock accepted'
  call cde_day_observe(0,1d0,status)
  if(status/=CDE_DAY_INPUT)error stop 'zero slot accepted'
  call cde_day_observe(7,1d0,status)
  if(status/=CDE_DAY_INPUT)error stop 'foreign slot accepted'
  call cde_day_observe(1,nan,status)
  if(status/=CDE_DAY_INPUT)error stop 'nonfinite increment accepted'
  call cde_day_close(11.5d0,ledger,status)
  if(status/=CDE_DAY_BALANCE.or.any(ledger/=0d0))error stop 'mass mismatch accepted'
  call cde_day_diagnostics(stock,flow,counts,live)
  if(stock/=10d0.or..not.live.or.any(flow/=before).or.any(counts/=prior_counts))error stop 'refusal mutated receipt'
  call cde_day_close(10.5d0,first,status)
  if(status/=CDE_DAY_OK.or.any(first/=[10.5d0,0.5d0,1d0,0.5d0,-0.25d0,0.25d0,0.25d0,0.25d0,0d0])) &
    error stop 'independent actual increment balance differs'
  call cde_day_observe(1,1d0,status)
  if(status/=CDE_DAY_STATE)error stop 'closed receipt changed'
  call cde_day_close(10.5d0,ledger,status)
  if(status/=CDE_DAY_STATE)error stop 'double close accepted'
  call cde_day_begin(0d0,status)
  call cde_day_observe(2,2d0,status)
  call cde_day_close(2d0,ledger,status)
  if(status/=CDE_DAY_OK)error stop 'independent zero-stock source refused'
  call cde_day_begin(10d0,status)
  do i=1,6
    call cde_day_observe(i,before(i),status)
  end do
  call cde_day_close(10.5d0,ledger,status)
  if(status/=CDE_DAY_OK.or.any(ledger/=first))error stop 'A B A receipt differs'
  call cde_day_begin(-1d0,status)
  if(status/=CDE_DAY_INPUT)error stop 'negative stock accepted'
  call cde_day_open(7,1d0,status)
  if(status/=CDE_DAY_OK)error stop 'actual day open refused'
  call cde_day_observe(2,1d0,status)
  call cde_day_open(7,2d0,status)
  if(status/=CDE_DAY_OK)error stop 'same-day step refused'
  call cde_day_open(8,2d0,status)
  if(status/=CDE_DAY_STATE)error stop 'unclosed day replaced'
  call cde_day_close(2d0,ledger,status)
  if(status/=CDE_DAY_OK.or.ledger(2)/=1d0.or.ledger(4)/=1d0)error stop 'same-day flow reset'
  call cde_day_open(7,2d0,status)
  if(status/=CDE_DAY_STATE)error stop 'closed day reopened'
  call cde_day_open(8,2d0,status)
  if(status/=CDE_DAY_OK)error stop 'next day refused'
  call cde_day_close(2d0,ledger,status)
  if(status/=CDE_DAY_OK.or.any(ledger(2:)/=0d0))error stop 'previous day leaked'
  print '(a)','ACTUAL_CDE_INTERVAL_DAILY_RECEIPT_INTERFACE_PASS'
end program
