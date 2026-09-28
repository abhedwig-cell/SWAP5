program test_ppa_solute_root_uptake_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_root_uptake
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::tscf,qrot,cml,dz,dt,expected_rate,expected_amount,rate,amount,nan_value
  state=20260923_int64
  do i=1,vector_count
    tscf=10.0_real64*next_unit(state)
    qrot=5.0_real64*next_unit(state)
    cml=100.0_real64*next_unit(state)
    dz=0.01_real64+10.0_real64*next_unit(state)
    dt=0.001_real64+0.2_real64*next_unit(state)
    if(mod(i,4)==0)qrot=0.0_real64
    expected_rate=tscf*qrot*cml/dz
    expected_amount=tscf*qrot*cml*dt
    call ppa_solute_root_uptake(tscf,qrot,cml,dz,dt,rate,amount,status)
    call require(status==PPA_SOLUTE_ROOT_UPTAKE_OK,1)
    call compare_real(expected_rate,rate,2)
    call compare_real(expected_amount,amount,3)
  end do
  print '(A)','PPA_SOLUTE_ROOT_UPTAKE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_ROOT_UPTAKE_RATE_AND_AMOUNT_COMPOSITION=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_root_uptake(nan_value,1.0_real64,1.0_real64,1.0_real64,0.1_real64,rate,amount,status)
  call require(status==PPA_SOLUTE_ROOT_UPTAKE_INVALID_INPUT,4)
  call ppa_solute_root_uptake(10.0_real64,huge(1.0_real64),100.0_real64,1.0_real64, &
       0.1_real64,rate,amount,status)
  call require(status==PPA_SOLUTE_ROOT_UPTAKE_INVALID_INPUT,5)
  print '(A)','PPA_SOLUTE_ROOT_UPTAKE_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state)result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
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
    write(*,'(A,I0)')'PPA_SOLUTE_ROOT_UPTAKE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_root_uptake_source_oracle
