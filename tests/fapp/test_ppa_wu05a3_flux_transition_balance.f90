program test_ppa_wu05a3_flux_transition_balance
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_flux_candidate
  implicit none
  real(real64) :: water(2,4),previous(2,4),volume(2,4),exchange(2,4),q(2,4),q0(2,4),residual(2,3)
  real(real64) :: incoming(2)
  integer(int32) :: front(2),status
  integer :: ic
  volume=1.0_real64; volume(:,4)=0.0_real64
  previous(1,:)=[0.2_real64,1.0_real64,1.0_real64,0.0_real64]
  previous(2,:)=[0.0_real64,0.3_real64,1.0_real64,0.0_real64]
  water=previous; water(1,1)=0.4_real64; water(2,2)=0.5_real64
  exchange=0.1_real64; exchange(:,4)=0.0_real64; q0=0.0_real64
  incoming=0.5_real64; front=[1_int32,2_int32]
  call calculate()
  call require(maxval(abs(residual))<1.e-14_real64,1)
  ! A shared transition from main domain 1 corrupts the internal cell balance.
  front=1_int32
  call calculate()
  call require(abs(residual(2,1)-0.2_real64)<1.e-14_real64,2)
  call require(abs(residual(2,2)+0.2_real64)<1.e-14_real64,3)
  call require(abs(sum(residual(2,:)))<1.e-14_real64,4)
  ! Put a 0.2 rapid-drainage sink in saturated main-domain cell 2.
  ! Account for that sink explicitly in the independent cell mass equation.
  front=[1_int32,2_int32]; water(1,:)=previous(1,:)
  call calculate()
  residual(1,2)=residual(1,2)-0.2_real64
  call require(abs(residual(1,1)-0.2_real64)<1.e-14_real64 .and. &
      abs(residual(1,2)+0.2_real64)<1.e-14_real64,5)
  call require(abs(sum(residual(1,:)))<1.e-14_real64,7)
  print '(A)','PPA_WU05A3_DOMAIN_FRONT_LOCAL_BALANCE=PASS'
  print '(A)','PPA_WU05A3_SHARED_FRONT_LOCAL_IMBALANCE=REPRODUCED'
  print '(A)','PPA_WU05A3_RAPID_DRAINAGE_RECURRENCE_GAP=REPRODUCED'
contains
  subroutine calculate()
    call ppa_wu05a3_macrostate_flux_candidate(4_int32,2_int32,1_int32,1_int32, &
        [3_int32,3_int32],[3_int32,3_int32],front,1.0_real64,incoming, &
        [0.0_real64,0.0_real64],exchange,water,previous,volume,volume,q0,q,status)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,6)
    do ic=1,3
      residual(:,ic)=q(:,ic)-q(:,ic+1)-exchange(:,ic)-(water(:,ic)-previous(:,ic))
    end do
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'TRANSITION_BALANCE_FAIL',code
      error stop 1
    end if
  end subroutine
end program
