program test_ppa_wu05a3_polygon_diameter_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05a3_polygon_diameter
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,branch,status
  real(real64)::dmax,dmin,dz,ppv,pps,mvl,mvs,z1,z,zd,expected,actual,nan_value
  state=20260923_int64
  do i=1,vector_count
    branch=mod(i-1,4)
    dmin=0.05_real64+0.2_real64*next_unit(state)
    dmax=dmin+0.1_real64+2.0_real64*next_unit(state)
    dz=0.1_real64+5.0_real64*next_unit(state)
    ppv=2.0_real64*next_unit(state);pps=0.01_real64+next_unit(state)
    mvl=3.0_real64*next_unit(state);mvs=0.01_real64+next_unit(state)
    z1=10.0_real64;zd=0.0_real64;z=-2.0_real64+14.0_real64*next_unit(state)
    select case(branch)
    case(0)
      mvs=2.0e-6_real64+next_unit(state)
    case(1)
      mvs=0.0_real64;pps=2.0e-6_real64+next_unit(state)
    case(2)
      mvs=0.0_real64;pps=0.0_real64
    case(3)
      dmax=dmin+5.0e-4_real64
    end select
    call source_diameter(dmax,dmin,dz,ppv,pps,mvl,mvs,z1,z,zd,expected)
    call ppa_wu05a3_polygon_diameter(dmax,dmin,dz,ppv,pps,mvl,mvs,z1,z,zd,actual,status)
    call require(status==PPA_WU05A3_POLYGON_DIAMETER_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_WU05A3_POLYGON_DIAMETER_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_POLYGON_DIAMETER_ALL_THREE_DENSITY_PATHS_AND_FALLBACK=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_wu05a3_polygon_diameter(nan_value,0.1_real64,1.0_real64,1.0_real64,1.0_real64, &
       1.0_real64,1.0_real64,1.0_real64,0.0_real64,0.0_real64,actual,status)
  call require(status==PPA_WU05A3_POLYGON_DIAMETER_INVALID_INPUT,3)
  call ppa_wu05a3_polygon_diameter(2.0_real64,0.1_real64,0.0_real64,1.0_real64,0.0_real64, &
       1.0_real64,1.0_real64,1.0_real64,0.0_real64,0.0_real64,actual,status)
  call require(status==PPA_WU05A3_POLYGON_DIAMETER_INVALID_INPUT,4)
  print '(A)','PPA_WU05A3_POLYGON_DIAMETER_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_diameter(dm,di,dz0,pv,ps,mv,ms,zz1,zz,zd0,out)
    real(real64),intent(in)::dm,di,dz0,pv,ps,mv,ms,zz1,zz,zd0
    real(real64),intent(out)::out
    real(real64)::mpds
    if((dm-di)>1.0e-3_real64)then
      if(ms>1.0e-6_real64)then
        mpds=mv/dz0/ms
      else if(ps>1.0e-6_real64)then
        mpds=pv/ps
      else
        mpds=max(0.0_real64,1.0_real64-((zz1-zz)/(zz1-zd0)))
      end if
      out=di+(dm-di)*(1.0_real64-mpds)
    else
      out=di
    end if
  end subroutine source_diameter
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
    write(*,'(A,I0)')'PPA_WU05A3_POLYGON_DIAMETER_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_wu05a3_polygon_diameter_source_oracle
