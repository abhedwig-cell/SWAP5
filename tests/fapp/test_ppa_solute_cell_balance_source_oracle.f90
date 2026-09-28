program test_ppa_solute_cell_balance_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_solute_cell_balance
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::old,bottom,top,dz,decomp,root,drain,dt,expected,actual,nan_value
  state=20260923_int64
  do i=1,vector_count
    old=100.0_real64*next_unit(state)
    bottom=-10.0_real64+20.0_real64*next_unit(state)
    top=-10.0_real64+20.0_real64*next_unit(state)
    dz=0.01_real64+10.0_real64*next_unit(state)
    decomp=2.0_real64*next_unit(state)
    root=-2.0_real64+4.0_real64*next_unit(state)
    drain=-2.0_real64+4.0_real64*next_unit(state)
    dt=0.001_real64+0.2_real64*next_unit(state)
    if(mod(i,4)==0)top=bottom
    if(mod(i,4)==1)root=0.0_real64
    call source_update(old,bottom,top,dz,decomp,root,drain,dt,expected)
    call ppa_solute_cell_storage_update(old,bottom,top,dz,decomp,root,drain,dt,actual,status)
    call require(status==PPA_SOLUTE_CELL_BALANCE_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_SOLUTE_CELL_STORAGE_UPDATE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_CELL_FACE_AND_SINK_COMPOSITION=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_cell_storage_update(1.0_real64,1.0_real64,0.0_real64,nan_value, &
       0.0_real64,0.0_real64,0.0_real64,0.1_real64,actual,status)
  call require(status==PPA_SOLUTE_CELL_BALANCE_INVALID_INPUT,3)
  call ppa_solute_cell_storage_update(1.0_real64,huge(1.0_real64),-huge(1.0_real64), &
       0.1_real64,0.0_real64,0.0_real64,0.0_real64,0.1_real64,actual,status)
  call require(status==PPA_SOLUTE_CELL_BALANCE_INVALID_INPUT,4)
  print '(A)','PPA_SOLUTE_CELL_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_update(previous,cb,ct,thickness,dec,uptake,drainage,step,new_value)
    real(real64),intent(in)::previous,cb,ct,thickness,dec,uptake,drainage,step
    real(real64),intent(out)::new_value
    new_value=previous+(cb-ct)/thickness+(-dec-uptake-drainage)*step
  end subroutine source_update
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
    write(*,'(A,I0)')'PPA_SOLUTE_CELL_BALANCE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_cell_balance_source_oracle
