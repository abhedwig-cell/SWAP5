#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-r05-matrix-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/provider_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/solver/mod_b110_default_mvg_provider.f90").read_text()
needle="  public :: bind_b110_default_mvg_provider\n"
if needle not in src: raise SystemExit("provider public seam missing")
src=src.replace(needle,needle+"  public :: b110_hconduc\n",1)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/directional_base.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/solver/mod_b110_default_mvg_directional_provider.f90").read_text()
src=src.replace("module mod_b110_default_mvg_directional_provider",
                "module mod_b110_default_mvg_directional_provider_base",1)
src=src.replace("end module mod_b110_default_mvg_directional_provider",
                "end module mod_b110_default_mvg_directional_provider_base",1)
src=src.replace("evaluate_b110_default_mvg_state_direction",
                "evaluate_b110_default_mvg_state_direction_base")
src=src.replace("evaluate_b110_default_mvg_water_content_direction",
                "evaluate_b110_default_mvg_water_content_direction_base")
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/directional_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/solver/mod_b110_default_mvg_directional_provider.f90").read_text()
src=src.replace(
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, b110_hconduc",1)
src=src.replace(
"""  subroutine evaluate_b110_default_mvg_state_direction(provider, pressure_head, pressure_head_direction, &
                                                        water_content_direction, conductivity_direction, &
                                                        available, route)""",
"""  subroutine evaluate_b110_default_mvg_state_direction(provider, pressure_head, pressure_head_direction, &
                                                        water_content_direction, conductivity_direction, &
                                                        available, route, base_conductivity)""",1)
src=src.replace(
"    real(real64), intent(out) :: water_content_direction(:), conductivity_direction(:)\n",
"    real(real64), intent(out) :: water_content_direction(:), conductivity_direction(:)\n"
"    real(real64), intent(out), optional :: base_conductivity(:)\n",1)
src=src.replace(
"    real(real64) :: dthetadh, dkdh\n",
"    real(real64) :: theta, dthetadh, dkdh\n",1)
src=src.replace(
"    conductivity_direction = 0.0_real64\n",
"    conductivity_direction = 0.0_real64\n"
"    if (present(base_conductivity)) base_conductivity = 0.0_real64\n",1)
src=src.replace(
"       call b110_smooth_derivatives(provider%parameters%cofgen(:,i), pressure_head(i), dthetadh, dkdh, node_ok)\n",
"       call b110_smooth_derivatives(provider%parameters%cofgen(:,i), pressure_head(i), theta, dthetadh, dkdh, node_ok)\n",1)
src=src.replace(
"""       water_content_direction(i) = dthetadh * pressure_head_direction(i)
       conductivity_direction(i) = dkdh * pressure_head_direction(i)
""",
"""       if (present(base_conductivity)) then
          base_conductivity(i) = b110_hconduc(provider%parameters%cofgen(:,i), pressure_head(i), theta, &
               provider%parameters%ksatexm_extension_enabled)
       end if
       water_content_direction(i) = dthetadh * pressure_head_direction(i)
       conductivity_direction(i) = dkdh * pressure_head_direction(i)
""",1)
src=src.replace(
"""  subroutine b110_smooth_derivatives(c, head, dthetadh, dkdh, ok)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: dthetadh, dkdh""",
"""  subroutine b110_smooth_derivatives(c, head, theta, dthetadh, dkdh, ok)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: theta, dthetadh, dkdh""",1)
src=src.replace(
"    real(real64) :: theta, relsat, invm, one_minus_term, term1\n",
"    real(real64) :: relsat, invm, one_minus_term, term1\n",1)
src=src.replace(
"    dthetadh = 0.0_real64\n    dkdh = 0.0_real64\n",
"    theta = 0.0_real64\n    dthetadh = 0.0_real64\n    dkdh = 0.0_real64\n",1)
Path(sys.argv[1]).write_text(src)
PY

cat > "$BUILD/test.f90" <<'F90'
program test_dir01_repair05_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_default_mvg_directional_provider_base, only: evaluate_b110_default_mvg_state_direction_base
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  implicit none

  integer, parameter :: n=4
  character(len=3), parameter :: materials(4)=[character(len=3) :: 'B01','B12','O05','O14']
  character(len=3), parameter :: regimes(3)=[character(len=3) :: 'wet','mid','dry']
  real(real64), parameter :: regime_heads(3)=[-10.0_real64,-75.0_real64,-500.0_real64]
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h(n), hd(n), theta(n), kref(n), cap(n), dkdummy(n)
  real(real64) :: wbase(n), dbase(n), wfused(n), dfused(n), kfused(n)
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: provider
  character(len=64) :: rbase,rfused
  logical :: abase,afused
  integer :: im,ir,i
  real(real64) :: max_k_diff,max_w_diff,max_dk_diff

  hd=[0.25_real64,-0.5_real64,1.0_real64,-1.5_real64]

  do im=1,size(materials)
    call material_parameters(materials(im),tr,ts,alpha,nvg,ksat,lambda)
    allocate(cofgen(24,n)); cofgen=0.0_real64
    do i=1,n
      cofgen(1,i)=tr; cofgen(2,i)=ts; cofgen(3,i)=ksat
      cofgen(4,i)=alpha; cofgen(5,i)=lambda; cofgen(6,i)=nvg
      cofgen(7,i)=1.0_real64-1.0_real64/nvg; cofgen(8,i)=alpha
      cofgen(9,i)=0.0_real64; cofgen(10,i)=ksat; cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*ksat; cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(provider,hp,0.25_real64)

    do ir=1,size(regimes)
      h=regime_heads(ir)
      call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
           theta,kref,cap,dkdummy)
      call evaluate_b110_default_mvg_state_direction_base(provider,h,hd,wbase,dbase,abase,rbase)
      call evaluate_b110_default_mvg_state_direction(provider,h,hd,wfused,dfused,afused,rfused,kfused)

      if (abase .neqv. afused) error stop 'Repair05 availability drift'
      if (trim(rbase) /= trim(rfused)) error stop 'Repair05 route drift'
      if (.not. abase) error stop 'Repair05 production matrix unexpectedly nonsmooth'

      max_k_diff=maxval(abs(kfused-kref))
      max_w_diff=maxval(abs(wfused-wbase))
      max_dk_diff=maxval(abs(dfused-dbase))
      write(*,'(*(g0))') 'DIR01_R05_MATRIX|CASE=',materials(im),':',regimes(ir), &
           '|MAX_K_DIFF=',max_k_diff,'|MAX_WDIR_DIFF=',max_w_diff,'|MAX_KDIR_DIFF=',max_dk_diff, &
           '|K_BITS_EQUAL=',all_bits_equal(kfused,kref),'|WDIR_BITS_EQUAL=',all_bits_equal(wfused,wbase), &
           '|KDIR_BITS_EQUAL=',all_bits_equal(dfused,dbase)
      if (.not. all_bits_equal(kfused,kref)) error stop 'Repair05 base K not bit-identical'
      if (.not. all_bits_equal(wfused,wbase)) error stop 'Repair05 water direction not bit-identical'
      if (.not. all_bits_equal(dfused,dbase)) error stop 'Repair05 conductivity direction not bit-identical'
    end do
    deallocate(cofgen)
  end do

  ! Optional-result API must remain valid for existing callers.
  h=-75.0_real64
  call evaluate_b110_default_mvg_state_direction(provider,h,hd,wfused,dfused,afused,rfused)
  if (.not. afused) error stop 'Repair05 optional base K changed existing call semantics'

  print '(A)','FPE_DIR01_REPAIR05_EQUIVALENCE=PASS'

contains

  logical function all_bits_equal(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer(int64) :: ia(size(a)),ib(size(b))
    ia=transfer(a,ia); ib=transfer(b,ib)
    all_bits_equal=all(ia==ib)
  end function all_bits_equal

  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
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
  end subroutine material_parameters
end program test_dir01_repair05_equivalence
F90

gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD"   -c "$BUILD/provider_candidate.f90" -o "$BUILD/provider.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD"   -c "$BUILD/directional_base.f90" -o "$BUILD/directional_base.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD"   -c "$BUILD/directional_candidate.f90" -o "$BUILD/directional_candidate.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD"   -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/provider.o" "$BUILD/directional_base.o"   "$BUILD/directional_candidate.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
