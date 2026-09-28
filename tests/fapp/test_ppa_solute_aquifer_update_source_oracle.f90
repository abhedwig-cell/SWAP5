program test_ppa_solute_aquifer_update_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_aquifer_update
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,swbr,status
  real(real64)::dt,satporos,daquif,qdrtot,isqdra,decsat,cdrain,cseep,sqsur
  real(real64)::source_cdrain,source_cseep,source_sqsur,actual_cdrain,actual_cseep,actual_sqsur,nan_value

  state=2026092302_int64
  do i=1,vector_count
    dt=1.0e-6_real64+0.25_real64*next_unit(state)
    satporos=0.01_real64+0.99_real64*next_unit(state)
    daquif=0.1_real64+50.0_real64*next_unit(state)
    select case(mod(i,4))
    case(0)
      qdrtot=0.0_real64
    case(1,2)
      qdrtot=2.0_real64*next_unit(state)
    case default
      qdrtot=-2.0_real64*next_unit(state)
    end select
    isqdra=100.0_real64*next_unit(state)
    decsat=0.1_real64*next_unit(state)
    cdrain=10.0_real64*next_unit(state)
    cseep=10.0_real64*next_unit(state)
    sqsur=100.0_real64*next_unit(state)
    swbr=mod(i,2)
    source_cdrain=cdrain
    source_cseep=cseep
    source_sqsur=sqsur
    if(swbr==1)then
      if(qdrtot>0.0_real64)then
        source_cdrain=cdrain+dt/satporos * ((isqdra-qdrtot*cdrain)/daquif-decsat*cdrain*satporos)
      else
        source_cdrain=cdrain+dt/satporos * (isqdra/daquif-decsat*cdrain*satporos)
      end if
      source_cseep=source_cdrain
      source_sqsur=sqsur+qdrtot*source_cdrain*dt
    end if
    call ppa_solute_aquifer_update(swbr,dt,satporos,daquif,qdrtot,isqdra,decsat,cdrain,cseep,sqsur, &
         actual_cdrain,actual_cseep,actual_sqsur,status)
    call require(status==PPA_SOLUTE_AQUIFER_UPDATE_OK,1)
    call compare_real(source_cdrain,actual_cdrain,2)
    call compare_real(source_cseep,actual_cseep,3)
    call compare_real(source_sqsur,actual_sqsur,4)
  end do
  print '(A)','PPA_SOLUTE_AQUIFER_UPDATE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_AQUIFER_UPDATE_POSITIVE_ZERO_NEGATIVE_DRAIN=PASS'
  print '(A)','PPA_SOLUTE_AQUIFER_UPDATE_SWBR_GATE_AND_UPDATED_SEEP_CONCENTRATION=PASS'
  print '(A)','PPA_SOLUTE_AQUIFER_SURFACE_MASS_USES_UPDATED_CONCENTRATION=PASS'

  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_aquifer_update(1,1.0_real64,1.0_real64,1.0_real64,0.0_real64,0.0_real64, &
       0.0_real64,nan_value,0.0_real64,0.0_real64,actual_cdrain,actual_cseep,actual_sqsur,status)
  call require(status==PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT,5)
  call ppa_solute_aquifer_update(1,1.0_real64,1.0_real64,1.0_real64,0.0_real64,0.0_real64, &
       -1.0_real64,1.0_real64,0.0_real64,0.0_real64,actual_cdrain,actual_cseep,actual_sqsur,status)
  call require(status==PPA_SOLUTE_AQUIFER_UPDATE_INVALID_INPUT,6)
  print '(A)','PPA_SOLUTE_AQUIFER_UPDATE_INVALID_DOMAIN_FAIL_CLOSED=PASS'
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
    write(*,'(A,I0)')'PPA_SOLUTE_AQUIFER_UPDATE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_aquifer_update_source_oracle
