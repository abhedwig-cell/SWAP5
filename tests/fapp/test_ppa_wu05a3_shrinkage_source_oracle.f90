program test_ppa_wu05a3_shrinkage_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use mod_ppa_wu05a3_shrinkage
  implicit none
  integer, parameter :: vector_count=100000
  integer(int64) :: state
  integer :: i, kind, case_kind, input_kind, status
  real(real64) :: theta_s, theta, p(5), expected, actual, nan_value, inf_value

  state=20260923_int64
  do i=1,vector_count
    theta_s=0.35_real64+0.45_real64*next_unit(state)
    case_kind=1+mod(i-1,3)
    kind=1
    input_kind=1
    p=[0.2_real64+0.2_real64*next_unit(state), 0.5_real64+next_unit(state), &
       0.05_real64+0.2_real64*next_unit(state), 0.0_real64, 0.0_real64]
    select case(case_kind)
    case(1)
      input_kind=1
      p=[0.2_real64+0.2_real64*next_unit(state), 0.5_real64+2.0_real64*next_unit(state), &
         0.2_real64*next_unit(state), 0.4_real64+1.0_real64*next_unit(state), 0.0_real64]
    case(2)
      kind=2
      input_kind=1
      p=[0.05_real64+0.1_real64*next_unit(state), 0.2_real64+0.25_real64*(theta_s/(1.0_real64-theta_s)), &
         0.4_real64, 1.5_real64, 0.15_real64]
    case(3)
      kind=2
      input_kind=3
      p=[0.05_real64+0.1_real64*next_unit(state), 0.2_real64+ &
         0.25_real64*(theta_s/(1.0_real64-theta_s)), &
         0.1_real64+0.08_real64*(theta_s/(1.0_real64-theta_s)), 0.2_real64, 0.0_real64]
    end select
    theta=theta_s*next_unit(state)
    call source_shrink(kind,input_kind,theta_s,theta,p,expected)
    call ppa_wu05a3_relative_shrinkage(kind,input_kind,theta_s,theta,p,actual,status)
    call require(status==PPA_WU05A3_SHRINKAGE_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_WU05A3_SHRINKAGE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SHRINKAGE_CLAY_PEAT_CONTINUOUS_AND_PIECEWISE=PASS'

  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  inf_value=ieee_value(0.0_real64,ieee_positive_inf)
  p=[0.2_real64,1.0_real64,0.1_real64,0.4_real64,0.0_real64]
  call ppa_wu05a3_relative_shrinkage(1,1,0.6_real64,nan_value,p,actual,status)
  call require(status==PPA_WU05A3_SHRINKAGE_INVALID_INPUT,3)
  call ppa_wu05a3_relative_shrinkage(1,1,0.6_real64,0.2_real64, &
       [0.2_real64,inf_value,0.1_real64,0.4_real64,0.0_real64],actual,status)
  call require(status==PPA_WU05A3_SHRINKAGE_INVALID_INPUT,4)
  call ppa_wu05a3_relative_shrinkage(0,1,0.6_real64,0.2_real64,p,actual,status)
  call require(status==PPA_WU05A3_SHRINKAGE_INVALID_INPUT,5)
  print '(A)','PPA_WU05A3_SHRINKAGE_NONFINITE_AND_UNDEFINED_MODE_FAIL_CLOSED=PASS'

contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_shrink(soil_kind, input_kind, ts, th, par, result)
    integer,intent(in)::soil_kind,input_kind
    real(real64),intent(in)::ts,th,par(5)
    real(real64),intent(out)::result
    real(real64)::solid,mois,moisra,moisrs,voidr,voidr0,voidrs,alfa,beta,power,moisrt,moisrp,voidrt,vrhlp
    real(real64)::moisri,mr1,mr2,vr1,vr2
    solid=1.0_real64-ts
    mois=th/solid
    if(soil_kind==1)then
      alfa=par(1);beta=par(2);moisra=par(4)
      if(mois>moisra)then
        voidr=mois
      else
        voidr=max(alfa*exp(-beta*mois)+par(3)*mois,alfa)
      end if
    else
      voidr0=par(1);moisra=par(2);moisrs=ts/solid;voidrs=moisrs
      if(input_kind/=3)then
        alfa=par(3);beta=par(4);power=par(5);moisrp=alfa/beta;moisrt=mois/moisra
        voidrt=voidr0+(voidrs-voidr0)*mois/moisrs
        vrhlp=1.0_real64+power*((moisrt**alfa)*(exp(-beta*moisrt)-exp(-beta)))/ &
             ((moisrp**alfa)*(exp(-alfa)-exp(-beta)))
        if(mois<moisra)then
          voidr=voidrt*vrhlp
        else
          voidr=voidrt
        end if
      else
        moisri=par(3)
        if(mois>moisra)then
          mr1=moisrs;mr2=moisra;vr1=voidrs;vr2=voidr0+(voidrs-voidr0)*moisra/moisrs
        else if(mois>moisri)then
          mr1=moisra;mr2=moisri;vr1=voidr0+(voidrs-voidr0)*moisra/moisrs;vr2=par(4)
        else
          mr1=moisri;mr2=0.0_real64;vr1=par(4);vr2=voidr0
        end if
        voidr=vr2+(vr1-vr2)*(mois-mr2)/(mr1-mr2)
      end if
    end if
    result=ts-voidr*solid
  end subroutine source_shrink

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
    write(*,'(A,I0)')'PPA_WU05A3_SHRINKAGE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_wu05a3_shrinkage_source_oracle
