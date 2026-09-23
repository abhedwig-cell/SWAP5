program test_ppa_wu05a3_absorption_derivative_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_absorption_derivative
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: qout,alpha,reference,theta,moiscap,thetas,delh,df_in,expected,actual
  integer(int64) :: state,eb,ab
  integer :: i,status
  logical :: in_zone,is_sorption,swabs_sorption

  state=20260923_int64
  do i=1,vector_count
    qout=2.0_real64*next_unit(state)
    alpha=0.2_real64+2.0_real64*next_unit(state)
    theta=0.1_real64+0.3_real64*next_unit(state)
    thetas=theta+0.01_real64+0.5_real64*next_unit(state)
    reference=theta+0.01_real64+0.5_real64*next_unit(state)
    moiscap=10.0_real64*next_unit(state)
    delh=-2.0_real64+4.0_real64*next_unit(state)
    df_in=-3.0_real64+6.0_real64*next_unit(state)
    in_zone=modulo(i,8)/=0
    is_sorption=modulo(i,3)==0
    swabs_sorption=modulo(i,2)==0
    select case(modulo(i,7))
    case(1)
      is_sorption=.true.;swabs_sorption=.true.;qout=1.0e-6_real64
    case(2)
      is_sorption=.true.;swabs_sorption=.false.;qout=1.0e-6_real64
    case(3)
      is_sorption=.false.;delh=0.5e-14_real64;qout=1.0e-6_real64
    case(4)
      is_sorption=.false.;delh=1.0e-14_real64;qout=1.0e-6_real64
    case(5)
      qout=1.0e-7_real64
    case(6)
      in_zone=.false.;qout=1.0001e-7_real64
    end select
    call source_derivative(in_zone,qout,is_sorption,swabs_sorption,alpha,reference,theta,moiscap,thetas, &
         delh,df_in,expected)
    call ppa_wu05a3_absorption_derivative(in_zone,qout,is_sorption,swabs_sorption,alpha,reference,theta, &
         moiscap,thetas,delh,df_in,actual,status)
    call require(status==PPA_WU05A3_ABSORPTION_DERIVATIVE_OK,1)
    eb=transfer(expected,eb);ab=transfer(actual,ab)
    call require(eb==ab,2)
  end do

  print '(A)','PPA_WU05A3_ABSORPTION_DERIVATIVE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DERIVATIVE_SORPTIVITY_AND_DIFFUSION_BRANCHES=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DERIVATIVE_STRICT_FLUX_AND_HEAD_THRESHOLDS=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_derivative(active,q,sorption,swabs_sorp,alfa,ref,t,capacity,ts,headdiff,initial,result)
    logical,intent(in)::active,sorption,swabs_sorp
    real(real64),intent(in)::q,alfa,ref,t,capacity,ts,headdiff,initial
    real(real64),intent(out)::result
    real(real64)::term
    result=initial
    if(active.and.q>1.0e-7_real64)then
      if(sorption)then
        if(swabs_sorp)then
          term=-q*alfa/(ref-t)
          term=term*capacity
        else
          term=-q*capacity/(ts-t)
        end if
      else
        term=0.0_real64
        if(abs(headdiff)>1.0e-14_real64)term=-q/headdiff
      end if
      result=result+term
    end if
  end subroutine source_derivative

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_ABSORPTION_DERIVATIVE_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_absorption_derivative_source_oracle
