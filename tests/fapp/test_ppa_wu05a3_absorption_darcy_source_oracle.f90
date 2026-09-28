program test_ppa_wu05a3_absorption_darcy_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_absorption_darcy
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: h,hentry,water_level,z,theta_s,theta,theta_r,alpha,sorpfacparl,dia,proportion,dz,k,shape,dt,wall
  real(real64) :: actual_dh,actual_fac,actual_flux,expected_dh,expected_fac,expected_flux
  integer(int64) :: state
  integer :: i,ic,water_top,status,expected_status
  logical :: enabled,wall_enabled,factor_defined

  state=20260923_int64
  do i=1,vector_count
    water_top=1+modulo(i,5)
    ic=water_top+1
    enabled=modulo(i,9)/=0
    wall_enabled=modulo(i,2)==0
    h=-0.5_real64+2.0_real64*next_unit(state)
    hentry=-0.2_real64+0.5_real64*next_unit(state)
    z=-5.0_real64+10.0_real64*next_unit(state)
    water_level=z+0.01_real64+3.0_real64*next_unit(state)
    theta_s=0.5_real64
    theta_r=0.1_real64
    theta=0.1_real64+0.5_real64*next_unit(state)
    alpha=0.2_real64+2.0_real64*next_unit(state)
    sorpfacparl=next_unit(state)
    dia=0.01_real64+0.5_real64*next_unit(state)
    proportion=next_unit(state)
    dz=0.1_real64+3.0_real64*next_unit(state)
    k=10.0_real64*next_unit(state)
    shape=0.1_real64+4.0_real64*next_unit(state)
    dt=0.01_real64+0.4_real64*next_unit(state)
    wall=next_unit(state)
    select case(modulo(i,4))
    case(0)
      h=0.1_real64;hentry=0.5_real64;water_level=z+2.0_real64
    case(1)
      h=0.9_real64;hentry=0.5_real64;water_level=z+2.0_real64
    case(2)
      h=0.1_real64;hentry=0.5_real64;water_level=z+0.05_real64
    end select
    if(modulo(i,11)==0)then
      enabled=.true.
      ic=water_top
    end if

    call source_candidate(enabled,ic,water_top,h,hentry,water_level,z,theta_s,theta,theta_r,alpha,sorpfacparl, &
         dia,proportion,dz,k,shape,dt,wall_enabled,wall,expected_dh,expected_fac,expected_flux,expected_status)
    call ppa_wu05a3_absorption_darcy_candidate(enabled,ic,water_top,h,hentry,water_level,z,theta_s,theta,theta_r, &
         alpha,sorpfacparl,dia,proportion,dz,k,shape,dt,wall_enabled,wall,actual_dh,actual_fac,actual_flux, &
         factor_defined,status)
    call require(status==expected_status,1)
    call require(factor_defined.eqv.(expected_status==PPA_WU05A3_ABSORPTION_DARCY_OK),2)
    call compare_real(expected_dh,actual_dh,3)
    call compare_real(expected_fac,actual_fac,4)
    call compare_real(expected_flux,actual_flux,5)
  end do

  print '(A)','PPA_WU05A3_ABSORPTION_DARCY_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DARCY_ENTRY_HEAD_AND_MACRO_HEAD_GATES=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DARCY_RESISTANCE_AND_SORPTIVITY_FACTOR=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_candidate(use_darcy,comp,top,h,entry,zw,elev,ts,t,tr,alpha,facparl,dia,pfrac,thick,cond,shape,dt, &
       apply_wall,wall,delh,sorpfac,abs_darc,result_status)
    logical,intent(in)::use_darcy,apply_wall
    integer,intent(in)::comp,top
    real(real64),intent(in)::h,entry,zw,elev,ts,t,tr,alpha,facparl,dia,pfrac,thick,cond,shape,dt,wall
    real(real64),intent(out)::delh,sorpfac,abs_darc
    integer,intent(out)::result_status
    real(real64)::hmp,recres,satdef
    delh=0.0_real64;sorpfac=0.0_real64;abs_darc=0.0_real64
    if(.not.use_darcy.or.comp<=top)then
      result_status=PPA_WU05A3_ABSORPTION_DARCY_INACTIVE
      return
    end if
    hmp=max(0.0_real64,zw-elev)
    if(h<entry-1.0e-8_real64.and.hmp>1.0e-8_real64)then
      delh=max(0.0_real64,hmp-h)
    end if
    recres=shape*8.0_real64*pfrac*thick*cond/dia**2
    if(apply_wall.and.comp==top)recres=wall*recres
    abs_darc=recres*delh*dt
    satdef=max(max(ts-t,0.0_real64),0.0_real64)
    sorpfac=facparl+(1.0_real64-facparl)*(1.0_real64-(satdef/(ts-tr))**alpha)
    result_status=PPA_WU05A3_ABSORPTION_DARCY_OK
  end subroutine source_candidate

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
    write(*,'(A,I0)')'PPA_WU05A3_ABSORPTION_DARCY_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_absorption_darcy_source_oracle
