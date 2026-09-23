#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI109_GATE_FAIL $*" >&2; exit 109; }

CANONICAL=a2d99ddd149ffaa422d9c422f96bd66e92c8555d
SUBJECT=ba3699f970d48b6b15db24fac1d1ec619f7fcb32

git cat-file -e "$CANONICAL^{commit}"
git cat-file -e "$SUBJECT^{commit}"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail "admission head not descended from frozen canonical"

mapfile -t changed < <(git diff --name-only "$CANONICAL..HEAD" -- src | sort)
expected=(
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90
  src/runtime/mod_fmr_surface_water_swap_participant.f90
)
mapfile -t expected_sorted < <(printf '%s\n' "${expected[@]}" | sort)
[[ "${changed[*]}" == "${expected_sorted[*]}" ]] || {
  printf 'observed src delta:\n%s\n' "${changed[*]}" >&2
  fail "src delta is not exact five-file F-APP09 postimage"
}
echo 'FCI109_EXACT_FIVE_FILE_PRODUCTION_DELTA=PASS'

declare -A BLOBS=(
  [src/process/mod_drainage_extended_exchange.f90]=25d76013d25c2eaa2d254865149c740bc3257617
  [src/runtime/mod_fmr_drainage_response_binding.f90]=263cf55b2c336d149ba41b4d04f510e10c4207e2
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0cdf05c1fc066f80aad7807c35a4e718fdecdb09
  [src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90]=1029cd4658a28f4aaf21db3cd480872c2d17722a
  [src/runtime/mod_fmr_surface_water_swap_participant.f90]=5fd5007cf8e523d3b2cd4236114e887d0c383f0a
)
for p in "${!BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${BLOBS[$p]}" ]] || fail "postimage drift $p"
  [[ "$(git rev-parse "$SUBJECT:$p")" == "${BLOBS[$p]}" ]] || fail "subject authority drift $p"
done
echo 'FCI109_FAPP09_FVQ128_POSTIMAGES=PASS'

bash tests/fapp/run_fapp09_ribasim_external_surface_water_profile.sh | tee /tmp/fci109-owner.txt
grep -Fq 'F-APP09 OWNER GATE PASS' /tmp/fci109-owner.txt || fail "F-APP09 owner replay"

bash tests/fvq/run_fvq128_fapp09_independent.sh | tee /tmp/fci109-vq.txt
grep -Fq 'F-VQ128 INDEPENDENT QUALIFICATION PASS' /tmp/fci109-vq.txt || fail "F-VQ128 replay"

git diff --check "$CANONICAL..HEAD"
echo 'FCI109_OWNER_REPLAY=PASS'
echo 'FCI109_INDEPENDENT_REPLAY=PASS'
echo 'F-CI109 FAPP09 CANONICAL ADMISSION GATE PASS'
