program test_ppa_solute_dispersion_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_dispersion
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::q,theta,ddif,ldis,dt,expected_diff,expected_vpore,expected_disp
  real(real64)::diffusion,vpore,dispersion,nan_value
  state=20260923_int64
  do i=1,vector_count
    q=-10.0_real64+20.0_real64*next_unit(state)
    theta=0.01_real64+0.8_real64*next_unit(state)
    ddif=10.0_real64*next_unit(state)
    ldis=100.0_real64*next_unit(state)
    dt=0.001_real64+0.2_real64*next_unit(state)
    if(mod(i,4)==0)q=0.0_real64
    if(mod(i,4)==1)ldis=0.0_real64
    call source_coefficients(q,theta,ddif,ldis,dt,expected_diff,expected_vpore,expected_disp)
    call ppa_solute_dispersion_coefficient(q,theta,ddif,ldis,dt,diffusion,vpore,dispersion,status)
    call require(status==PPA_SOLUTE_DISPERSION_OK,1)
    call compare_real(expected_diff,diffusion,2)
    call compare_real(expected_vpore,vpore,3)
    call compare_real(expected_disp,dispersion,4)
  end do
  print '(A)','PPA_SOLUTE_DISPERSION_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_DIFFUSION_PORE_VELOCITY_AND_TIMESTEP_DISPERSION=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_dispersion_coefficient(1.0_real64,nan_value,0.1_real64,1.0_real64, &
       0.1_real64,diffusion,vpore,dispersion,status)
  call require(status==PPA_SOLUTE_DISPERSION_INVALID_INPUT,5)
  call ppa_solute_dispersion_coefficient(huge(1.0_real64),1.0e-300_real64,0.1_real64, &
       1.0_real64,0.1_real64,diffusion,vpore,dispersion,status)
  call require(status==PPA_SOLUTE_DISPERSION_INVALID_INPUT,6)
  print '(A)','PPA_SOLUTE_DISPERSION_INVALID_DOMAIN_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state)result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_coefficients(qin,theta_v,dd,ld,step,diff,vp,disp)
    real(real64),intent(in)::qin,theta_v,dd,ld,step
    real(real64),intent(out)::diff,vp,disp
    real(real64)::vp2,disp1
    diff=dd*theta_v**2.33_real64
    vp=abs(qin)/theta_v
    vp2=vp*vp
    disp1=diff+ld*vp
    disp=disp1+0.5_real64*step*vp2
  end subroutine source_coefficients
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
    write(*,'(A,I0)')'PPA_SOLUTE_DISPERSION_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_dispersion_source_oracle
