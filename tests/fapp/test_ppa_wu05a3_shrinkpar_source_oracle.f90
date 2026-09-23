program test_ppa_wu05a3_shrinkpar_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05a3_shrinkpar
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::theta_s,alpha,beta,gamma,expected,actual,nan_value,ratio,beta_expected,gamma_expected
  real(real64)::reference_expected,beta_actual,gamma_actual,reference_actual
  state=20260923_int64
  do i=1,vector_count
    theta_s=0.3_real64+0.65_real64*next_unit(state)
    alpha=0.15_real64+0.6_real64*next_unit(state)
    beta=0.2_real64+4.0_real64*next_unit(state)
    expected=0.01_real64+0.5_real64*min(2.0_real64,theta_s/(1.0_real64-theta_s)-0.01_real64)* &
         next_unit(state)
    gamma=1.0_real64+alpha*beta*exp(-beta*expected)
    call source_task1(theta_s,alpha,beta,gamma,actual)
    call ppa_wu05a3_clay_reference_moisture(theta_s,alpha,beta,gamma,expected,status)
    call require(status==PPA_WU05A3_SHRINKPAR_OK,1)
    call compare_real(actual,expected,2)
  end do
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK1_SOURCE_ORACLE_100000=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_wu05a3_clay_reference_moisture(nan_value,0.2_real64,1.0_real64,1.1_real64,actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_INVALID_INPUT,3)
  call ppa_wu05a3_clay_reference_moisture(0.6_real64,0.2_real64,1.0_real64,0.9_real64,actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_INVALID_INPUT,4)
  call ppa_wu05a3_clay_reference_moisture(0.6_real64,0.2_real64,1.0_real64,1.0001_real64,actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_SOURCE_ERROR,5)
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK1_FAIL_CLOSED=PASS'

  do i=1,vector_count
    theta_s=0.8_real64
    alpha=0.1_real64+0.1_real64*next_unit(state)
    ratio=1.05_real64+2.5_real64*next_unit(state)
    reference_expected=alpha*ratio
    call source_task2(alpha,reference_expected,beta_expected,gamma_expected)
    call ppa_wu05a3_clay_typical_points(theta_s,alpha,reference_expected,beta_actual,gamma_actual, &
         reference_actual,status)
    call require(status==PPA_WU05A3_SHRINKPAR_OK,6)
    call compare_real(beta_expected,beta_actual,7)
    call compare_real(gamma_expected,gamma_actual,8)
    call compare_real(reference_expected,reference_actual,9)
  end do
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK2_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK2_BOUNDED_NEWTON_CONVERGENCE=PASS'
  call ppa_wu05a3_clay_typical_points(0.8_real64,0.2_real64,0.2_real64, &
       beta_actual,gamma_actual,reference_actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_INVALID_INPUT,10)
  call ppa_wu05a3_clay_typical_points(0.6_real64,0.2_real64,2.0_real64, &
       beta_actual,gamma_actual,reference_actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_SOURCE_ERROR,11)
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK2_INVALID_AND_SOURCE_ERROR=PASS'
contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_task1(ts,a,b,c,d)
    real(real64),intent(in)::ts,a,b,c
    real(real64),intent(out)::d
    d=-log((c-1.0_real64)/(a*b))/b
    if(d>ts/(1.0_real64-ts)-0.01_real64)then
      write(*,'(A)')'unexpected source error in generated oracle vector'
      error stop 9
    end if
  end subroutine source_task1
  subroutine source_task2(a,mr,b,c)
    real(real64),intent(in)::a,mr
    real(real64),intent(out)::b,c
    real(real64)::b1,funct,deriv
    b=-log(mr/a)/mr
    b1=b+1.0_real64
    do while(abs(b-b1)>0.001_real64)
      b1=b
      funct=(a+a*mr*b1)*exp(-b1*mr)
      deriv=(-a*mr*mr*b1)*exp(-b1*mr)
      b=b1-funct/deriv
    end do
    c=1.0_real64+a*b*exp(-b*mr)
  end subroutine source_task2
  subroutine compare_real(a,b,code)
    real(real64),intent(in)::a,b
    integer,intent(in)::code
    integer(int64)::ab,bb
    ab=transfer(a,ab);bb=transfer(b,bb)
    call require(ab==bb,code)
  end subroutine compare_real
  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_SHRINKPAR_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_wu05a3_shrinkpar_source_oracle
