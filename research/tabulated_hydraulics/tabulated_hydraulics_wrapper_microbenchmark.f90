program tabulated_hydraulics_wrapper_microbenchmark
  use iso_fortran_env, only: real64, int64
  use swap_array_dimensions, only: macp, matab, matabentries
  use variables, only: cofgen, swsophy, numtab, sptab, ientrytab, iHWCKmodel, layer, &
                       swfrost, dt, fluseksatexm, tsoil
  use soilhydraulics_utils, only: watcon, moiscap, hconduc
  implicit none

  integer, parameter :: ntab=250, nhead=256
  integer(int64), parameter :: nouter=10000_int64
  real(real64), parameter :: ores=0.01_real64, osat=0.42_real64
  real(real64), parameter :: alfa=0.0276_real64, npar=1.491_real64
  real(real64), parameter :: mpar=1.0_real64-1.0_real64/npar
  real(real64), parameter :: ksat=12.52_real64, lexp=-1.060_real64
  real(real64), parameter :: hcrit=-1.0e-2_real64
  real(real64), parameter :: relsat_ksat=1.0_real64-1.0e-6_real64

  real(real64) :: heads(nhead), theta_ref(nhead), headtab(ntab), xtab(ntab), theta_tab(ntab), logk_tab(ntab)
  real(real64) :: dydx(ntab), sigma(ntab)
  real(real64) :: th, cap, kval, sink, t0, t1, sec, sec_watcon, sec_moiscap, sec_hconduc
  real(real64) :: h0,h1,x0,x1,x,frac,k_target
  integer :: i,j,idx
  integer(int64) :: outer
  character(len=32) :: mode

  mode='analytic'
  if(command_argument_count()>=1) call get_command_argument(1,mode)

  call setup_common()
  if(trim(mode)=='analytic') then
    call setup_analytic()
  else if(trim(mode)=='table') then
    call setup_table()
  else
    error stop 'mode must be analytic or table'
  end if

  do i=1,nhead
    frac=real(i-1,real64)/real(nhead-1,real64)
    heads(i)=-10.0_real64**(6.0_real64-7.5_real64*frac)
    call constitutive(heads(i),theta_ref(i),kval)
  end do

  ! Warm-up.
  sink=0.0_real64
  do i=1,nhead
    th=watcon(1,heads(i))
    cap=moiscap(1,heads(i))
    kval=hconduc(1,heads(i),th,1.0_real64)
    sink=sink+th+cap+kval
  end do

  call cpu_time(t0)
  sink=0.0_real64
  do outer=1,nouter
    do i=1,nhead
      sink=sink+watcon(1,heads(i))
    end do
  end do
  call cpu_time(t1)
  sec_watcon=t1-t0

  call cpu_time(t0)
  do outer=1,nouter
    do i=1,nhead
      sink=sink+moiscap(1,heads(i))
    end do
  end do
  call cpu_time(t1)
  sec_moiscap=t1-t0

  call cpu_time(t0)
  do outer=1,nouter
    do i=1,nhead
      sink=sink+hconduc(1,heads(i),theta_ref(i),1.0_real64)
    end do
  end do
  call cpu_time(t1)
  sec_hconduc=t1-t0

  call cpu_time(t0)
  do outer=1,nouter
    do i=1,nhead
      th=watcon(1,heads(i))
      cap=moiscap(1,heads(i))
      kval=hconduc(1,heads(i),th,1.0_real64)
      sink=sink+th+cap+kval
    end do
  end do
  call cpu_time(t1)
  sec=t1-t0

  write(*,'(A,A)') 'MODE=',trim(mode)
  write(*,'(A,I0)') 'EVALUATION_SETS=',nouter*int(nhead,int64)
  write(*,'(A,ES24.16)') 'WATCON_NS_PER_CALL=',sec_watcon*1.0e9_real64/real(nouter*int(nhead,int64),real64)
  write(*,'(A,ES24.16)') 'MOISCAP_NS_PER_CALL=',sec_moiscap*1.0e9_real64/real(nouter*int(nhead,int64),real64)
  write(*,'(A,ES24.16)') 'HCONDUC_NS_PER_CALL=',sec_hconduc*1.0e9_real64/real(nouter*int(nhead,int64),real64)
  write(*,'(A,ES24.16)') 'CPU_SECONDS=',sec
  write(*,'(A,ES24.16)') 'NS_PER_SET=',sec*1.0e9_real64/real(nouter*int(nhead,int64),real64)
  write(*,'(A,ES24.16)') 'CHECKSUM=',sink
  write(*,'(A)') 'MICROBENCHMARK_COMPLETED'

contains

  subroutine setup_common()
    cofgen=0.0_real64
    swsophy=0
    numtab=0
    sptab=0.0_real64
    ientrytab=0
    iHWCKmodel=1
    layer=1
    swfrost=0
    dt=0.04_real64
    fluseksatexm=.false.
    tsoil=10.0_real64
  end subroutine setup_common

  subroutine setup_analytic()
    swsophy=0
    cofgen(1,1)=ores
    cofgen(2,1)=osat
    cofgen(3,1)=ksat
    cofgen(4,1)=alfa
    cofgen(5,1)=lexp
    cofgen(6,1)=npar
    cofgen(7,1)=mpar
    cofgen(9,1)=0.0_real64
  end subroutine setup_analytic

  subroutine setup_table()
    real(real64) :: relsat
    swsophy=1
    numtab(1)=ntab

    h0=-1.0e7_real64
    k_target=ksat*(1.0_real64-1.0e-8_real64)
    call find_wet_head(k_target,h1)
    x0=-log(1.0_real64-h0)
    x1=-log(1.0_real64-h1)

    do i=1,ntab-1
      frac=real(i-1,real64)/real(ntab-2,real64)
      x=x0+frac*(x1-x0)
      if(i==ntab-1) then
        headtab(i)=h1
      else
        headtab(i)=1.0_real64-exp(-x)
      end if
      call constitutive(headtab(i),theta_tab(i),kval)
      logk_tab(i)=log(kval)
    end do
    headtab(ntab)=0.0_real64
    theta_tab(ntab)=osat
    logk_tab(ntab)=log(ksat)

    do i=1,ntab
      xtab(i)=-log(1.0_real64-headtab(i))
      sptab(1,1,i)=xtab(i)
      sptab(2,1,i)=theta_tab(i)
      sptab(3,1,i)=logk_tab(i)

      if(headtab(i)>-1.0e-5_real64) then
        j=0
      else
        j=int(1000.0_real64*(log10(-headtab(i))+1.0_real64))+4001
      end if
      if(j<0 .or. j>matabentries) error stop 'lookup bin out of range'
      ientrytab(1,j)=i
    end do

    ientrytab(1,1)=0
    do j=matabentries-1,1,-1
      if(ientrytab(1,j)==0) ientrytab(1,j)=ientrytab(1,j+1)
    end do

    call PreProcTabulatedFunction(1,ntab,xtab,theta_tab,dydx,sigma)
    do i=1,ntab
      sptab(4,1,i)=dydx(i)
      sptab(6,1,i)=sigma(i)
    end do
    call PreProcTabulatedFunction(2,ntab,xtab,logk_tab,dydx,sigma)
    do i=1,ntab
      sptab(5,1,i)=dydx(i)
      sptab(7,1,i)=sigma(i)
    end do

    cofgen(1,1)=0.0_real64
    cofgen(2,1)=osat
    cofgen(3,1)=ksat
  end subroutine setup_table

  subroutine find_wet_head(target,hout)
    real(real64),intent(in) :: target
    real(real64),intent(out) :: hout
    real(real64) :: lo,hi,mid,tth,tk
    integer :: iter
    lo=-1.0e7_real64
    hi=-1.0e-12_real64
    do iter=1,120
      mid=0.5_real64*(lo+hi)
      call constitutive(mid,tth,tk)
      if(tk<=target) then
        lo=mid
      else
        hi=mid
      end if
    end do
    hout=lo
  end subroutine find_wet_head

  subroutine constitutive(h,theta,k)
    real(real64),intent(in) :: h
    real(real64),intent(out) :: theta,k
    real(real64) :: help,theta_crit,relsat,term
    if(h>=0.0_real64) then
      theta=osat
    else if(h>hcrit) then
      help=abs(alfa*hcrit)**npar
      theta_crit=ores+(osat-ores)/(1.0_real64+help)**mpar
      theta=min(theta_crit+(osat-theta_crit)/(-hcrit)*(h-hcrit),osat)
    else
      theta=ores+(osat-ores)/(1.0_real64+abs(alfa*h)**npar)**mpar
    end if
    relsat=(theta-ores)/(osat-ores)
    if(h < -1.0e14_real64) then
      k=1.0e-10_real64
    else if(relsat>relsat_ksat) then
      k=ksat
    else
      term=(1.0_real64-relsat**(1.0_real64/mpar))**mpar
      k=min(ksat*relsat**lexp*(1.0_real64-term)**2,ksat)
    end if
  end subroutine constitutive

end program tabulated_hydraulics_wrapper_microbenchmark
