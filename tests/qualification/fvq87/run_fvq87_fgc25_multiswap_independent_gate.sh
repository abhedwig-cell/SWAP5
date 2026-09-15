#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

OWNER_HEAD=43c9f09110dea83928ef7d58990c37575d8ca223
FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
FGC20_AUTH=54dc9cc930468d9f376f596fe2c1b6f45938b59b
FGC22_AUTH=c50f3770ae8e4bee7c276a080be00156218944f1
FGC20_BLOB=d62ecba039d9bef178acde6900b81e9d5b0931eb
FGC22_BLOB=b8ac03e810c73519b433f7851c6fd143ba26676a
GC22_TEMPORAL_AUTH_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e

allowed=(
  ".github/workflows/fvq87-fgc25-multiswap-independent.yml"
  "qualification/F-VQ87_STATUS.json"
  "tests/qualification/fvq87/run_fvq87_fgc25_multiswap_independent_gate.sh"
  "tests/qualification/fvq87/test_fvq87_fgc25_multiswap_independent.f90"
)

mapfile -t changed < <(git diff --name-only "$OWNER_HEAD..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then
      ok=1
      break
    fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "FVQ87_SCOPE_FAIL unexpected path: $path" >&2
    exit 20
  fi
done
echo 'FVQ87_SCOPE_ALLOWLIST=PASS'

# F-VQ87 is verification-only. No GC25 production or owner-test path may change
# relative to the exact owner-qualified source head.
for path in \
  src/runtime/mod_groundwater_tile_aggregation.f90 \
  src/runtime/mod_groundwater_accuracy_binding.f90 \
  src/runtime/mod_groundwater_multiswap_coupler.f90 \
  src/runtime/mod_groundwater_multiswap_publication.f90 \
  src/runtime/mod_groundwater_multiswap_swap_phase.f90 \
  src/runtime/mod_groundwater_multiswap_topology.f90 \
  src/runtime/mod_groundwater_multiswap_transaction.f90 \
  src/runtime/mod_groundwater_multiswap_types.f90 \
  tests/fgc/mod_fgc25_multiswap_fixture.f90 \
  tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$OWNER_HEAD:$path")"
done
echo 'FVQ87_OWNER_PRODUCTION_POSTIMAGE_LOCKED=PASS'

# Lock the inherited F-GC20 and F-GC22 production blobs exactly.
test "$(git rev-parse "$FGC20_AUTH:src/runtime/mod_groundwater_tile_aggregation.f90")" = "$FGC20_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_tile_aggregation.f90)" = "$FGC20_BLOB"
test "$(git rev-parse "$FGC22_AUTH:src/runtime/mod_groundwater_accuracy_binding.f90")" = "$FGC22_BLOB"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_accuracy_binding.f90)" = "$FGC22_BLOB"

# GC25 consumes a pre-bound groundwater_head_convergence_policy_t. It does not
# construct that policy and it does not execute the Richards temporal indicator.
# Therefore only the application-accuracy contract/adapter and policy blobs that
# define the inherited binding boundary must remain identical in the GC25 image.
declare -A GC22_RELEVANT_UPSTREAM=(
  [src/runtime/mod_coupling_application_accuracy_contract.f90]=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
  [src/runtime/mod_coupling_application_accuracy_adapter.f90]=9212d600e89c85287e9280832c7e0a94befb642e
  [src/runtime/mod_groundwater_coupling_policy.f90]=5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976
)
for path in "${!GC22_RELEVANT_UPSTREAM[@]}"; do
  expected="${GC22_RELEVANT_UPSTREAM[$path]}"
  test "$(git rev-parse "$FGC22_AUTH:$path")" = "$expected"
  test "$(git rev-parse "HEAD:$path")" = "$expected"
done

test "$(git rev-parse "$FGC22_AUTH:src/solver/mod_reference_richards_temporal_indicator.f90")" = "$GC22_TEMPORAL_AUTH_BLOB"
current_temporal_blob="$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)"
if [[ "$current_temporal_blob" != "$GC22_TEMPORAL_AUTH_BLOB" ]]; then
  if grep -Eq 'use[[:space:]]+mod_reference_richards_temporal_indicator|use[[:space:]]+mod_groundwater_accuracy_binding' \
      src/runtime/mod_groundwater_multiswap_*.f90; then
    echo 'FVQ87_GC22_DEPENDENCY_BOUNDARY=FAIL unexpected temporal/accuracy-binding import' >&2
    exit 21
  fi
  echo 'FVQ87_GC22_TEMPORAL_CHANGE_OUTSIDE_GC25_BOUNDARY=PASS'
else
  echo 'FVQ87_GC22_TEMPORAL_AUTHORITY_STILL_IDENTICAL=PASS'
fi
echo 'FVQ87_FGC20_FGC22_INHERITANCE_LOCKED=PASS'

python3 - <<'PY'
from pathlib import Path

pub = Path('src/runtime/mod_groundwater_multiswap_publication.f90').read_text()
txn = Path('src/runtime/mod_groundwater_multiswap_transaction.f90').read_text()
gw = Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
ledger = Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text()

preflight = pub.index('if (.not. multiswap_publication_preflight')
first_commit = pub.index('call executor%commit_candidate')
assert preflight < first_commit
assert "error stop 'F-GC25 atomic cell publication invariant: late SWAP commit failed after prior tile publication'" in pub
assert "error stop 'F-GC25 atomic cell publication invariant: groundwater commit failed after SWAP tile publication'" in pub

for needle in [
    'if (.not. committed(i)%ready()) return',
    'if (.not. candidates(i)%ready()) return',
    'if (candidates(i)%current_lineage_id() /= committed(i)%current_lineage_id()) return',
    'if (candidates(i)%origin_revision() /= current_revision) return',
    'if (.not. ledgers(i)%prepared_ready_for_commit(prepared_ledgers(i))) return',
    'if (.not. groundwater_checkpoint%is_prepared()) return',
    'if (.not. prepared_groundwater%ready()) return',
]:
    assert needle in txn, needle

sig = 'subroutine gw_commit_prepared_backend_ifc(self, prepare_token)'
assert sig in gw
segment = gw[gw.index(sig):gw.index('end subroutine gw_commit_prepared_backend_ifc')]
assert 'status' not in segment.lower()
assert 'call service%commit_prepared_backend(prepared%backend_prepare_token)' in gw

start = ledger.index('subroutine groundwater_mass_commit_prepared')
end = ledger.index('end subroutine groundwater_mass_commit_prepared', start)
segment = ledger[start:end]
assert 'prepared_ready_for_commit' in segment
assert 'error stop' in segment
assert 'self%committed_swap_outward_exchange_m = self%prepared_total_swap_m' in segment
assert 'self%committed_exchange_count = self%prepared_committed_exchange_count' in segment
PY
echo 'FVQ87_PUBLICATION_BOUNDARY_STATIC_AUDIT=PASS'

work="$(mktemp -d)"
cleanup() {
  if git worktree list --porcelain | grep -Fq "worktree $work/owner"; then
    git worktree remove --force "$work/owner" >/dev/null 2>&1 || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# Replay the exact owner postimage in a detached worktree. This is prerequisite
# preservation evidence only. It is deliberately not counted as the independent oracle.
git worktree add --detach "$work/owner" "$OWNER_HEAD" >/dev/null
(
  cd "$work/owner"
  bash tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh > "$work/owner-gate.txt"
)
grep -q '^F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS$' "$work/owner-gate.txt"
git worktree remove --force "$work/owner" >/dev/null
echo 'FVQ87_OWNER_POSTIMAGE_REPLAY=PASS'

# Reuse only pinned fixture types from F-GC21. The adversarial sequences and all
# assertions below are independently defined by F-VQ87.
git cat-file -e "$FGC21_OWNER^{commit}"
python3 - "$FGC21_OWNER" "$work/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]
out=Path(sys.argv[2])
text=subprocess.check_output([
    'git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'
], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
echo 'FVQ87_PINNED_OWNER_FIXTURE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
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
  "$work/fgc21_fixture.f90"
  tests/fgc/mod_fgc25_multiswap_fixture.f90
  tests/qualification/fvq87/test_fvq87_fgc25_multiswap_independent.f90
)

compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/o$opt"
  mkdir -p "$dir"
  : > "$dir/compiler.txt"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${SOURCES[@]}" \
      -o "$dir/test_fvq87" 2>"$dir/compiler.txt"; then
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fvq87" > "$out"
}

compile_and_run 0 "$work/o0.txt"
compile_and_run 2 "$work/o2.txt"

grep -q '^FVQ87_PREPARE_REJECTION_ATOMICITY=PASS$' "$work/o0.txt"
grep -q '^FVQ87_DUPLICATE_TILE_PRETRIAL_REJECTION=PASS$' "$work/o0.txt"
grep -q '^FVQ87_STALE_ORIGIN_PRETRIAL_REJECTION=PASS$' "$work/o0.txt"
grep -q '^FVQ87_NONCONVERGED_CELL_ROLLBACK=PASS$' "$work/o0.txt"
grep -q '^FVQ87_WEIGHTED_MASS_ACTION_REACTION=PASS$' "$work/o0.txt"
grep -q '^FVQ87_INDEPENDENT_ORACLE=PASS$' "$work/o0.txt"
diff -u "$work/o0.txt" "$work/o2.txt"

cat "$work/o0.txt"
echo "FVQ87_INDEPENDENT_ORACLE_SHA256=$(sha256sum "$work/o0.txt" | awk '{print $1}')"
echo 'FVQ87_INDEPENDENT_ORACLE_O0_O2_IDENTITY=PASS'
echo 'F_VQ87_FINAL_GATE=PASS'
