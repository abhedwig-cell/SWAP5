program test_frost_bottom
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  use mod_frost_bottom_boundary_effect
  implicit none
  real(real64)::t(4),w(4),sat(4),dz(4),f(4),q,air,expected,nan,inf
  type(frost_bottom_result_t)::r
  integer::mask,j,k,deep,signum
  logical::blocked
  nan=ieee_value(0._real64,ieee_quiet_nan);inf=ieee_value(0._real64,ieee_positive_inf)
  sat=.5_real64;dz=1._real64
  ! Enumerated independent oracle: air is a suffix sum selected by the LAST barrier
  ! among nodes 1:3, while the freeze index excludes node4 under the legacy contract.
  do mask=0,15
    do j=1,4
      t(j)=merge(-3._real64,1._real64,btest(mask,j-1))
    end do
    deep=-1
    do j=1,3
      if(btest(mask,j-1))deep=j
    end do
    do k=0,7
      f=1._real64
      do j=1,3
        if(btest(k,j-1))f(j)=.01_real64
      end do
      w=[.499_real64,.498_real64,.497_real64,.496_real64]
      j=1
      if(btest(k,0))j=2
      if(btest(k,1))j=3
      if(btest(k,2))j=4
      air=sum((sat(j:)-w(j:))*dz(j:))
      blocked=deep>1.and.air<.01_real64
      do signum=-1,1,2
        q=real(signum,real64)*.25_real64
        expected=merge(0._real64,q,blocked)
        call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,q,r)
        call require(r%available.and.r%status==FROST_BOTTOM_OK,'enumerated valid')
        call require(r%deepest_node==deep.and.(r%blocked.eqv.blocked),'independent freeze classification')
        call require(abs(r%available_air_cm-air)<1.e-15_real64.and.r%final_flux==expected,'suffix/sign oracle')
      end do
    end do
  end do
  ! Air threshold constructed exactly with theta_sat=0.01, theta=0, dz=1.
  t=-3._real64;f=0._real64;sat=.01_real64;w=0._real64;dz=1._real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(r%available_air_cm==.01_real64.and..not.r%blocked,'air equality unblocked')
  dz(4)=nearest(1._real64,-1._real64)
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(r%blocked,'air immediately below threshold blocked')
  dz=1._real64;w=sat;f=1._real64;t=1._real64;t(4)=-3._real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,-1._real64,r)
  call require(r%deepest_node==-1.and.r%final_flux==-1._real64,'last node intentionally omitted')
  t(1)=-3._real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,-1._real64,r)
  call require(r%deepest_node==1.and..not.r%blocked,'top node alone allowed')
  t(2)=-2._real64+1.e-6_real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,-1._real64,r)
  call require(r%deepest_node==2.and.r%blocked,'temperature epsilon equality')
  t(2)=nearest(t(2),1._real64)
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,-1._real64,r)
  call require(r%deepest_node==1.and..not.r%blocked,'temperature immediately above cutoff')
  t=-3._real64;w=0._real64;sat=[.02_real64,.02_real64,.006_real64,.004_real64]
  dz=1._real64;f=0._real64;f(3)=.01_real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(r%blocked.and.r%available_air_cm==.004_real64,'factor equality stops before preceding node')
  f(3)=nearest(.01_real64,1._real64)
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(.not.r%blocked.and.abs(r%available_air_cm-.01_real64)<1.e-18_real64,'factor above threshold traverses')
  call compose_legacy_no_drain_frost_bottom(.true.,t(:1),-2._real64,w(:1),sat(:1),dz(:1),f(:1),1._real64,r)
  call require(r%available.and.r%deepest_node==-1.and..not.r%blocked,'one node contract')
  t=nan;w=inf;dz=-1._real64;f=nan
  call compose_legacy_no_drain_frost_bottom(.false.,t,nan,w,sat,dz,f,-.3_real64,r)
  call require(r%available.and.r%final_flux==-.3_real64,'OFF exact identity ignores inactive inputs')
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(.not.r%available,'invalid fields rejected')
  t=1._real64;w=.2_real64;sat=.5_real64;dz=1._real64;f=1._real64
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w(:3),sat,dz,f,1._real64,r)
  call require(.not.r%available,'shape rejected')
  f(1)=inf
  call compose_legacy_no_drain_frost_bottom(.true.,t,-2._real64,w,sat,dz,f,1._real64,r)
  call require(.not.r%available,'infinite factor rejected')
  print '(A)','PPA-WU05B3_FROST_BOTTOM_UNIT=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
