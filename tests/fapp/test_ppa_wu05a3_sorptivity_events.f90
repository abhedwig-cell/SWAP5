program test_ppa_wu05a3_sorptivity_events
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a3_sorptivity_events
  implicit none
  real(real64) :: t(2,3),s(2,3),r(2,3),w(3),tn(2,3),sn(2,3),rn(2,3),wn(3)
  real(real64) :: wet(2,3),pp(2,3),diameter(3)
  logical :: ended(2,3)
  integer :: water_top(2),bottom(2),status
  t=4.0_real64; s=2.0_real64; r=1.0_real64; w=0.8_real64
  wet=0.5_real64; pp=0.25_real64; diameter=2.0_real64
  ended=.false.; ended(1,2)=.true.; water_top=2; bottom=3
  call invoke(1,4)
  call require(status==0,1)
  call require(maxval(abs(tn(:,1)))+maxval(abs(sn(:,1)))+maxval(abs(rn(:,1)))<1.e-14_real64,2)
  call require(abs(tn(1,2))+abs(sn(1,2))+abs(rn(1,2))+abs(wn(2))<1.e-14_real64,3)
  call require(abs(tn(2,2)-9.0_real64)+abs(rn(2,2)-1.0_real64)<1.e-14_real64,4)
  call require(maxval(abs(rn(:,3)-1.4_real64))+maxval(abs(tn(:,3)-9.0_real64))<1.e-14_real64,5)
  call require(maxval(abs(t-4.0_real64))+maxval(abs(s-2.0_real64))+maxval(abs(w-0.8_real64))<1.e-14_real64,6)
  call invoke(1,3)
  call require(status==0 .and. maxval(abs(tn(:,3)))<1.e-14_real64,7)
  call invoke(0,3)
  call require(status==0,8)
  call require(maxval(abs(tn-t))+maxval(abs(sn-s))+maxval(abs(rn-r))+maxval(abs(wn-w))<1.e-14_real64,9)
  bottom=0
  call invoke(1,4)
  call require(status==0 .and. maxval(abs(tn))+maxval(abs(sn))+maxval(abs(rn))<1.e-14_real64,10)
  diameter(1)=0.0_real64
  call invoke(1,4)
  call require(status==1,11)
  call refresh_sorptivity_wall(2,[0.0_real64,0.75_real64,1.0_real64], &
      [0.0_real64,0.5_real64,0.5_real64],[0.0_real64,2.0_real64,2.0_real64],w,wn,status)
  call require(status==0,12)
  call require(maxval(abs(wn-[0.8_real64,0.5_real64,0.0_real64]))<1.e-14_real64,13)
  call refresh_sorptivity_wall(2,[0.0_real64,1.25_real64,1.0_real64], &
      [0.0_real64,0.5_real64,0.5_real64],[0.0_real64,2.0_real64,2.0_real64],w,wn,status)
  call require(status==1 .and. maxval(abs(wn))<1.e-14_real64,14)
  call refresh_sorptivity_wall(1,[0.0_real64,0.75_real64,1.0_real64], &
      [0.0_real64,0.5_real64,0.5_real64],[1.0_real64,2.0_real64,2.0_real64],w,wn,status)
  call require(status==1,15)
  print '(A)', 'PPA_WU05A3_SORPTIVITY_EVENT_INCREMENT=PASS'
  print '(A)', 'PPA_WU05A3_SORPTIVITY_SHARED_WALL_ORDER=PASS'
  print '(A)', 'PPA_WU05A3_SORPTIVITY_RESETS_AND_DISABLED=PASS'
  print '(A)', 'PPA_WU05A3_SORPTIVITY_HISTORY_AND_INVALID=PASS'
  print '(A)', 'PPA_WU05A3_SORPTIVITY_WALL_REFRESH=PASS'
contains
  subroutine invoke(mode,saturated_top)
    integer,intent(in) :: mode,saturated_top
    call update_sorptivity_events(3,2,1,saturated_top,mode,water_top,bottom,5.0_real64,ended, &
        wet,pp,diameter,t,s,r,w,tn,sn,rn,wn,status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if(.not.ok) then
      print *, 'SORPTIVITY_EVENTS_FAIL',code
      error stop 1
    end if
  end subroutine
end program
