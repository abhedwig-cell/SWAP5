program test_ppa_solute_timestep_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_timestep
  implicit none
  integer,parameter::vector_count=100000,node_count=8
  integer(int64)::state
  integer::i,j,status
  real(real64)::dz(node_count),disp(node_count),dt,dtmin,elapsed,expected,actual,nan_value
  state=20260923_int64
  do i=1,vector_count
    do j=1,node_count
      dz(j)=0.01_real64+10.0_real64*next_unit(state)
      disp(j)=100.0_real64*next_unit(state)
    end do
    dt=0.001_real64+1.0_real64*next_unit(state)
    dtmin=1.0e-8_real64+1.0e-4_real64*next_unit(state)
    elapsed=dt*0.9_real64*next_unit(state)
    select case(mod(i,4))
    case(0)
      disp(mod(i,node_count)+1)=0.0_real64
    case(1)
      dz(mod(i,node_count)+1)=1.0e-3_real64
    end select
    call source_step(dz,disp,dt,dtmin,elapsed,expected)
    call ppa_solute_timestep_candidate(dz,disp,dt,dtmin,elapsed,actual,status)
    call require(status==PPA_SOLUTE_TIMESTEP_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_SOLUTE_TIMESTEP_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_TIMESTEP_DISPERSION_FLOOR_AND_REMAINING_INTERVAL=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  dz=1.0_real64;disp=0.1_real64
  call ppa_solute_timestep_candidate(dz,disp,nan_value,1.0e-6_real64,0.0_real64,actual,status)
  call require(status==PPA_SOLUTE_TIMESTEP_INVALID_INPUT,3)
  call ppa_solute_timestep_candidate(dz,disp,1.0_real64,1.0e-6_real64,1.0_real64,actual,status)
  call require(status==PPA_SOLUTE_TIMESTEP_INVALID_INPUT,4)
  print '(A)','PPA_SOLUTE_TIMESTEP_INVALID_DOMAIN_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state)result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_step(thickness,dispersions,interval,dtmin0,elapsed0,step)
    real(real64),intent(in)::thickness(:),dispersions(:),interval,dtmin0,elapsed0
    real(real64),intent(out)::step
    real(real64)::candidate0,dummy0,dispr0
    integer::k
    step=interval
    do k=1,size(thickness)
      dispr0=max(dispersions(k),1.0e-8_real64)
      dummy0=thickness(k)*thickness(k)/(2.0_real64*dispr0)
      step=min(step,dummy0)
    end do
    candidate0=min(step,(interval-elapsed0))
    step=max(candidate0,dtmin0)
  end subroutine source_step
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
    write(*,'(A,I0)')'PPA_SOLUTE_TIMESTEP_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_timestep_source_oracle
