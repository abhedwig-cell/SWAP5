#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile04-kernels-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/test.f90" <<'F90'
program test_fpe_profile04_kernel_costs
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use MOD_grid, only: numnod
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_reference_linear_solver, only: reference_tridag, reference_tridag_backsolve
  implicit none

  integer, parameter :: NREP_CONSTITUTIVE=500000, NREP_LINEAR=1000000
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: provider
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h(numnod), theta(numnod), k(numnod), c(numnod), dkdh(numnod)
  real(real64) :: a(numnod), b(numnod), cc(numnod), rhs(numnod), u(numnod), gamma(2*numnod)
  real(real64) :: t0,t1,full_ns,demand_ns,tridag_ns,backsolve_ns,checksum
  integer :: i,j,ierror,demand_mask

  allocate(cofgen(24,numnod))
  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=0.032_real64
    cofgen(2,i)=0.423_real64
    cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64
    cofgen(5,i)=0.365_real64
    cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64
    cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64
    cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(provider,hp,1.0e-4_real64)
  h=-75.0_real64

  checksum=0.0_real64
  call cpu_time(t0)
  do j=1,NREP_CONSTITUTIVE
    call provider%evaluate(h,theta,k,c,dkdh)
    checksum=checksum+theta(1)+k(numnod)+c(1)
  end do
  call cpu_time(t1)
  full_ns=1.0e9_real64*(t1-t0)/real(NREP_CONSTITUTIVE,real64)

  demand_mask=CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY+CONSTITUTIVE_DEMAND_CAPACITY
  call cpu_time(t0)
  do j=1,NREP_CONSTITUTIVE
    call provider%evaluate_demand(h,demand_mask,theta,k,c,dkdh)
    checksum=checksum+theta(numnod)+k(1)+c(numnod)
  end do
  call cpu_time(t1)
  demand_ns=1.0e9_real64*(t1-t0)/real(NREP_CONSTITUTIVE,real64)

  a=-1.0_real64; b=4.0_real64; cc=-1.0_real64; rhs=1.0_real64
  a(1)=0.0_real64; cc(numnod)=0.0_real64
  call reference_tridag(numnod,a,b,cc,rhs,u,gamma,ierror)
  if(ierror/=0) error stop 'PROFILE04 tridag setup failed'

  call cpu_time(t0)
  do j=1,NREP_LINEAR
    call reference_tridag(numnod,a,b,cc,rhs,u,gamma,ierror)
    if(ierror/=0) error stop 'PROFILE04 tridag failed'
    checksum=checksum+u(1)
  end do
  call cpu_time(t1)
  tridag_ns=1.0e9_real64*(t1-t0)/real(NREP_LINEAR,real64)

  call reference_tridag(numnod,a,b,cc,rhs,u,gamma,ierror)
  if(ierror/=0) error stop 'PROFILE04 factor capture failed'
  call cpu_time(t0)
  do j=1,NREP_LINEAR
    call reference_tridag_backsolve(numnod,a,rhs,gamma(1:numnod),gamma(numnod+1:2*numnod),u,ierror)
    if(ierror/=0) error stop 'PROFILE04 backsolve failed'
    checksum=checksum+u(numnod)
  end do
  call cpu_time(t1)
  backsolve_ns=1.0e9_real64*(t1-t0)/real(NREP_LINEAR,real64)

  write(*,'(*(g0))') 'PROFILE04_KERNEL|NODES=',numnod,'|CONSTITUTIVE_FULL_NS=',full_ns, &
       '|CONSTITUTIVE_DEMAND_NS=',demand_ns,'|TRIDAG_NS=',tridag_ns,'|BACKSOLVE_NS=',backsolve_ns, &
       '|CHECKSUM=',checksum
  write(*,'(A)') 'FPE_PROFILE04_KERNEL_COSTS=PASS'
end program test_fpe_profile04_kernel_costs
F90

COMMON=(-std=f2008 -ffree-line-length-none -O2)
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fsi/fsi04_real_headcalc_stubs.f90 -o "$BUILD/grid.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_reference_linear_solver.f90 -o "$BUILD/linear.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 "$BUILD/grid.o" "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/linear.o" "$BUILD/test.o" -o "$BUILD/test"

RESULT="$BUILD/results.txt"
: > "$RESULT"
for rep in 1 2 3 4 5; do
  "$BUILD/test" | tee -a "$RESULT"
done

python3 - "$RESULT" <<'PY'
import re,statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith('PROFILE04_KERNEL|'): continue
    d={}
    for part in line.strip().split('|')[1:]:
        k,v=part.split('=',1)
        d[k]=v
    rows.append(d)
if len(rows)!=5: raise SystemExit(f'expected 5 kernel rows, got {len(rows)}')
for key in ('CONSTITUTIVE_FULL_NS','CONSTITUTIVE_DEMAND_NS','TRIDAG_NS','BACKSOLVE_NS'):
    vals=[float(r[key]) for r in rows]
    print(f'PROFILE04_KERNEL_MEDIAN|{key}={statistics.median(vals):.6f}|MIN={min(vals):.6f}|MAX={max(vals):.6f}')
print('FPE_PROFILE04_KERNEL_AGGREGATE=PASS')
PY
