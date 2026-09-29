program test_ppa_solute_linear_inversion_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_solute_linear_inversion
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::storage,theta,adsorption,dz,frexp,expected_c,expected_store,expected_roundoff
  real(real64)::actual_c,actual_store,actual_roundoff,nan_value
  state=20260923_int64
  do i=1,vector_count
    theta=0.5_real64*next_unit(state)
    adsorption=4.0_real64*next_unit(state)
    dz=0.01_real64+10.0_real64*next_unit(state)
    frexp=0.9991_real64+0.0018_real64*next_unit(state)
    if(mod(i,3)==0)then
      storage=0.999e-15_real64*next_unit(state)
    else
      storage=100.0_real64*next_unit(state)
    end if
    call source_invert(storage,theta,adsorption,dz,expected_c,expected_store,expected_roundoff)
    call ppa_solute_linear_storage_to_concentration(storage,theta,adsorption,dz,frexp, &
         actual_c,actual_store,actual_roundoff,status)
    call require(status==PPA_SOLUTE_LINEAR_INVERSION_OK,1)
    call compare_real(expected_c,actual_c,2)
    call compare_real(expected_store,actual_store,3)
    call compare_real(expected_roundoff,actual_roundoff,4)
  end do
  print '(A)','PPA_SOLUTE_LINEAR_STORAGE_INVERSION_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_VSMALL_ROUNDOFF_AND_LINEAR_ADSORPTION_BRANCH=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_linear_storage_to_concentration(nan_value,0.2_real64,0.1_real64,1.0_real64, &
       1.0_real64,actual_c,actual_store,actual_roundoff,status)
  call require(status==PPA_SOLUTE_LINEAR_INVERSION_INVALID_INPUT,5)
  call ppa_solute_linear_storage_to_concentration(1.0_real64,0.2_real64,0.1_real64,1.0_real64, &
       0.998_real64,actual_c,actual_store,actual_roundoff,status)
  call require(status==PPA_SOLUTE_LINEAR_INVERSION_UNSUPPORTED,6)
  call ppa_solute_linear_storage_to_concentration(1.0_real64,0.0_real64,0.0_real64,1.0_real64, &
       1.0_real64,actual_c,actual_store,actual_roundoff,status)
  call require(status==PPA_SOLUTE_LINEAR_INVERSION_INVALID_INPUT,7)
  print '(A)','PPA_SOLUTE_LINEAR_INVERSION_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_invert(value,water,ads,thickness,cml,cmsy,rounderr)
    real(real64),intent(in)::value,water,ads,thickness
    real(real64),intent(out)::cml,cmsy,rounderr
    if(value<1.0e-15_real64)then
      rounderr=value*thickness
      cmsy=0.0_real64
      cml=0.0_real64
    else
      cml=value/(water+ads)
      cmsy=value
      rounderr=0.0_real64
    end if
  end subroutine source_invert
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
    write(*,'(A,I0)')'PPA_SOLUTE_LINEAR_INVERSION_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_linear_inversion_source_oracle
