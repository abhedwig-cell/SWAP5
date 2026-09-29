program test_ppa_solute_lateral_drainage_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_lateral_drainage
  implicit none
  integer,parameter::vector_count=100000,max_levels=6
  integer(int64)::state
  integer::i,j,levels,status
  real(real64)::flux(max_levels),cml,cdrain,dz,dt,expected_rate,actual_rate
  real(real64)::expected_amount,actual_amount,nan_value,concentration

  state=2026092301_int64
  do i=1,vector_count
    levels=mod(i,max_levels+1)
    cml=1.0e-8_real64+500.0_real64*next_unit(state)
    cdrain=1.0e-8_real64+500.0_real64*next_unit(state)
    dz=0.01_real64+4.0_real64*next_unit(state)
    dt=1.0e-8_real64+0.5_real64*next_unit(state)
    do j=1,max_levels
      select case(mod(i+j,5))
      case(0)
        flux(j)=0.0_real64
      case(1,2)
        flux(j)=5.0_real64*next_unit(state)
      case default
        flux(j)=-5.0_real64*next_unit(state)
      end select
    end do
    expected_rate=0.0_real64
    do j=1,levels
      if(flux(j)>0.0_real64)then
        concentration=cml
      else
        concentration=cdrain
      end if
      expected_rate=expected_rate+flux(j)*concentration/dz
    end do
    expected_amount=expected_rate*dz*dt
    call ppa_solute_lateral_drainage(flux(1:levels),cml,cdrain,dz,dt,actual_rate,actual_amount,status)
    call require(status==PPA_SOLUTE_LATERAL_DRAINAGE_OK,1)
    call compare_real(expected_rate,actual_rate,2)
    call compare_real(expected_amount,actual_amount,3)
  end do
  print '(A)','PPA_SOLUTE_LATERAL_DRAINAGE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_LATERAL_DRAINAGE_SIGN_PARTITION_AND_LEVEL_ORDER=PASS'
  print '(A)','PPA_SOLUTE_LATERAL_DRAINAGE_RATE_AND_INTERVAL_AMOUNT=PASS'

  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  flux=0.0_real64
  call ppa_solute_lateral_drainage(flux,nan_value,0.0_real64,1.0_real64,1.0_real64, &
       actual_rate,actual_amount,status)
  call require(status==PPA_SOLUTE_LATERAL_DRAINAGE_INVALID_INPUT,4)
  call ppa_solute_lateral_drainage(flux,1.0_real64,0.0_real64,1.0e-13_real64,1.0_real64, &
       actual_rate,actual_amount,status)
  call require(status==PPA_SOLUTE_LATERAL_DRAINAGE_INVALID_INPUT,5)
  print '(A)','PPA_SOLUTE_LATERAL_DRAINAGE_INVALID_DOMAIN_FAIL_CLOSED=PASS'
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
    write(*,'(A,I0)')'PPA_SOLUTE_LATERAL_DRAINAGE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_lateral_drainage_source_oracle
