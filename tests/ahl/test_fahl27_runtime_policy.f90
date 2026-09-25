program test_fahl27_runtime_policy
  use mod_b110_adaptive_runtime_policy, only: b110_adaptive_runtime_eligible
  implicit none

  call require(eligible(5,0,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'qualified mode5 reference route')
  call require(.not.eligible(2,0,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'prescribed qbot fallback')
  call require(.not.eligible(7,0,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'free drainage fallback')
  call require(.not.eligible(-2,0,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'negative free drainage fallback')
  call require(.not.eligible(5,1,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'SWKIMPL1 fallback')
  call require(.not.eligible(5,0,.true.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'macropore fallback')
  call require(.not.eligible(5,0,.false.,.true.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'hysteresis fallback')
  call require(.not.eligible(5,0,.false.,.false.,.true.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'existing table fallback')
  call require(.not.eligible(5,0,.false.,.false.,.false.,.true.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.), &
       'KSATEXM fallback')
  call require(.not.eligible(5,0,.false.,.false.,.false.,.false.,.false.,.false.,.true.,.false.,.false.,.false.,.false.,.false.), &
       'root extraction fallback')
  call require(.not.eligible(5,0,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.false.,.true.,.false.), &
       'drainage response fallback')
  call require(.not.b110_adaptive_runtime_eligible(5,0,0,.false.,.false.,.false.,.false.,.false.,.false.,.false., &
       .false.,.false.,.false.,.false.,.false.,.false.,.false.), 'non-reference solver fallback')

  write(*,'(A)') 'FAHL27_RUNTIME_POLICY=PASS'

contains

  logical function eligible(mode,swk,macro,hyst,tab,ksatx,elas,frost,root,snow,temp,black,drain,weir) result(ok)
    integer,intent(in)::mode,swk
    logical,intent(in)::macro,hyst,tab,ksatx,elas,frost,root,snow,temp,black,drain,weir
    ok=b110_adaptive_runtime_eligible(mode,swk,0,.true.,macro,hyst,tab,ksatx,elas,frost,root,snow,temp,black, &
         .false.,drain,weir)
  end function eligible

  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok)then
      write(*,'(A,1X,A)') 'FAHL27_POLICY_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fahl27_runtime_policy
