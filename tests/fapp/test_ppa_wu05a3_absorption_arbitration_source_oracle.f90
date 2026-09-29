program test_ppa_wu05a3_absorption_arbitration_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_absorption_arbitration
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: sorp,darc,sorp_factor,reduction,dt,expected_out,expected_sorp,expected_darc
  real(real64) :: actual_out,actual_sorp,actual_darc
  integer(int64) :: state
  integer :: i,status
  logical :: expected_selected,expected_continues,actual_selected,actual_continues

  state=20260923_int64
  do i=1,vector_count
    sorp=10.0_real64*next_unit(state)
    darc=10.0_real64*next_unit(state)
    sorp_factor=next_unit(state)
    reduction=next_unit(state)
    dt=0.01_real64+next_unit(state)
    if(modulo(i,4)==0)sorp=sorp_factor*darc
    if(modulo(i,4)==1)sorp=sorp_factor*darc+1.0e-12_real64
    call source_arbitrate(sorp,darc,sorp_factor,reduction,dt,expected_out,expected_sorp,expected_darc, &
         expected_selected,expected_continues)
    call ppa_wu05a3_absorption_arbitrate(sorp,darc,sorp_factor,reduction,dt,actual_out,actual_sorp, &
         actual_darc,actual_selected,actual_continues,status)
    call require(status==PPA_WU05A3_ABSORPTION_ARBITRATION_OK,1)
    call compare_real(expected_out,actual_out,2)
    call compare_real(expected_sorp,actual_sorp,3)
    call compare_real(expected_darc,actual_darc,4)
    call require(expected_selected.eqv.actual_selected,5)
    call require(expected_continues.eqv.actual_continues,6)
  end do

  print '(A)','PPA_WU05A3_ABSORPTION_ARBITRATION_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SORPTIVITY_STRICT_GREATER_SELECTION_AND_EQUAL_DARCY_ROUTE=PASS'
  print '(A)','PPA_WU05A3_SORPTIVITY_RESIDUAL_EVENT_THRESHOLD=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_arbitrate(abs_sorp,abs_darc,sorp_fac,fr_reduce,delta_t,outflow,sorp_left,darc_left, &
       selected,continues)
    real(real64),intent(in)::abs_sorp,abs_darc,sorp_fac,fr_reduce,delta_t
    real(real64),intent(out)::outflow,sorp_left,darc_left
    logical,intent(out)::selected,continues
    if(abs_sorp>sorp_fac*abs_darc)then
      outflow=fr_reduce*abs_sorp
      sorp_left=abs_sorp
      darc_left=0.0_real64
      selected=.true.
    else
      outflow=fr_reduce*sorp_fac*abs_darc
      sorp_left=0.0_real64
      darc_left=abs_darc
      selected=.false.
    end if
    continues=sorp_left/delta_t>1.0e-7_real64
  end subroutine source_arbitrate

  subroutine compare_real(expected,actual,code)
    real(real64),intent(in)::expected,actual
    integer,intent(in)::code
    integer(int64)::eb,ab
    eb=transfer(expected,eb);ab=transfer(actual,ab)
    call require(eb==ab,code)
  end subroutine compare_real

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_ABSORPTION_ARBITRATION_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_absorption_arbitration_source_oracle
