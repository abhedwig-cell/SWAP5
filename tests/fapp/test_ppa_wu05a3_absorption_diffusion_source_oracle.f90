program test_ppa_wu05a3_absorption_diffusion_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_absorption_diffusion
  implicit none

  integer, parameter :: vector_count=100000
  real(real64) :: theta_s,theta,diff_wall,diff_aggregate,dia,unsat_volume,proportion,dz,dt,wall
  real(real64) :: expected,actual
  integer(int64) :: state,eb,ab
  integer :: i,status
  logical :: apply_wall

  state=20260923_int64
  do i=1,vector_count
    theta_s=0.5_real64
    theta=0.1_real64+0.4_real64*next_unit(state)
    diff_wall=10.0_real64*next_unit(state)
    diff_aggregate=10.0_real64*next_unit(state)
    dia=0.01_real64+0.5_real64*next_unit(state)
    unsat_volume=0.99_real64*next_unit(state)
    proportion=next_unit(state)
    dz=0.1_real64+4.0_real64*next_unit(state)
    dt=0.5_real64*next_unit(state)
    wall=next_unit(state)
    apply_wall=modulo(i,2)==0
    select case(modulo(i,4))
    case(0)
      theta=theta_s-0.5e-8_real64
    case(1)
      theta=theta_s-1.0e-8_real64
    case(2)
      theta=theta_s-0.2_real64*next_unit(state)
    case default
      theta=theta_s+0.01_real64
    end select
    call source_diffusion(theta_s,theta,diff_wall,diff_aggregate,dia,unsat_volume,proportion,dz,dt, &
         apply_wall,wall,expected)
    call ppa_wu05a3_absorption_diffusion(theta_s,theta,diff_wall,diff_aggregate,dia,unsat_volume, &
         proportion,dz,dt,apply_wall,wall,actual,status)
    call require(status==PPA_WU05A3_ABSORPTION_DIFFUSION_OK,1)
    eb=transfer(expected,eb);ab=transfer(actual,ab)
    call require(eb==ab,2)
  end do

  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSION_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSION_STRICT_DEFICIT_THRESHOLD=PASS'
  print '(A)','PPA_WU05A3_ABSORPTION_DIFFUSION_WALL_WETTING_FACTOR=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_diffusion(ts,t,diff_wall,diff_aggregate,dia,vunsat,pfrac,thickness,delta_t,apply_wall,wall,absorb)
    real(real64),intent(in)::ts,t,diff_wall,diff_aggregate,dia,vunsat,pfrac,thickness,delta_t,wall
    logical,intent(in)::apply_wall
    real(real64),intent(out)::absorb
    real(real64)::deficit,diff_avg,sorp_act
    absorb=0.0_real64
    deficit=max(0.0_real64,ts-t)
    if(deficit>=1.0e-8_real64)then
      diff_avg=(diff_wall+diff_aggregate)/2.0_real64
      sorp_act=(4.0_real64*8.0_real64*diff_avg*0.4_real64)/(dia**2*(1.0_real64-vunsat))*(ts-t)
      absorb=sorp_act*pfrac*thickness*delta_t
    end if
    if(apply_wall)absorb=wall*absorb
  end subroutine source_diffusion

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_ABSORPTION_DIFFUSION_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_absorption_diffusion_source_oracle
