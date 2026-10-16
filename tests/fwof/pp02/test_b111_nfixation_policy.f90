program test_b111_nfixation_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use mod_b111_nfixation_policy
  implicit none
  type(b111_nfixation_result_t) :: r
  real(real64) :: values(13), base(13)
  integer :: i, kind, count
  real(real64) :: bad

  call evaluate_b111_nfixation(.5_real64,1._real64,1._real64,.2_real64, &
       .03_real64,.015_real64,.015_real64,1000._real64,800._real64,600._real64, &
       0._real64,0._real64,0._real64,r)
  call check(r%status==B111_NFIX_OK,'base status')
  call check(abs(r%vegetative_demand-51._real64)<1e-12_real64,'base demand')
  call check(abs(r%fixation-10.2_real64)<1e-12_real64,'base fixation')
  call check(abs(r%soil_demand-40.8_real64)<1e-12_real64,'base soil demand')

  call evaluate_b111_nfixation(1._real64,1._real64,1._real64,.2_real64, &
       .03_real64,.015_real64,.015_real64,1000._real64,800._real64,600._real64, &
       0._real64,0._real64,0._real64,r)
  call check(abs(r%fixation)<1e-15_real64,'strict dvs cutoff')

  call evaluate_b111_nfixation(.5_real64,1._real64,.01_real64,.2_real64, &
       .03_real64,.015_real64,.015_real64,1000._real64,800._real64,600._real64, &
       0._real64,0._real64,0._real64,r)
  call check(abs(r%fixation)<1e-15_real64,'strict moisture cutoff')

  call evaluate_b111_nfixation(.5_real64,1._real64,.0100001_real64,.2_real64, &
       .03_real64,.015_real64,.015_real64,1000._real64,800._real64,600._real64, &
       0._real64,0._real64,0._real64,r)
  call check(abs(r%fixation-10.2_real64)<1e-12_real64,'moisture just above cutoff')

  base=[.5_real64,1._real64,1._real64,.2_real64,.03_real64,.015_real64,.015_real64, &
    1000._real64,800._real64,600._real64,0._real64,0._real64,0._real64]
  count=0
  do kind=1,2
    if(kind==1)then
      bad=ieee_value(0._real64,ieee_quiet_nan)
    else
      bad=ieee_value(0._real64,ieee_positive_inf)
    end if
    do i=1,13
      values=base;values(i)=bad
      call evaluate_b111_nfixation(values(1),values(2),values(3),values(4),values(5),values(6),values(7), &
        values(8),values(9),values(10),values(11),values(12),values(13),r)
      call check(r%status==B111_NFIX_INVALID,'nonfinite input status')
      call check(abs(r%vegetative_demand)+abs(r%fixation)+abs(r%soil_demand)<tiny(1._real64),'invalid result cleared')
      count=count+1
    end do
  end do
  do i=2,13
    values=base;values(i)=-1._real64
    call evaluate_b111_nfixation(values(1),values(2),values(3),values(4),values(5),values(6),values(7), &
      values(8),values(9),values(10),values(11),values(12),values(13),r)
    call check(r%status==B111_NFIX_INVALID,'negative input rejected')
    count=count+1
  end do
  call evaluate_b111_nfixation(.5_real64,1._real64,1._real64,1.01_real64, &
    .03_real64,.015_real64,.015_real64,1000._real64,800._real64,600._real64,0._real64,0._real64,0._real64,r)
  call check(r%status==B111_NFIX_INVALID,'invalid fixation fraction')
  count=count+1
  write(*,'(A,I0)')'B111_NFIX_INVALID_CASES=',count
  print '(A)', 'B111_NFIXATION_POLICY_PASS'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine check
end program test_b111_nfixation_policy
