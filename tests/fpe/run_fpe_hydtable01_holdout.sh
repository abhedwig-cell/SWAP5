#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hydtable01-holdout-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/test.f90" <<'F90'
program test_hydtable01_holdout
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  implicit none
  integer, parameter :: NTAB=1024, NH=16007, NB=4096, NREP=200
  character(len=3), parameter :: MATERIALS(4)=[character(len=3)::'B01','B12','O05','O14']
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: provider
  real(real64), allocatable :: cofgen(:,:), x(:), y(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h,ka,kt,dka,dkt,denom
  real(real64) :: maxrk,maxrd,t0,t1,ta,tt,ca,ct,frac
  real(real64) :: hs(1),dir(1),dw(1),dk(1),basek(1),bh(NB)
  character(len=128) :: route
  logical :: ok,avail,mono,probe_ok
  integer :: m,i,j,q
  real(real64), parameter :: GOLD=0.6180339887498948482_real64

  do m=1,4
    call material(trim(MATERIALS(m)),tr,ts,alpha,nvg,ksat,lambda)
    allocate(cofgen(24,1)); cofgen=0.0_real64
    cofgen(1,1)=tr; cofgen(2,1)=ts; cofgen(3,1)=ksat; cofgen(4,1)=alpha
    cofgen(5,1)=lambda; cofgen(6,1)=nvg; cofgen(7,1)=1.0_real64-1.0_real64/nvg
    cofgen(8,1)=alpha; cofgen(9,1)=0.0_real64; cofgen(10,1)=ksat
    cofgen(11,1)=0.999_real64; cofgen(12,1)=0.99_real64*ksat
    cofgen(22,1)=-1.0e6_real64; cofgen(23,1)=1.0e-12_real64
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(provider,hp,0.25_real64)
    allocate(x(NTAB),y(NTAB))
    call build_table(hp,x,y,mono)
    if(.not.mono) error stop 'holdout table nonmonotone'

    maxrk=0.0_real64; maxrd=0.0_real64
    do i=1,NH
      frac=mod(real(i,real64)*GOLD,1.0_real64)
      h=-exp(frac*log(1.0e6_real64))
      call analytical_pair(provider,h,ka,dka,ok)
      if(.not.ok) error stop 'holdout analytical unavailable'
      call table_pair(h,x,y,kt,dkt,ok)
      if(.not.ok) error stop 'holdout table unavailable inside domain'
      if(.not.(kt>=0.0_real64)) error stop 'holdout negative K'
      denom=max(abs(ka),1.0e-12_real64*ksat)
      maxrk=max(maxrk,abs(kt-ka)/denom)
      denom=max(abs(dka),1.0e-12_real64*ksat)
      maxrd=max(maxrd,abs(dkt-dka)/denom)
    end do

    probe_ok=.true.
    call table_pair(-0.999999_real64,x,y,kt,dkt,ok); probe_ok=probe_ok .and. (.not.ok)
    call table_pair(-1.000001_real64,x,y,kt,dkt,ok); probe_ok=probe_ok .and. ok
    call table_pair(-999999.0_real64,x,y,kt,dkt,ok); probe_ok=probe_ok .and. ok
    call table_pair(-1000001.0_real64,x,y,kt,dkt,ok); probe_ok=probe_ok .and. (.not.ok)
    if(.not.probe_ok) error stop 'holdout fallback boundary probe failed'

    do i=1,NB
      frac=(real(i,real64)-0.37_real64)/real(NB,real64)
      bh(i)=-exp(frac*log(1.0e6_real64))
    end do
    ca=0.0_real64; call cpu_time(t0)
    do j=1,NREP
      do i=1,NB
        call evaluate_b110_default_mvg_conductivity(hp,1,bh(i),ka,ok)
        if(.not.ok) error stop 'analytical speed unavailable'
        ca=ca+ka
      end do
    end do
    call cpu_time(t1); ta=t1-t0

    ct=0.0_real64; call cpu_time(t0)
    do j=1,NREP
      do i=1,NB
        call table_pair(bh(i),x,y,kt,dkt,ok)
        if(.not.ok) error stop 'table speed unavailable'
        ct=ct+kt
      end do
    end do
    call cpu_time(t1); tt=t1-t0

    write(*,'(*(g0))') 'HYDTABLE01_HOLDOUT|MATERIAL=',trim(MATERIALS(m)), &
      '|MAX_REL_K=',maxrk,'|MAX_REL_DKDH=',maxrd,'|K_RATIO=',tt/ta, &
      '|BOUNDARY_FALLBACK=',probe_ok,'|MONOTONE=',mono

    if(maxrk>1.0e-4_real64) error stop 'holdout K gate'
    if(maxrd>1.5e-2_real64) error stop 'holdout dKdh gate'
    if(tt>=ta) error stop 'holdout speed gate'

    deallocate(x,y,cofgen)
    if(allocated(hp%cofgen)) deallocate(hp%cofgen)
  end do
  write(*,'(A)') 'FPE_HYDTABLE01_HOLDOUT=PASS'

contains
  subroutine material(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop
    end select
  end subroutine material

  subroutine build_table(p,x,y,mono)
    type(b110_default_mvg_parameters_t),intent(in)::p
    real(real64),intent(out)::x(:),y(:)
    logical,intent(out)::mono
    real(real64)::h,k
    logical::lok
    integer::i,n
    n=size(x)
    do i=1,n
      x(i)=real(i-1,real64)/real(n-1,real64)*log(1.0e6_real64)
      h=-exp(x(i))
      call evaluate_b110_default_mvg_conductivity(p,1,h,k,lok)
      if(.not.lok .or. k<=0.0_real64) error stop 'build'
      y(i)=log(k)
    end do
    mono=.true.
    do i=2,n
      if(y(i)>y(i-1)+1.0e-13_real64) mono=.false.
    end do
  end subroutine build_table

  subroutine table_pair(h,x,y,k,dkdh,ok)
    real(real64),intent(in)::h,x(:),y(:)
    real(real64),intent(out)::k,dkdh
    logical,intent(out)::ok
    real(real64)::xx,f,slope,yy
    integer::i,n
    k=0.0_real64; dkdh=0.0_real64; ok=.false.
    if(h>-1.0_real64 .or. h < -1.0e6_real64) return
    n=size(x); xx=log(-h)
    i=1+int(xx*real(n-1,real64)/log(1.0e6_real64))
    i=max(1,min(n-1,i))
    f=(xx-x(i))/(x(i+1)-x(i)); f=max(0.0_real64,min(1.0_real64,f))
    yy=(1.0_real64-f)*y(i)+f*y(i+1)
    slope=(y(i+1)-y(i))/(x(i+1)-x(i))
    k=exp(yy); dkdh=k*slope/h; ok=(k>=0.0_real64)
  end subroutine table_pair

  subroutine analytical_pair(provider,h,k,dkdh,ok)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::h
    real(real64),intent(out)::k,dkdh
    logical,intent(out)::ok
    hs(1)=h; dir(1)=1.0_real64
    call evaluate_b110_default_mvg_state_direction(provider,hs,dir,dw,dk,avail,route,basek)
    if(.not.avail) then
      k=0.0_real64; dkdh=0.0_real64; ok=.false.
    else
      k=basek(1); dkdh=dk(1); ok=.true.
    end if
  end subroutine analytical_pair
end program test_hydtable01_holdout
F90

gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_b110_default_mvg_directional_provider.f90 -o "$BUILD/dir.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O3 "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/dir.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
