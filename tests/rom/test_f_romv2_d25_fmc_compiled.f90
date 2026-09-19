program test_f_romv2_d25_fmc_compiled
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic
  implicit none

  integer, parameter :: NBINS=200, IBASE=100, J0=101, J1=199
  integer, parameter :: NHIST=3, NSTEPS=16
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NN=1.734737_real64
  real(real64), parameter :: MM=1.0_real64-1.0_real64/NN
  real(real64), parameter :: KS=31.225016_real64, ELL=0.98087_real64
  real(real64), parameter :: HCM=14.085215420920257_real64
  real(real64), parameter :: DEPTH=160.0_real64
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: DTH=(TS-TR)/real(NBINS,real64)
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: RELAX_TOL=1.0e-14_real64
  real(real64), parameter :: PONDMAX=KS*DT, RSRO=0.001_real64

  real(real64) :: TI,KI,TD,KD,GEFF,ADV
  character(len=32) :: mode,arg
  integer :: repeats,rep
  real(real64) :: checksum,total_checksum,t0,t1

  TI=theta_bin(IBASE)
  KI=kval(TI)
  TD=theta_bin(J1)
  KD=kval(TD)
  GEFF=max(abs(psi(TD)),HCM)
  ADV=(KD-KI)/(TD-TI)

  mode='validate'
  call get_command_argument(1,mode)
  if(len_trim(mode)==0)mode='validate'

  if(trim(mode)=='bench')then
    arg=''
    call get_command_argument(2,arg)
    read(arg,*)repeats
    call require(repeats>=1,'positive benchmark repeats')
    total_checksum=0.0_real64
    call cpu_time(t0)
    do rep=1,repeats
      call run_all(.false.,checksum)
      total_checksum=total_checksum+checksum
    end do
    call cpu_time(t1)
    write(*,'(*(g0))') 'F_ROMV2_D25_BENCH|ROUTE=FMC|REPEATS=',repeats, &
         '|CPU_SECONDS=',t1-t0,'|CHECKSUM=',total_checksum
  else
    call run_all(.true.,checksum)
    write(*,'(*(g0))') 'F_ROMV2_D25_FMC_VALIDATE_COMPLETE=PASS|CHECKSUM=',checksum
  end if

contains

  subroutine run_all(emit,checksum)
    logical,intent(in) :: emit
    real(real64),intent(out) :: checksum
    integer :: ih
    checksum=0.0_real64
    do ih=1,NHIST
      call run_history(ih,history_factor(ih),emit,checksum)
    end do
  end subroutine run_all

  subroutine run_history(ih,factor,emit,checksum)
    integer,intent(in) :: ih
    real(real64),intent(in) :: factor
    logical,intent(in) :: emit
    real(real64),intent(inout) :: checksum
    real(real64) :: fronts(J0:J1),gw(J0:J1),fronts2(J0:J1),gw2(J0:J1)
    real(real64) :: surfstore,prevstore,runoff,cumrun,cuminfil,cumbottom
    real(real64) :: rain,sb,sa,g0,g1,dgw,gray,alloc,infil,bottom,bflux
    real(real64) :: surface_ledger,soil_ledger,global_ledger,gap,srel,grel
    real(real64) :: theta16(16)
    integer :: step,cell
    logical :: ok

    call initial_surface(fronts)
    call initial_gw(gw)
    surfstore=0.0_real64;cumrun=0.0_real64;cuminfil=0.0_real64;cumbottom=0.0_real64

    do step=1,NSTEPS
      rain=factor*KS*DT
      sb=total_storage(fronts,gw)
      g0=groundwater_storage(gw)
      prevstore=surfstore

      call connected_surface_step(fronts,prevstore+rain,fronts2,gray,alloc,surfstore,runoff,srel,ok)
      call require(ok,'surface step')
      call groundwater_step(gw,gw2,grel,ok)
      call require(ok,'groundwater step')
      g1=groundwater_storage(gw2)
      dgw=g1-g0
      infil=gray+alloc
      bottom=gray-dgw
      sa=total_storage(fronts2,gw2)
      surface_ledger=prevstore+rain-infil-surfstore-runoff
      soil_ledger=(sa-sb)-infil+bottom
      global_ledger=(sa-sb)+surfstore-prevstore+runoff+bottom-rain
      call minimum_gap(fronts2,gw2,gap)
      call require(gap>0.0_real64,'surface-groundwater separation')
      call mapped_theta16(fronts2,gw2,theta16,ok)
      call require(ok,'mapped theta16')
      call require(max(abs(surface_ledger),abs(soil_ledger),abs(global_ledger))<=TOL,'ledger gate')
      call require(abs(srel)<=RELAX_TOL.and.abs(grel)<=RELAX_TOL,'relaxation gate')

      cumrun=cumrun+runoff
      cuminfil=cuminfil+infil
      cumbottom=cumbottom+bottom
      bflux=terminal_bottom_flux(gw2)

      if(emit)then
        write(*,'(*(g0))') 'F_ROMV2_D25_FMC_STATE|HISTORY=',trim(history_label(ih)), &
             '|STEP=',step,'|RAIN_CM=',rain,'|INFIL_CM=',infil,'|CUM_INFIL_CM=',cuminfil, &
             '|SURFACE_STORE_CM=',surfstore,'|RUNOFF_CM=',runoff,'|CUM_RUNOFF_CM=',cumrun, &
             '|BOTTOM_EXCHANGE_CM=',bottom,'|CUM_BOTTOM_CM=',cumbottom, &
             '|BOTTOM_FLUX_CM_PER_DAY=',bflux,'|SOIL_STORAGE_CM=',sa,'|MIN_GAP_CM=',gap, &
             '|SURFACE_LEDGER_CM=',surface_ledger,'|SOIL_LEDGER_CM=',soil_ledger, &
             '|GLOBAL_LEDGER_CM=',global_ledger
        do cell=1,16
          write(*,'(*(g0))') 'F_ROMV2_D25_FMC_CELL|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|CELL=',cell,'|THETA=',theta16(cell)
        end do
      end if

      fronts=fronts2
      gw=gw2
    end do

    call mapped_theta16(fronts,gw,theta16,ok)
    call require(ok,'final benchmark mapped theta16')
    checksum=checksum+total_storage(fronts,gw)+surfstore+cumrun+cuminfil+cumbottom+terminal_bottom_flux(gw)+sum(theta16)
  end subroutine run_history

  pure real(real64) function theta_bin(j) result(v)
    integer,intent(in) :: j
    v=TR+real(j,real64)*DTH
  end function theta_bin

  pure real(real64) function psi(t) result(v)
    real(real64),intent(in) :: t
    real(real64) :: se
    se=(t-TR)/(TS-TR)
    v=((se**(-1.0_real64/MM)-1.0_real64)**(1.0_real64/NN))/ALPHA
  end function psi

  pure real(real64) function kval(t) result(v)
    real(real64),intent(in) :: t
    real(real64) :: se
    se=(t-TR)/(TS-TR)
    v=KS*se**ELL*(1.0_real64-(1.0_real64-se**(1.0_real64/MM))**MM)**2
  end function kval

  subroutine initial_surface(fronts)
    real(real64),intent(out) :: fronts(J0:J1)
    integer :: j
    do j=J0,J1
      fronts(j)=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
    end do
  end subroutine initial_surface

  subroutine initial_gw(gw)
    real(real64),intent(out) :: gw(J0:J1)
    integer :: j
    do j=J0,J1
      gw(j)=0.25_real64*abs(psi(theta_bin(j)))
    end do
  end subroutine initial_gw

  subroutine relax_map(a,drift)
    real(real64),intent(inout) :: a(J0:J1)
    real(real64),intent(out) :: drift
    real(real64) :: before,after,tmp
    integer :: i,j,maxj
    before=DTH*sum(a)
    do i=J0,J1-1
      maxj=i
      do j=i+1,J1
        if(a(j)>a(maxj))maxj=j
      end do
      if(maxj/=i)then
        tmp=a(i);a(i)=a(maxj);a(maxj)=tmp
      end if
    end do
    after=DTH*sum(a)
    drift=after-before
  end subroutine relax_map

  subroutine surface_route(residual,store,runoff)
    real(real64),intent(in) :: residual
    real(real64),intent(out) :: store,runoff
    real(real64) :: ratio
    if(residual<=PONDMAX)then
      store=residual;runoff=0.0_real64
    else
      ratio=DT/RSRO
      store=(residual+ratio*PONDMAX)/(1.0_real64+ratio)
      runoff=residual-store
    end if
  end subroutine surface_route

  subroutine connected_surface_step(fronts,available,out,gray,alloc,store,runoff,drift,ok)
    real(real64),intent(in) :: fronts(J0:J1),available
    real(real64),intent(out) :: out(J0:J1),gray,alloc,store,runoff,drift
    logical,intent(out) :: ok
    real(real64) :: rem,z,raw,demand,take
    integer :: j
    ok=.false.;out=fronts
    gray=KI*DT
    if(available+1.0e-18_real64<gray)return
    rem=available-gray;alloc=0.0_real64
    do j=J0,J1
      z=fronts(j)
      raw=z+DT*ADV*(1.0_real64+GEFF/z)
      if(.not.ieee_is_finite(raw).or.raw<=0.0_real64.or.raw>=DEPTH)return
      demand=max(0.0_real64,DTH*(raw-z))
      take=min(rem,demand)
      if(take>0.0_real64)then
        out(j)=z+take/DTH
        rem=rem-take
        alloc=alloc+take
      end if
      if(take<demand-1.0e-18_real64 .or. rem<=1.0e-18_real64)exit
    end do
    call relax_map(out,drift)
    call surface_route(max(0.0_real64,rem),store,runoff)
    if(.not.(store>=0.0_real64.and.runoff>=0.0_real64.and.store<=max(0.0_real64,rem)+TOL))return
    ok=.true.
  end subroutine connected_surface_step

  pure real(real64) function gw_velocity(j,h) result(v)
    integer,intent(in) :: j
    real(real64),intent(in) :: h
    real(real64) :: tj
    tj=theta_bin(j)
    v=(kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0_real64)
  end function gw_velocity

  subroutine groundwater_step(gw,out,drift,ok)
    real(real64),intent(in) :: gw(J0:J1)
    real(real64),intent(out) :: out(J0:J1),drift
    logical,intent(out) :: ok
    integer :: j
    ok=.false.
    do j=J0,J1
      out(j)=gw(j)+DT*gw_velocity(j,gw(j))
      if(.not.ieee_is_finite(out(j)).or.out(j)<=0.0_real64.or.out(j)>DEPTH)return
    end do
    call relax_map(out,drift)
    ok=.true.
  end subroutine groundwater_step

  pure real(real64) function groundwater_storage(gw) result(v)
    real(real64),intent(in) :: gw(J0:J1)
    v=TI*DEPTH+DTH*sum(gw)
  end function groundwater_storage

  pure real(real64) function total_storage(fronts,gw) result(v)
    real(real64),intent(in) :: fronts(J0:J1),gw(J0:J1)
    v=TI*DEPTH+DTH*(sum(fronts)+sum(gw))
  end function total_storage

  subroutine minimum_gap(fronts,gw,gap)
    real(real64),intent(in) :: fronts(J0:J1),gw(J0:J1)
    real(real64),intent(out) :: gap
    integer :: j
    gap=huge(0.0_real64)
    do j=J0,J1
      gap=min(gap,DEPTH-fronts(j)-gw(j))
    end do
  end subroutine minimum_gap

  pure real(real64) function terminal_bottom_flux(gw) result(v)
    real(real64),intent(in) :: gw(J0:J1)
    integer :: j
    v=KI
    do j=J0,J1
      v=v-DTH*gw_velocity(j,gw(j))
    end do
  end function terminal_bottom_flux

  subroutine mapped_theta16(fronts,gw,vals,ok)
    real(real64),intent(in) :: fronts(J0:J1),gw(J0:J1)
    real(real64),intent(out) :: vals(16)
    logical,intent(out) :: ok
    integer :: c,j
    real(real64) :: top,bot,t,surf,gtop,ground
    ok=.false.
    do c=1,16
      top=10.0_real64*real(c-1,real64);bot=top+10.0_real64;t=TI
      do j=J0,J1
        surf=max(0.0_real64,min(fronts(j),bot)-top)
        gtop=DEPTH-gw(j)
        ground=max(0.0_real64,bot-max(gtop,top))
        if(surf>0.0_real64.and.ground>0.0_real64.and.min(fronts(j),bot)>max(gtop,top))return
        t=t+DTH*(surf+ground)/10.0_real64
      end do
      if(.not.(t>TR.and.t<TS).or..not.ieee_is_finite(t))return
      vals(c)=t
    end do
    ok=.true.
  end subroutine mapped_theta16

  pure real(real64) function history_factor(ih) result(v)
    integer,intent(in) :: ih
    select case(ih)
    case(1);v=0.5_real64
    case(2);v=2.0_real64
    case(3);v=4.0_real64
    case default;v=-1.0_real64
    end select
  end function history_factor

  function history_label(ih) result(v)
    integer,intent(in) :: ih
    character(len=4) :: v
    select case(ih)
    case(1);v='RG05'
    case(2);v='RG20'
    case(3);v='RG40'
    case default;v='BAD '
    end select
  end function history_label

  subroutine require(cond,label)
    logical,intent(in) :: cond
    character(len=*),intent(in) :: label
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_ROMV2_D25_FMC_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require


end program test_f_romv2_d25_fmc_compiled
