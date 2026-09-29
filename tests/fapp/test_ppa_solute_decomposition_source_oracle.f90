program test_ppa_solute_decomposition_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_decomposition
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::decpot,tsoil,gamma,theta,rtheta,bexp,cml,ads_coeff,cref,frexp,expected,actual
  real(real64)::ftemp,ftheta,decact,nan_value
  logical::heat
  state=20260923_int64
  do i=1,vector_count
    decpot=10.0_real64*next_unit(state)
    tsoil=-10.0_real64+60.0_real64*next_unit(state)
    gamma=0.5_real64*next_unit(state)
    theta=0.6_real64*next_unit(state)
    rtheta=0.01_real64+0.39_real64*next_unit(state)
    bexp=2.0_real64*next_unit(state)
    cml=100.0_real64*next_unit(state)
    ads_coeff=5.0_real64*next_unit(state)
    cref=0.01_real64+100.0_real64*next_unit(state)
    frexp=10.0_real64*next_unit(state)
    heat=modulo(i,2)==0
    if(mod(i,5)==0)tsoil=35.0_real64
    call source_rate(decpot,heat,tsoil,gamma,theta,rtheta,bexp,cml,ads_coeff,cref,frexp,expected)
    call ppa_solute_decomposition_rate(decpot,heat,tsoil,gamma,theta,rtheta,bexp,cml,ads_coeff, &
         cref,frexp,actual,status)
    call require(status==PPA_SOLUTE_DECOMPOSITION_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_SOLUTE_DECOMPOSITION_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_DECOMPOSITION_TEMPERATURE_DRYNESS_AND_FREUNDLICH=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_decomposition_rate(1.0_real64,.true.,nan_value,0.1_real64,0.2_real64, &
       0.1_real64,1.0_real64,1.0_real64,1.0_real64,1.0_real64,1.0_real64,actual,status)
  call require(status==PPA_SOLUTE_DECOMPOSITION_INVALID_INPUT,3)
  call ppa_solute_decomposition_rate(1.0_real64,.true.,20.0_real64,0.1_real64,0.2_real64, &
       0.0_real64,1.0_real64,1.0_real64,1.0_real64,0.0_real64,1.0_real64,actual,status)
  call require(status==PPA_SOLUTE_DECOMPOSITION_INVALID_INPUT,4)
  print '(A)','PPA_SOLUTE_DECOMPOSITION_INVALID_DOMAIN_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state)result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_rate(dp,swheat,t,g,th,rth,b,c,ads,cr,fr,result)
    real(real64),intent(in)::dp,t,g,th,rth,b,c,ads,cr,fr
    logical,intent(in)::swheat
    real(real64),intent(out)::result
    if(swheat)then
      if(t<35.0_real64)then
        ftemp=exp(g*(t-20.0_real64))
      else
        ftemp=exp(g*15.0_real64)
      end if
    else
      ftemp=0.0_real64
    end if
    ftheta=min(1.0_real64,(th/rth)**b)
    decact=dp*ftemp*ftheta
    result=decact*th*c+decact*ads*((c/cr)**fr)
  end subroutine source_rate
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
    write(*,'(A,I0)')'PPA_SOLUTE_DECOMPOSITION_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_decomposition_source_oracle
