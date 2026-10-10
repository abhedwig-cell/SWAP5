program test_b111_nfixation_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_nfixation_policy
  implicit none
  type(b111_nfixation_result_t) :: r

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
