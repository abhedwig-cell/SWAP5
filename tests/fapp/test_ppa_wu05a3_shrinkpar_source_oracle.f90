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
  real(real64)::void0,mois_b,mois_c,mois_d,shape_p,alpha_expected,peat_beta_expected
  real(real64)::alpha_actual,peat_beta_actual
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

  do i=1,vector_count
    theta_s=0.8_real64
    void0=0.09_real64+0.02_real64*next_unit(state)
    mois_b=1.95_real64+0.1_real64*next_unit(state)
    mois_c=0.58_real64+0.04_real64*next_unit(state)
    mois_d=0.98_real64+0.04_real64*next_unit(state)
    shape_p=-0.12_real64-0.01_real64*next_unit(state)
    call source_task4(theta_s,void0,mois_b,mois_c,mois_d,shape_p,alpha_expected,peat_beta_expected)
    call ppa_wu05a3_peat_typical_points(theta_s,void0,mois_b,mois_c,mois_d,shape_p, &
         alpha_actual,peat_beta_actual,status)
    if(status/=PPA_WU05A3_SHRINKPAR_OK)write(*,'(A,I0,6(1X,ES14.6))') &
         'TASK4_INVALID ',i,void0,mois_b,mois_c,mois_d,shape_p
    call require(status==PPA_WU05A3_SHRINKPAR_OK,12)
    call compare_real(alpha_expected,alpha_actual,13)
    call compare_real(peat_beta_expected,peat_beta_actual,14)
  end do
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK4_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK4_BOUNDED_ROOT_CONVERGENCE=PASS'
  call ppa_wu05a3_peat_typical_points(0.8_real64,0.1_real64,2.0_real64,0.6_real64, &
       1.0_real64,0.0_real64,alpha_actual,peat_beta_actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_INVALID_INPUT,15)
  call ppa_wu05a3_peat_typical_points(0.8_real64,0.1_real64,0.5_real64,0.6_real64, &
       1.0_real64,-0.12_real64,alpha_actual,peat_beta_actual,status)
  call require(status==PPA_WU05A3_SHRINKPAR_INVALID_INPUT,16)
  print '(A)','PPA_WU05A3_SHRINKPAR_TASK4_INVALID_DOMAIN_FAIL_CLOSED=PASS'
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
  subroutine source_task4(ts,e0,b,c,d,p,a_out,b_out)
    real(real64),intent(in)::ts,e0,b,c,d,p
    real(real64),intent(out)::a_out,b_out
    real(real64)::c1,c2,c3,et,er,amin,amax,a1,a2,fa,ga,ha,funct,deriv
    c1=1.0_real64/(d/b)
    c2=c/d
    et=e0+(ts/(1.0_real64-ts)-e0)*c/(ts/(1.0_real64-ts))
    if(p>0.0_real64)then
      er=e0+c
    else
      er=0.5_real64*e0+c
    end if
    c3=(er/et-1.0_real64)/p
    if(abs(p)>0.33_real64)then
      a2=0.5_real64
    else
      a2=0.9_real64
    end if
    a1=a2+1.0_real64
    amax=10.0_real64
    amin=0.001_real64
    do while(abs(a2-a1)>0.001_real64)
      a1=a2
      fa=c2**a1
      ga=exp((c1-c2)*a1)-1.0_real64
      ha=exp((c1-1.0_real64)*a1)-1.0_real64
      funct=fa*ga/ha-c3
      deriv=fa*(ga*(1.0_real64+log(c2)-c2-(c1-1.0_real64)/ha)+(c1-c2))/ha
      a2=a1-funct/deriv
      if(abs(a2-a1)>1.0e-2_real64)then
        if(a2>a1)then
          if(a1>amin .and. a1<amax-1.0e-3_real64)then
            amin=a1
          else
            a2=(amin+min(a2,amax-1.0e-2_real64))/2.0_real64
          end if
          a2=min(a2,amax)
        else if(a2<a1)then
          if(a1<amax .and. a1>amin+1.0e-3_real64)then
            amax=a1
          else
            a2=(amax+max(a2,amin+1.0e-2_real64))/2.0_real64
          end if
          a2=max(a2,amin)
        end if
      end if
    end do
    a_out=a2
    b_out=a2/(d/b)
  end subroutine source_task4
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
