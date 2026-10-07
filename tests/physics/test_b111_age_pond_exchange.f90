program test_b111_age_pond_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_age_pond_exchange
  implicit none
  type(b111_age_pond_result_t)::r
  real(real64)::available

  available=1.0_real64+0.1_real64*2.0_real64+0.05_real64*4.0_real64
  call evaluate_b111_age_pond_exchange(1.0_real64,0.1_real64,2.0_real64,0.05_real64,4.0_real64, &
       -0.2_real64,0.0_real64,0.3_real64,1.0_real64,r)
  call check(r%status==B111_AGE_POND_OK,'pond age exchange')
  call near(r%pond_age_concentration,available/0.5_real64,'pond age concentration')
  call near(r%soil_age_transfer,0.2_real64*r%pond_age_concentration,'soil age transfer')
  call near(r%pond_age_amount_after,available-r%soil_age_transfer,'pond residual age')
  call near(r%pond_age_amount_after+r%soil_age_transfer,available,'surface age balance')

  call evaluate_b111_age_pond_exchange(0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
       0.0_real64,0.0_real64,0.0_real64,1.0_real64,r)
  call check(r%status==B111_AGE_POND_OK,'literal non-infiltration branch')
  call near(r%pond_age_concentration,0.0_real64,'non-infiltration Agepond reset')
  print '(A)','B111_AGE_POND_EXCHANGE_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
