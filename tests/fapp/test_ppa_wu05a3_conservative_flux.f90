program test_ppa_wu05a3_conservative_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_wu05a3_conservative_flux
  implicit none
  real(real64) :: old(2,3),new(2,3),exchange(2,3),drain(2,3),top(2),bottom(2),q(2,4),residual(2)
  integer :: status,ic
  old(1,:)=[0.2_real64,1.0_real64,1.0_real64]
  old(2,:)=[0.0_real64,0.3_real64,1.0_real64]
  new=old; new(1,1)=0.4_real64; new(2,2)=0.5_real64
  exchange=0.1_real64; drain=0.0_real64; top=0.5_real64; bottom=0.0_real64
  call invoke()
  call require(status==FLUX_OK,1)
  call require(maxval(abs(q(1,:)-[0.5_real64,0.2_real64,0.1_real64,0.0_real64]))<1.e-14_real64,2)
  call require(maxval(abs(q(2,:)-[0.5_real64,0.4_real64,0.1_real64,0.0_real64]))<1.e-14_real64,3)
  new(1,:)=old(1,:); drain(1,2)=0.2_real64
  call invoke()
  call require(status==FLUX_OK,4)
  call require(maxval(abs(q(1,:)-[0.5_real64,0.4_real64,0.1_real64,0.0_real64]))<1.e-14_real64,5)
  do ic=1,3
    call require(maxval(abs(q(:,ic)-q(:,ic+1)-exchange(:,ic)-drain(:,ic)-(new(:,ic)-old(:,ic)))) &
        <1.e-14_real64,6)
  end do
  bottom(2)=0.25_real64
  call invoke()
  call require(status==FLUX_BOUNDARY_MISMATCH .and. abs(residual(2)+0.25_real64)<1.e-14_real64,7)
  old=1.0_real64; new=old
  new(:,1)=0.8_real64; new(:,2)=1.2_real64; new(:,3)=0.9_real64
  exchange=0.0_real64; drain=0.0_real64; top=0.0_real64; bottom=0.1_real64
  call invoke()
  call require(status==FLUX_OK,8)
  call require(maxval(abs(q(1,:)-[0.0_real64,0.2_real64,0.0_real64,0.1_real64]))<1.e-14_real64,9)
  new(1,1)=ieee_value(0.0_real64,ieee_quiet_nan)
  call invoke()
  call require(status==FLUX_INVALID .and. maxval(abs(q))<1.e-14_real64,10)
  print '(A)','PPA_WU05A3_CONSERVATIVE_FLUX_FRONT_AND_DRAIN=PASS'
  print '(A)','PPA_WU05A3_CONSERVATIVE_FLUX_REDISTRIBUTION=PASS'
  print '(A)','PPA_WU05A3_CONSERVATIVE_FLUX_BOUNDARY_GUARD=PASS'
contains
  subroutine invoke()
    call reconstruct_conservative_flux(1.0_real64,old,new,exchange,drain,top,bottom,1.e-14_real64,q,residual,status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'CONSERVATIVE_FLUX_FAIL',code
      error stop 1
    end if
  end subroutine
end program
