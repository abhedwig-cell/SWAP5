program test_ppa_solute_transport_flux_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_solute_transport_flux
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status
  real(real64)::q,cface,theta,diffusion,cright,cleft,distance,dt,expected,actual,nan_value
  state=20260923_int64
  do i=1,vector_count
    q=-3.0_real64+6.0_real64*next_unit(state)
    cface=100.0_real64*next_unit(state)
    theta=0.5_real64*next_unit(state)
    diffusion=2.0_real64*next_unit(state)
    cright=100.0_real64*next_unit(state)
    cleft=100.0_real64*next_unit(state)
    distance=0.1_real64+10.0_real64*next_unit(state)
    dt=0.001_real64+0.2_real64*next_unit(state)
    select case(mod(i,4))
    case(0)
      cright=cleft
    case(1)
      q=0.0_real64
    case(2)
      theta=0.0_real64
    end select
    call source_flux(q,cface,theta,diffusion,cright,cleft,distance,dt,expected)
    call ppa_solute_face_flux_amount(q,cface,theta,diffusion,cright,cleft,distance,dt,actual,status)
    call require(status==PPA_SOLUTE_TRANSPORT_FLUX_OK,1)
    call compare_real(expected,actual,2)
  end do
  print '(A)','PPA_SOLUTE_INTERNAL_FACE_FLUX_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_ADVECTIVE_DISPERSIVE_SIGN_COMPOSITION=PASS'
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_face_flux_amount(1.0_real64,nan_value,0.2_real64,0.1_real64, &
       1.0_real64,0.0_real64,1.0_real64,0.1_real64,actual,status)
  call require(status==PPA_SOLUTE_TRANSPORT_FLUX_INVALID_INPUT,3)
  call ppa_solute_face_flux_amount(1.0_real64,1.0_real64,0.2_real64,0.1_real64, &
       1.0_real64,0.0_real64,0.0_real64,0.1_real64,actual,status)
  call require(status==PPA_SOLUTE_TRANSPORT_FLUX_INVALID_INPUT,4)
  call ppa_solute_face_flux_amount(huge(1.0_real64),100.0_real64,0.2_real64,0.1_real64, &
       1.0_real64,0.0_real64,1.0_real64,0.1_real64,actual,status)
  call require(status==PPA_SOLUTE_TRANSPORT_FLUX_INVALID_INPUT,5)
  print '(A)','PPA_SOLUTE_INTERNAL_FACE_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine source_flux(waterflux,cmobile,theta_v,disp,cr,cl,dx,delta_t,amount)
    real(real64),intent(in)::waterflux,cmobile,theta_v,disp,cr,cl,dx,delta_t
    real(real64),intent(out)::amount
    amount=(waterflux*cmobile+theta_v*disp*(cr-cl)/dx)*delta_t
  end subroutine source_flux
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
    write(*,'(A,I0)')'PPA_SOLUTE_INTERNAL_FACE_FLUX_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_transport_flux_source_oracle
