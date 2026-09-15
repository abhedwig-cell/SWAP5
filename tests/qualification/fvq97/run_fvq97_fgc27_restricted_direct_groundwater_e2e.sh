#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

CANONICAL_BASE=5e4386f06a230c71eba103fd8e12fec97e7fae6d
FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
FVQ95_AUTH=da64ffb1f4cd5105e2809a02ddae02f50a9c853b
FVQ86_AUTH=0fea1f7a17ccff9f41b4d2dee71feab526313a01
FVQ96_AUTH=ae97f0d47c183a64e470be5badca220d95a65cb0

# F-VQ97 is qualification-only. Production must remain exactly the live
# canonical post-F-GC26 image throughout this workunit.
allowed=(
  ".github/workflows/f-vq97-fgc27-restricted-direct-groundwater-e2e.yml"
  "qualification/F-VQ97_STATUS.json"
  "tests/qualification/fvq97/F-VQ97_RECONCILE_CHECKPOINT.json"
  "tests/qualification/fvq97/F-VQ97_QUALIFY_CHECKPOINT.json"
  "tests/qualification/fvq97/run_fvq97_fgc27_restricted_direct_groundwater_e2e.sh"
  "tests/qualification/fvq97/test_fvq97_fgc27_restricted_direct_groundwater_e2e.f90"
)
mapfile -t changed < <(git diff --name-only "$CANONICAL_BASE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then ok=1; break; fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "FVQ97_SCOPE_FAIL unexpected path: $path" >&2
    exit 20
  fi
done
echo 'FVQ97_ZERO_PRODUCTION_DELTA=PASS'

# Pin the complete restricted v1 composition surface used by F-GC27.
declare -A PINNED=(
  [src/runtime/mod_groundwater_predictor_corrector_window.f90]=fa2a5a45d558fbaaea242438915cdb7420b6503c
  [src/runtime/mod_groundwater_tile_aggregation.f90]=d62ecba039d9bef178acde6900b81e9d5b0931eb
  [src/runtime/mod_groundwater_accuracy_binding.f90]=b8ac03e810c73519b433f7851c6fd143ba26676a
  [src/runtime/mod_groundwater_coupling_response.f90]=645141676536ae8289b9d52433798a965c7baa04
  [src/runtime/mod_groundwater_coupled_restart.f90]=0596933ff3ae89c61ab7a0913189a4fa3179e50b
  [src/runtime/mod_groundwater_multiswap_coupler.f90]=f2bf0e7d144fd3c0b9dc18f24f24eb4ffb7ffa0f
  [src/adapter/mod_groundwater_external_gateway.f90]=f307f17e2fd20983432f91e91ac90aaae8311849
  [src/runtime/mod_groundwater_coupling_contract.f90]=fc598d14eabafcb025bb55621f7b00d6d1816f10
  [src/runtime/mod_groundwater_exchange_service_contract.f90]=e99ae052fccd9992b76c12a91422a987dce059e2
  [src/runtime/mod_coupling_application_accuracy_contract.f90]=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
)
for path in "${!PINNED[@]}"; do
  actual="$(git rev-parse "HEAD:$path")"
  expected="${PINNED[$path]}"
  if [[ "$actual" != "$expected" ]]; then
    echo "FVQ97_PIN_FAIL $path expected=$expected actual=$actual" >&2
    exit 21
  fi
  echo "FVQ97_PIN $path=$actual"
done
echo 'FVQ97_CURRENT_CANONICAL_STACK_PINNED=PASS'

# Inherited independent authorities are evidence only. They are reusable because
# the production blobs they qualified are still byte-identical on current canonical.
git cat-file -e "$FVQ95_AUTH^{commit}"
git cat-file -e "$FVQ86_AUTH^{commit}"
git cat-file -e "$FVQ96_AUTH^{commit}"
python3 - "$FVQ95_AUTH" "$FVQ86_AUTH" <<'PY'
import json, subprocess, sys
vq95, vq86 = sys.argv[1:]

def show(commit, path):
    return subprocess.check_output(['git','show',f'{commit}:{path}'], text=True)

s95=json.loads(show(vq95,'qualification/F-VQ95_STATUS.json'))
assert s95['conclusion']=='success'
assert s95['production_source_blob']=='645141676536ae8289b9d52433798a965c7baa04'
assert s95['evidence']['accepted_whole_window_only'] is True
assert s95['evidence']['rejected_retry_zero_contribution'] is True
assert s95['evidence']['o0_o2_identity'] is True

s86=json.loads(show(vq86,'qualification/F-VQ86_STATUS.json'))
assert s86['workflow']['conclusion']=='success'
assert s86['qualified_source_blobs']['src/runtime/mod_groundwater_coupled_restart.f90']=='0596933ff3ae89c61ab7a0913189a4fa3179e50b'
assert s86['evidence_markers']['FVQ86_INDEPENDENT_ORACLE_O0_O2_IDENTITY']=='PASS'
assert s86['evidence_markers']['FVQ86_NO_IO_CALENDAR_MODFLOW_DEPENDENCY']=='PASS'
PY
echo 'FVQ97_FGC23_FGC24_IMMUTABLE_INDEPENDENT_EVIDENCE_REUSED=PASS'

test "$(git rev-parse "$FVQ96_AUTH:src/adapter/mod_groundwater_external_gateway.f90")" = \
  f307f17e2fd20983432f91e91ac90aaae8311849
echo 'FVQ97_FGC26_INDEPENDENT_AUTHORITY_LOCKED=PASS'

# Architecture boundaries: GC21 must consume the abstract exchange service, while
# the backend-specific type stays in the adapter layer. F-GC23 stays a separate
# accepted-trajectory composition and is not smuggled into the GC21 loop.
if grep -Eq 'external_groundwater_backend_t|groundwater_external_gateway_t' \
    src/runtime/mod_groundwater_predictor_corrector_window.f90 \
    src/runtime/mod_groundwater_multiswap_coupler.f90; then
  echo 'FVQ97_BACKEND_TYPE_LEAK=FAIL' >&2
  exit 22
fi
if grep -Eq 'compose_groundwater_coupling_response|mod_groundwater_coupling_response' \
    src/runtime/mod_groundwater_predictor_corrector_window.f90; then
  echo 'FVQ97_FGC23_OWNERSHIP=FAIL response composition folded into GC21' >&2
  exit 23
fi
if grep -Eiq '(^|[^a-z])(open|read|write)[[:space:]]*\(' src/adapter/mod_groundwater_external_gateway.f90; then
  echo 'FVQ97_GATEWAY_FILE_IO=FAIL' >&2
  exit 24
fi
echo 'FVQ97_ARCHITECTURE_BOUNDARIES=PASS'

work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# Reuse only SWAP-side fixture TYPES from the exact F-GC21 owner authority. The
# groundwater backend and all F-VQ97 sequences/assertions are independent.
git cat-file -e "$FGC21_OWNER^{commit}"
python3 - "$FGC21_OWNER" "$work/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]
out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
echo 'FVQ97_PINNED_SWAP_FIXTURE_TYPES=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_coupling_application_accuracy_contract.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_accuracy_binding.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_groundwater_multiswap_topology.f90
  src/runtime/mod_groundwater_multiswap_swap_phase.f90
  src/runtime/mod_groundwater_multiswap_transaction.f90
  src/runtime/mod_groundwater_multiswap_publication.f90
  src/runtime/mod_groundwater_multiswap_coupler.f90
  src/adapter/mod_groundwater_external_gateway.f90
  "$work/fgc21_fixture.f90"
  tests/qualification/fvq97/test_fvq97_fgc27_restricted_direct_groundwater_e2e.f90
)

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${SOURCES[@]}" -o "$dir/fvq97" \
      2>"$dir/compiler.txt"; then
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  # compare-reals warnings are known in pinned fixtures/tests; all other warnings fail.
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/fvq97" > "$out"
}

compile_and_run 0 "$work/o0.txt"
compile_and_run 2 "$work/o2.txt"

for marker in \
  FVQ97_FGC22_POLICY_BINDING_IN_EXECUTION=PASS \
  FVQ97_DIRECT_GC21_GC26_E2E=PASS \
  FVQ97_EXTERNAL_FAILURE_FAILS_CLOSED=PASS \
  FVQ97_NO_SAME_WINDOW_RETRY=PASS \
  FVQ97_MULTISWAP_GC20_GC25_GC26_E2E=PASS \
  FVQ97_SHARED_BACKEND_NO_CROSSTALK_E2E=PASS \
  FVQ97_INDEPENDENT_E2E_ORACLE=PASS; do
  grep -qx "$marker" "$work/o0.txt"
done

diff -u "$work/o0.txt" "$work/o2.txt"
cat "$work/o0.txt"
echo "FVQ97_ORACLE_SHA256=$(sha256sum "$work/o0.txt" | awk '{print $1}')"
echo 'FVQ97_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-VQ97 F-GC27 RESTRICTED DIRECT-GROUNDWATER E2E QUALIFICATION GATE PASS'
