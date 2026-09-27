#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hydtable01-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/test_hydtable01_p0.f90" <<'F90'
program test_hydtable01_p0
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  implicit none

  integer, parameter :: NCAL=12001, NBENCH=4096, NREP=300
  integer, parameter :: NRES=5
  integer, parameter :: RES(NRES)=[64,128,256,512,1024]
  character(len=3), parameter :: MATERIALS(4)=[character(len=3)::'B01','B12','O05','O14']
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  real(real64), allocatable :: cofgen(:,:), xgrid(:), ygrid(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda
  real(real64) :: h,ka,kt,dka,dkt,relk,reld,denomk,denomd
  real(real64) :: maxrelk,maxreld,maxabsk,maxabsd,build0,build1,t0,t1
  real(real64) :: checksum_a,checksum_t, analytical_k_seconds, table_k_seconds
  real(real64) :: analytical_kd_seconds, table_kd_seconds
  real(real64) :: hs(1),dirs(1),dw(1),dk(1),basek(1)
  real(real64) :: bench_h(NBENCH)
  character(len=128) :: route
  logical :: ok,avail,mono
  integer :: m,r,n,i,j,idx
  integer :: fallback_count

  do m=1,size(MATERIALS)
    call material(trim(MATERIALS(m)),tr,ts,alpha,nvg,ksat,lambda)
    allocate(cofgen(24,1)); cofgen=0.0_real64
    cofgen(1,1)=tr; cofgen(2,1)=ts; cofgen(3,1)=ksat
    cofgen(4,1)=alpha; cofgen(5,1)=lambda; cofgen(6,1)=nvg
    cofgen(7,1)=1.0_real64-1.0_real64/nvg; cofgen(8,1)=alpha
    cofgen(9,1)=0.0_real64; cofgen(10,1)=ksat; cofgen(11,1)=0.999_real64
    cofgen(12,1)=0.99_real64*ksat; cofgen(22,1)=-1.0e6_real64; cofgen(23,1)=1.0e-12_real64
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(analytical,hp,0.25_real64)

    do i=1,NBENCH
      bench_h(i)=-exp(log(1.0_real64)+(real(i-1,real64)/real(NBENCH-1,real64))*log(1.0e6_real64))
    end do

    do r=1,NRES
      n=RES(r)
      allocate(xgrid(n),ygrid(n))
      call cpu_time(build0)
      call build_table(n,hp,xgrid,ygrid,mono)
      call cpu_time(build1)
      if(.not.mono) error stop 'HYDTABLE01 monotonicity failed during build'

      maxrelk=0.0_real64; maxreld=0.0_real64
      maxabsk=0.0_real64; maxabsd=0.0_real64
      fallback_count=0
      do i=1,NCAL
        h=-exp(log(1.0_real64)+(real(i-1,real64)/real(NCAL-1,real64))*log(1.0e6_real64))
        call analytical_pair(analytical,h,ka,dka,ok)
        if(.not.ok) then
          fallback_count=fallback_count+1
          cycle
        end if
        call table_pair(h,xgrid,ygrid,kt,dkt,ok)
        if(.not.ok) error stop 'HYDTABLE01 table unexpectedly unavailable'
        if(kt<0.0_real64) error stop 'HYDTABLE01 negative K'
        denomk=max(abs(ka),1.0e-12_real64*ksat)
        denomd=max(abs(dka),1.0e-12_real64*ksat)
        relk=abs(kt-ka)/denomk
        reld=abs(dkt-dka)/denomd
        maxrelk=max(maxrelk,relk); maxreld=max(maxreld,reld)
        maxabsk=max(maxabsk,abs(kt-ka)); maxabsd=max(maxabsd,abs(dkt-dka))
      end do

      checksum_a=0.0_real64
      call cpu_time(t0)
      do j=1,NREP
        do i=1,NBENCH
          call evaluate_b110_default_mvg_conductivity(hp,1,bench_h(i),ka,ok)
          if(.not.ok) error stop 'HYDTABLE01 analytical K benchmark unavailable'
          checksum_a=checksum_a+ka
        end do
      end do
      call cpu_time(t1)
      analytical_k_seconds=t1-t0

      checksum_t=0.0_real64
      call cpu_time(t0)
      do j=1,NREP
        do i=1,NBENCH
          call table_pair(bench_h(i),xgrid,ygrid,kt,dkt,ok)
          if(.not.ok) error stop 'HYDTABLE01 table K benchmark unavailable'
          checksum_t=checksum_t+kt
        end do
      end do
      call cpu_time(t1)
      table_k_seconds=t1-t0

      checksum_a=0.0_real64
      call cpu_time(t0)
      do j=1,NREP
        do i=1,NBENCH
          call analytical_pair(analytical,bench_h(i),ka,dka,ok)
          if(.not.ok) error stop 'HYDTABLE01 analytical KD benchmark unavailable'
          checksum_a=checksum_a+ka+dka
        end do
      end do
      call cpu_time(t1)
      analytical_kd_seconds=t1-t0

      checksum_t=0.0_real64
      call cpu_time(t0)
      do j=1,NREP
        do i=1,NBENCH
          call table_pair(bench_h(i),xgrid,ygrid,kt,dkt,ok)
          if(.not.ok) error stop 'HYDTABLE01 table KD benchmark unavailable'
          checksum_t=checksum_t+kt+dkt
        end do
      end do
      call cpu_time(t1)
      table_kd_seconds=t1-t0

      write(*,'(*(g0))') 'HYDTABLE01_P0|MATERIAL=',trim(MATERIALS(m)), &
        '|N=',n,'|BUILD_US=',1.0e6_real64*(build1-build0), &
        '|MAX_REL_K=',maxrelk,'|MAX_REL_DKDH=',maxreld, &
        '|MAX_ABS_K=',maxabsk,'|MAX_ABS_DKDH=',maxabsd, &
        '|FALLBACK_POINTS=',fallback_count, &
        '|K_RATIO=',table_k_seconds/analytical_k_seconds, &
        '|KD_RATIO=',table_kd_seconds/analytical_kd_seconds, &
        '|MONOTONE=',mono
      deallocate(xgrid,ygrid)
    end do
    deallocate(cofgen)
    if(allocated(hp%cofgen)) deallocate(hp%cofgen)
  end do
  write(*,'(A)') 'FPE_HYDTABLE01_P0=PASS'

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
      error stop 'unknown material'
    end select
  end subroutine material

  subroutine build_table(n,p,x,y,mono)
    integer,intent(in)::n
    type(b110_default_mvg_parameters_t),intent(in)::p
    real(real64),intent(out)::x(n),y(n)
    logical,intent(out)::mono
    real(real64)::h,k
    logical::local_ok
    integer::q
    do q=1,n
      x(q)=log(1.0_real64)+(real(q-1,real64)/real(n-1,real64))*log(1.0e6_real64)
      h=-exp(x(q))
      call evaluate_b110_default_mvg_conductivity(p,1,h,k,local_ok)
      if(.not.local_ok .or. k<=0.0_real64) error stop 'table build analytical K invalid'
      y(q)=log(k)
    end do
    mono=.true.
    do q=2,n
      if(y(q)>y(q-1)+64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(y(q-1)))) mono=.false.
    end do
  end subroutine build_table

  subroutine table_pair(h,x,y,k,dkdh,ok)
    real(real64),intent(in)::h,x(:),y(:)
    real(real64),intent(out)::k,dkdh
    logical,intent(out)::ok
    real(real64)::xx,t,slope,yy,dx
    integer::q,n
    ok=.false.; k=0.0_real64; dkdh=0.0_real64
    if(h>-1.0_real64 .or. h < -1.0e6_real64) return
    n=size(x); xx=log(-h); dx=x(n)-x(1)
    q=1+int((xx-x(1))*real(n-1,real64)/dx)
    q=max(1,min(n-1,q))
    t=(xx-x(q))/(x(q+1)-x(q))
    t=max(0.0_real64,min(1.0_real64,t))
    yy=(1.0_real64-t)*y(q)+t*y(q+1)
    slope=(y(q+1)-y(q))/(x(q+1)-x(q))
    k=exp(yy)
    dkdh=k*slope/h
    ok=(k>=0.0_real64)
  end subroutine table_pair

  subroutine analytical_pair(provider,h,k,dkdh,ok)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::h
    real(real64),intent(out)::k,dkdh
    logical,intent(out)::ok
    hs(1)=h; dirs(1)=1.0_real64
    call evaluate_b110_default_mvg_state_direction(provider,hs,dirs,dw,dk,avail,route,basek)
    if(.not.avail) then
      ok=.false.; k=0.0_real64; dkdh=0.0_real64; return
    end if
    k=basek(1); dkdh=dk(1); ok=.true.
  end subroutine analytical_pair
end program test_hydtable01_p0
F90

gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_b110_default_mvg_directional_provider.f90 -o "$BUILD/dir.o"
gfortran -std=f2008 -ffree-line-length-none -O3 -J "$BUILD" -I "$BUILD"   -c "$BUILD/test_hydtable01_p0.f90" -o "$BUILD/test.o"
gfortran -O3 "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/dir.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" | tee "$BUILD/result.txt"
grep -q '^FPE_HYDTABLE01_P0=PASS$' "$BUILD/result.txt"

python3 - "$BUILD/result.txt" <<'PY'
import re,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("HYDTABLE01_P0|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=20: raise SystemExit(f"expected 20 frontier rows, got {len(rows)}")
for n in (64,128,256,512,1024):
    rr=[r for r in rows if int(r["N"])==n]
    max_k=max(float(r["MAX_REL_K"]) for r in rr)
    max_d=max(float(r["MAX_REL_DKDH"]) for r in rr)
    med_kr=sorted(float(r["K_RATIO"]) for r in rr)[1:3]
    med_dr=sorted(float(r["KD_RATIO"]) for r in rr)[1:3]
    med_k=sum(med_kr)/2
    med_d=sum(med_dr)/2
    print(f"HYDTABLE01_P0_FRONTIER|N={n}|MAX_REL_K={max_k:.9e}|MAX_REL_DKDH={max_d:.9e}|MEDIAN4_K_RATIO={med_k:.6f}|MEDIAN4_KD_RATIO={med_d:.6f}")
PY
