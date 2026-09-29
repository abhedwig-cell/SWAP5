program test_ppa_wu05a3_sorptivity_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_sorptivity
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: theta_s,theta,theta_r,smax,alpha,event_time,dt,proportion,wetting,dz,dia,wall
  real(real64) :: ref_in,sorp_in,ref_expected,sorp_expected,abs_expected,ref_actual,sorp_actual,abs_actual
  integer(int64) :: state
  integer :: i,status,peak_cap_count
  logical :: apply_wall,event_expected,event_actual

  state=20260923_int64
  peak_cap_count=0
  do i=1,vector_count
    theta_s=0.5_real64
    theta_r=0.1_real64
    theta=0.1_real64+0.39_real64*next_unit(state)
    event_time=2.0_real64*next_unit(state)
    ref_in=theta+0.2_real64*next_unit(state)
    if(modulo(i,4)==0)then
      theta=theta_s-0.5e-8_real64
    else if(modulo(i,4)==1)then
      event_time=0.0_real64
    else if(modulo(i,4)==2)then
      event_time=0.1_real64+next_unit(state)
      ref_in=min(theta_s,theta+0.2_real64)
    else
      event_time=0.1_real64+next_unit(state)
      ref_in=theta
    end if
    dt=0.01_real64+0.4_real64*next_unit(state)
    smax=1.0_real64+500.0_real64*next_unit(state)
    alpha=0.2_real64+2.0_real64*next_unit(state)
    proportion=next_unit(state)
    wetting=next_unit(state)
    dz=0.1_real64+2.0_real64*next_unit(state)
    dia=0.01_real64+0.5_real64*next_unit(state)
    wall=next_unit(state)
    apply_wall=modulo(i,2)==0
    sorp_in=next_unit(state)
    if(modulo(i,100)==0)then
      theta=0.2_real64
      event_time=0.1_real64
      ref_in=0.5_real64
      dt=0.4_real64
      smax=1.0e5_real64
      alpha=1.0_real64
      proportion=1.0_real64
      wetting=1.0_real64
      dz=2.0_real64
      dia=0.01_real64
      wall=1.0_real64
      apply_wall=.true.
    end if

    call source_sorptivity(theta_s,theta,theta_r,smax,alpha,event_time,dt,proportion,wetting,dz,dia,wall, &
         apply_wall,ref_in,sorp_in,ref_expected,sorp_expected,abs_expected,event_expected)
    call ppa_wu05a3_sorptivity_absorption(theta_s,theta,theta_r,smax,alpha,event_time,dt,proportion,wetting, &
         dz,dia,wall,apply_wall,ref_in,sorp_in,ref_actual,sorp_actual,abs_actual,event_actual,status)
    call require(status==PPA_WU05A3_SORPTIVITY_OK,1)
    call compare_real(ref_expected,ref_actual,2)
    call compare_real(sorp_expected,sorp_actual,3)
    call compare_real(abs_expected,abs_actual,4)
    call require(event_expected.eqv.event_actual,5)
    if(transfer(abs_actual,0_int64)==transfer(1.0e3_real64*dt*dz,0_int64))peak_cap_count=peak_cap_count+1
  end do
  call require(peak_cap_count>0,6)

  print '(A)','PPA_WU05A3_SORPTIVITY_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SORPTIVITY_START_CONTINUE_END_AND_WET_GUARDS=PASS'
  print '(A)','PPA_WU05A3_SORPTIVITY_WALL_FACTOR_AND_PEAK_CAP=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_sorptivity(ts,t,tr,smax,alpha,time,delta_t,ppt,awl,thickness,diameter,wall_factor,apply_wall, &
       reference_in,sorptivity_in,reference_out,sorptivity_out,absorbed,continues)
    real(real64),intent(in)::ts,t,tr,smax,alpha,time,delta_t,ppt,awl,thickness,diameter,wall_factor
    real(real64),intent(in)::reference_in,sorptivity_in
    logical,intent(in)::apply_wall
    real(real64),intent(out)::reference_out,sorptivity_out,absorbed
    logical,intent(out)::continues
    real(real64)::deficit,active
    reference_out=reference_in
    sorptivity_out=sorptivity_in
    absorbed=0.0_real64
    deficit=max(0.0_real64,ts-t)
    active=0.0_real64
    if(deficit>=1.0e-8_real64)then
      if(time<1.0e-8_real64)then
        reference_out=ts
        sorptivity_out=smax*(max(0.0_real64,ts-t)/(ts-tr))**alpha
        active=sorptivity_out
      else if((reference_in-t)>1.0e-8_real64)then
        active=smax*((reference_in-t)/(ts-tr))**alpha
      end if
      absorbed=active*ppt*(4.0_real64*awl*thickness/diameter)* &
           (sqrt(time+delta_t)-sqrt(time))
      if(apply_wall)absorbed=wall_factor*absorbed
      absorbed=min(1.0e3_real64*delta_t*thickness,absorbed)
    end if
    continues=absorbed/delta_t>1.0e-7_real64
  end subroutine source_sorptivity

  subroutine compare_real(expected,actual,code)
    real(real64),intent(in)::expected,actual
    integer,intent(in)::code
    integer(int64)::expected_bits,actual_bits
    expected_bits=transfer(expected,expected_bits)
    actual_bits=transfer(actual,actual_bits)
    call require(expected_bits==actual_bits,code)
  end subroutine compare_real

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_SORPTIVITY_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_sorptivity_source_oracle
