program test_ppa_wu05a3_conservative_composition
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_storage_candidate
  use mod_ppa_wu05a3_macrostate_wetting_candidate
  use mod_ppa_wu05a3_conservative_flux
  implicit none
  real(real64) :: old(2,3),water(2,3),volume(2,3),fraction(2,3),zeros(2,3),exchange(2,3),drain(3)
  real(real64) :: previous_storage(2),storage(2),unsat(2),qlat(2),qvrt(2),total,dt
  real(real64) :: level(2),faces(2,4),residual(2),drain_by_domain(2,3)
  integer(int32) :: front(2),bottom(2),status
  integer :: interval,ic
  zeros=0.0_real64; volume=0.5_real64
  old(1,:)=[0.0_real64,0.25_real64,0.5_real64]
  old(2,:)=[0.0_real64,0.0_real64,0.25_real64]
  previous_storage=sum(old,dim=2); bottom=3_int32
  qlat=[0.25_real64,0.125_real64]; qvrt=0.0_real64
  exchange=0.0_real64; exchange(1,2)=0.0625_real64; exchange(2,1)=0.0625_real64
  drain=[0.0_real64,0.0_real64,0.0625_real64]
  do interval=1,3
    dt=2.0_real64**(1-interval)
    if(interval==2) volume=0.375_real64
    call compose()
    call require(status==FLUX_OK,1)
    call require(maxval(abs(sum(water,dim=2)-storage))<1.e-14_real64,2)
    do ic=1,3
      call require(maxval(abs((faces(:,ic)-faces(:,ic+1)-exchange(:,ic)-drain_by_domain(:,ic))*dt- &
          (water(:,ic)-old(:,ic))))<1.e-14_real64,3)
    end do
    old=water; previous_storage=storage
  end do
  call require(maxval(abs(storage-[0.96875_real64,0.359375_real64]))<1.e-14_real64,4)
  ! An inconsistent previous profile must not be hidden by matching scalar storage.
  old=0.0_real64
  call compose()
  call require(status==FLUX_BOUNDARY_MISMATCH,5)
  ! Source zero clamp discards an overdraw. Explicit lower-boundary check exposes it.
  old=water; previous_storage=storage; qlat=0.0_real64; exchange=0.0_real64
  dt=1.0_real64; drain=0.0_real64; drain(3)=2.0_real64
  call compose()
  call require(status==FLUX_BOUNDARY_MISMATCH .and. abs(storage(1))<1.e-14_real64,6)
  print '(A)','PPA_WU05A3_CONSERVATIVE_COMPOSITION_INTERVALS=PASS'
  print '(A)','PPA_WU05A3_CONSERVATIVE_COMPOSITION_CELL_BALANCE=PASS'
  print '(A)','PPA_WU05A3_CONSERVATIVE_COMPOSITION_HISTORY_GUARD=PASS'
  print '(A)','PPA_WU05A3_CONSERVATIVE_COMPOSITION_OVERDRAW_GUARD=PASS'
contains
  subroutine compose()
    call ppa_wu05a3_macrostate_storage_candidate(3_int32,2_int32,1_int32,1_int32,bottom,dt, &
        previous_storage,qlat,qvrt,exchange,drain,old,volume,[0.0_real64,0.0_real64], &
        storage,unsat,front,total,status)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,7)
    call ppa_wu05a3_macrostate_wetting_candidate(3_int32,2_int32,1_int32,1_int32,bottom,storage, &
        [-3.0_real64,-3.0_real64],volume,[1.0_real64,1.0_real64,1.0_real64],zeros,old, &
        fraction,water,front,level,status)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,8)
    drain_by_domain=0.0_real64; drain_by_domain(1,:)=drain
    call reconstruct_conservative_flux(dt,old,water,exchange,drain_by_domain,qlat+qvrt, &
        [0.0_real64,0.0_real64],1.e-14_real64,faces,residual,status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'CONSERVATIVE_COMPOSITION_FAIL',code
      error stop 1
    end if
  end subroutine
end program
