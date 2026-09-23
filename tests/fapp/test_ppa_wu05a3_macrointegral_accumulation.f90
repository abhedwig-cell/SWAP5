program test_ppa_wu05a3_macrointegral_accumulation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a3_macrointegral_accumulation
  implicit none
  type(macrointegral_history) :: history,first,second,bad
  real(real64) :: top(2,2),rates(5,2,3),rapid(3),wet(2,3)
  integer :: status,g
  allocate(history%cell(5,2,3),history%exchange(2,3),history%rapid(3),history%wet(2,3))
  history%cell=1.0_real64; history%exchange=9.0_real64
  history%rapid=2.0_real64; history%wet=3.0_real64
  history%top=4.0_real64; history%cumulative_top=5.0_real64
  history%cumulative_cell=6.0_real64
  history%rapid_total=7.0_real64; history%cumulative_rapid=8.0_real64
  top=2.0_real64; rapid=[100.0_real64,0.25_real64,0.75_real64]; wet=0.5_real64
  rates(:,:,1)=100.0_real64
  do g=1,2
    rates(:,g,2)=[1.0_real64,2.0_real64,4.0_real64,8.0_real64,16.0_real64]
    rates(:,g,3)=2.0_real64*rates(:,g,2)
  end do
  call accumulate_macrointegral(3,3,0.5_real64,top,rates,rapid,wet,history,first,status)
  call require(status==0,1)
  call require(maxval(abs(first%cell(:,:,1)-1.0_real64))<1.0e-14_real64,2)
  call require(maxval(abs(first%exchange(:,1)-9.0_real64))<1.0e-14_real64,3)
  call require(maxval(abs(first%exchange(:,2)-4.5_real64))<1.0e-14_real64,4)
  call require(maxval(abs(first%exchange(:,3)-9.0_real64))<1.0e-14_real64,5)
  call require(maxval(abs(first%cell(MP_TOP,:,2)-9.0_real64))<1.0e-14_real64,6)
  call require(maxval(abs(first%top-5.0_real64))+ &
      maxval(abs(first%cumulative_top-6.0_real64))<1.0e-14_real64,7)
  call require(maxval(abs(first%cumulative_cell(:,1)- &
      [7.5_real64,9.0_real64,12.0_real64,18.0_real64]))<1.0e-14_real64,8)
  call require(abs(first%rapid_total-7.5_real64)+abs(first%cumulative_rapid-8.5_real64)<1.0e-14_real64,9)
  call require(maxval(abs(first%rapid-[2.0_real64,2.125_real64,2.375_real64]))<1.0e-14_real64,10)
  call require(maxval(abs(first%wet(:,2:3)-3.25_real64))<1.0e-14_real64,11)
  call accumulate_macrointegral(3,3,0.5_real64,top,rates,rapid,wet,first,second,status)
  call require(status==0,12)
  call require(abs(second%rapid_total-8.0_real64)+abs(second%cumulative_rapid-9.0_real64)<1.0e-14_real64,13)
  call require(maxval(abs(second%cumulative_cell(:,2)- &
      [9.0_real64,12.0_real64,18.0_real64,30.0_real64]))<1.0e-14_real64,14)
  call require(maxval(abs(history%cell-1.0_real64))+maxval(abs(history%rapid-2.0_real64))<1.0e-14_real64,15)
  call accumulate_macrointegral(3,3,0.0_real64,top,rates,rapid,wet,history,bad,status)
  call require(status==1 .and. .not.allocated(bad%cell),16)
  call accumulate_macrointegral(3,3,0.5_real64,top,rates(:,:,1:2),rapid,wet,history,bad,status)
  call require(status==1 .and. .not.allocated(bad%cell),17)
  print '(A)','PPA_WU05A3_MACROINTEGRAL_ACCUMULATION=PASS'
  print '(A)','PPA_WU05A3_MACROINTEGRAL_EXCHANGE_SIGNS=PASS'
  print '(A)','PPA_WU05A3_MACROINTEGRAL_HISTORY_ISOLATION=PASS'
  print '(A)','PPA_WU05A3_MACROINTEGRAL_INVALID_INPUT=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'MACROINTEGRAL_FAIL',code
      error stop 1
    end if
  end subroutine
end program
