#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
BASE="42b11df9b863afe9bfe2c24a6556293c04bbe555"
CLOSEOUT="70a66a768e64760ecfd43702535a848b6d834d61"
EXPECTED_BLOB="1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"
PATH_CAND="src/process/mod_drainage_spatial_distribution.f90"
BUILD="${FVQ47_BUILD_DIR:-$ROOT/build/fvq47}"
rm -rf "$BUILD"; mkdir -p "$BUILD/mod_o0" "$BUILD/mod_o2"

git cat-file -e "${CLOSEOUT}^{commit}"
git show "${CLOSEOUT}:${PATH_CAND}" > "$BUILD/candidate.f90"
ACTUAL_BLOB="$(git hash-object "$BUILD/candidate.f90")"
[[ "$ACTUAL_BLOB" == "$EXPECTED_BLOB" ]] || { echo "F-VQ47 FAIL candidate blob $ACTUAL_BLOB" >&2; exit 20; }
if ! git diff --quiet "$BASE" HEAD -- src reference; then
  echo "F-VQ47 FAIL: qualification branch has src/ or reference/ delta" >&2
  git diff --name-status "$BASE" HEAD -- src reference >&2
  exit 21
fi
python3 -m py_compile integration/f-vq/fvq47/legacy_divdra_oracle.py integration/f-vq/fvq47/verify_fvq47.py

cat > "$BUILD/mod_process_hydraulic_view_stub.f90" <<'F90'
module mod_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type :: process_hydraulic_view_t
    real(real64) :: groundwater_level = 0.0_real64
  end type process_hydraulic_view_t
end module mod_process_hydraulic_view
F90
cat > "$BUILD/candidate_driver.f90" <<'F90'
program fvq47_candidate_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
      drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra
  implicit none
  type(drainage_distribution_parameters_t) :: p
  type(drainage_node_transfer_t) :: out
  type(drainage_distribution_diagnostics_t) :: d
  type(process_hydraulic_view_t) :: h
  integer :: ncase,c,n,i,case_id,ev,zt
  real(real64) :: q,gw,spacing,cumulative
  read(*,*) ncase
  do c=1,ncase
    read(*,*) case_id,n,q,gw,spacing
    p%active_nodes=n
    allocate(p%dz(n),p%zbotcp(n),p%saturated_conductivity(n),p%horizontal_anisotropy_factor(n))
    cumulative=0.0_real64
    do i=1,n
      read(*,*) p%dz(i),p%saturated_conductivity(i),p%horizontal_anisotropy_factor(i)
      cumulative=cumulative+p%dz(i); p%zbotcp(i)=-cumulative
    end do
    p%drain_spacing=spacing; h%groundwater_level=gw
    call distribute_single_level_positive_divdra(p,h,q,out,d)
    ev=merge(1,0,d%evaluated); zt=merge(1,0,d%zero_transfer)
    write(*,'(A,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,9(ES26.17E3,1X),I0)') &
      'CASE',case_id,d%status,ev,zt,d%water_table_node,d%discharge_bottom_node, &
      d%groundwater_depth,d%saturated_top_thickness,d%discharge_bottom_thickness, &
      d%profile_anisotropy_factor,d%discharge_layer_bottom_depth,d%discharge_transmissivity, &
      d%raw_partition_sum,d%closure_correction,q,n
    if (allocated(out%soil_to_drain_rate)) then
      write(*,'(A,1X,I0,1X,*(ES26.17E3,1X))') 'NODES',case_id,out%soil_to_drain_rate
    else
      write(*,'(A,1X,I0)') 'NODES',case_id
    end if
    if (allocated(p%dz)) deallocate(p%dz)
    if (allocated(p%zbotcp)) deallocate(p%zbotcp)
    if (allocated(p%saturated_conductivity)) deallocate(p%saturated_conductivity)
    if (allocated(p%horizontal_anisotropy_factor)) deallocate(p%horizontal_anisotropy_factor)
    if (allocated(out%soil_to_drain_rate)) deallocate(out%soil_to_drain_rate)
  end do
end program fvq47_candidate_driver
F90

COMMON=( -std=f2008 -ffree-line-length-none )
gfortran "${COMMON[@]}" -O0 -J"$BUILD/mod_o0" -I"$BUILD/mod_o0" "$BUILD/mod_process_hydraulic_view_stub.f90" "$BUILD/candidate.f90" "$BUILD/candidate_driver.f90" -o "$BUILD/candidate_o0"
gfortran "${COMMON[@]}" -O2 -J"$BUILD/mod_o2" -I"$BUILD/mod_o2" "$BUILD/mod_process_hydraulic_view_stub.f90" "$BUILD/candidate.f90" "$BUILD/candidate_driver.f90" -o "$BUILD/candidate_o2"
CANDIDATE_O0="$BUILD/candidate_o0" CANDIDATE_O2="$BUILD/candidate_o2" FVQ47_SUMMARY="$BUILD/F-VQ47_SUMMARY.json" FVQ47_RAW_O0="$BUILD/F-VQ47_O0.txt" FVQ47_RAW_O2="$BUILD/F-VQ47_O2.txt" python3 integration/f-vq/fvq47/verify_fvq47.py | tee "$BUILD/verifier_stdout.jsonl"
SUMMARY_SHA256="$(sha256sum "$BUILD/F-VQ47_SUMMARY.json" | awk '{print $1}')"
echo "F_VQ47_CANDIDATE_BLOB=$ACTUAL_BLOB"
echo "F_VQ47_SUMMARY_SHA256=$SUMMARY_SHA256"
echo "F_VQ47_DECISION=PASS_INDEPENDENT_REQUALIFICATION_GATE"
