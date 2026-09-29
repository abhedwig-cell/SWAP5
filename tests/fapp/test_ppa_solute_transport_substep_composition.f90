program test_ppa_solute_transport_substep_composition
  use,intrinsic::iso_fortran_env,only:real64,int64
  use mod_ppa_solute_dispersion
  use mod_ppa_solute_timestep
  implicit none
  integer,parameter::vector_count=100000,node_count=6
  integer(int64)::state
  integer::i,j,status
  real(real64)::q(node_count),theta(node_count),ddif(node_count),ldis(node_count),dz(node_count)
  real(real64)::effective_dispersion(node_count)
  real(real64)::dt,dtmin,elapsed,expected,actual,diff,vp,disp,dummy,disp1,vp2
  state=20260923_int64
  do i=1,vector_count
    do j=1,node_count
      q(j)=-10.0_real64+20.0_real64*next_unit(state)
      theta(j)=0.01_real64+0.8_real64*next_unit(state)
      ddif(j)=10.0_real64*next_unit(state)
      ldis(j)=100.0_real64*next_unit(state)
      dz(j)=0.01_real64+10.0_real64*next_unit(state)
    end do
    dt=0.001_real64+1.0_real64*next_unit(state)
    dtmin=1.0e-8_real64+1.0e-4_real64*next_unit(state)
    elapsed=dt*0.9_real64*next_unit(state)
    expected=dt
    do j=1,node_count
      diff=ddif(j)*theta(j)**2.33_real64
      vp=abs(q(j))/theta(j)
      vp2=vp*vp
      disp1=diff+ldis(j)*vp
      disp=disp1+0.5_real64*dt*vp2
      if(disp<1.0e-8_real64)disp=1.0e-8_real64
      dummy=dz(j)*dz(j)/(2.0_real64*disp)
      expected=min(expected,dummy)
      call ppa_solute_dispersion_coefficient(q(j),theta(j),ddif(j),ldis(j),dt,diff,vp,disp,status)
      call require(status==PPA_SOLUTE_DISPERSION_OK,1)
      effective_dispersion(j)=disp
    end do
    expected=max(min(expected,dt-elapsed),dtmin)
    call ppa_solute_timestep_candidate(dz,effective_dispersion,dt,dtmin,elapsed,actual,status)
    call require(status==PPA_SOLUTE_TIMESTEP_OK,2)
    call compare_real(expected,actual,3)
  end do
  print '(A)','PPA_SOLUTE_TRANSPORT_SUBSTEP_COMPOSITION_100000=PASS'
  print '(A)','PPA_SOLUTE_DISPERSION_TO_STABILITY_MIN_TO_DTMIN_PIPELINE=PASS'
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
    write(*,'(A,I0)')'PPA_SOLUTE_TRANSPORT_SUBSTEP_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_transport_substep_composition
