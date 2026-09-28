program test_ppa_wu05a3_absorption_diffusivity_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_absorption_diffusivity
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: alpha_m,ksat,m,wcs,enpr,overm,lambda,theta,theta_r
  real(real64) :: expected,actual,lambda_expected,lambda_actual,relsat_expected,relsat_actual
  integer(int64) :: state
  integer :: i,status

  state=20260923_int64
  do i=1,vector_count
    alpha_m=0.01_real64+4.0_real64*next_unit(state)
    ksat=100.0_real64*next_unit(state)
    m=0.05_real64+0.9_real64*next_unit(state)
    wcs=0.001_real64+0.5_real64*next_unit(state)
    enpr=0.5_real64+0.49_real64*next_unit(state)
    overm=0.5_real64+5.0_real64*next_unit(state)
    lambda=-3.0_real64+4.0_real64*next_unit(state)
    theta_r=0.01_real64+0.2_real64*next_unit(state)
    theta=theta_r+wcs*(0.01_real64+1.5_real64*next_unit(state))
    call source_diffusivity(alpha_m,ksat,m,wcs,enpr,overm,lambda,theta,theta_r, &
         expected,lambda_expected,relsat_expected)
    call ppa_wu05a3_absorption_diffusivity(alpha_m,ksat,m,wcs,enpr,overm,lambda,theta,theta_r, &
         actual,lambda_actual,relsat_actual,status)
    call require(status==PPA_WU05A3_DIFFUSIVITY_OK,1)
    call compare_real(expected,actual,2)
    call compare_real(lambda_expected,lambda_actual,3)
    call compare_real(relsat_expected,relsat_actual,4)
  end do

  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSIVITY_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSIVITY_LAMBDA_FLOOR_AND_ENVELOPE_CLAMP=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSIVITY_MUALEM_TERM=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_diffusivity(alpha_m,conductivity,mpar,wcsmin,s_enpr,inv_m,lambda,water,theta_res,diff,lambda_adj,rs)
    real(real64),intent(in)::alpha_m,conductivity,mpar,wcsmin,s_enpr,inv_m,lambda,water,theta_res
    real(real64),intent(out)::diff,lambda_adj,rs
    real(real64)::help
    lambda_adj=max(lambda,-inv_m)
    rs=(water-theta_res)/wcsmin
    rs=min(rs,s_enpr)
    help=1.0_real64-rs**inv_m
    diff=(((1.0_real64-mpar)*conductivity)/(alpha_m*mpar*wcsmin))* &
         rs**(lambda_adj-inv_m)*(help**(-mpar)+help**mpar-2.0_real64)
  end subroutine source_diffusivity

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
    write(*,'(A,I0)')'PPA_WU05A3_ABSORPTION_DIFFUSIVITY_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_absorption_diffusivity_source_oracle
