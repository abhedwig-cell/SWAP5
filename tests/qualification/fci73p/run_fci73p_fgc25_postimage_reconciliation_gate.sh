#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

ADMITTED=c53b4e4e966a6b0531e1e6224b2f8f1d7e02ece1
ADMISSION_PARENT1=1ef995e682cbc0fbbce8b68281646b0de1bbbcd3
ADMISSION_PARENT2=b2f5d7773dd426294a837e4de861472e1a8ee866
ADMISSION_TREE=55cb32c19015aed358cc4239d83c80082f1bd89e
OWNER_QUALIFIED=43c9f09110dea83928ef7d58990c37575d8ca223
FVQ87_CLOSEOUT=37c02ac3747bfaacdb8b3408b8228f3deb2b9824
FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
FGC20_AUTH=54dc9cc930468d9f376f596fe2c1b6f45938b59b
FGC22_AUTH=c50f3770ae8e4bee7c276a080be00156218944f1
EXPECTED_ORACLE_SHA=de9a811ebb3a85bf14c440350fb730b0fab8f576c06683f1265757669542d9d8

test "$(git rev-parse "$ADMITTED^1")" = "$ADMISSION_PARENT1"
test "$(git rev-parse "$ADMITTED^2")" = "$ADMISSION_PARENT2"
test "$(git rev-parse "$ADMITTED^{tree}")" = "$ADMISSION_TREE"
git merge-base --is-ancestor "$ADMITTED" HEAD
echo 'FCI73P_ADMISSION_PARENTAGE_TREE=PASS'

allowed=(
  ".github/workflows/fci73p-fgc25-postimage-reconciliation.yml"
  "integration/f-ci/F-CI73P_STATUS.json"
  "tests/qualification/fci73p/run_fci73p_fgc25_postimage_reconciliation_gate.sh"
)
mapfile -t changed < <(git diff --name-only "$ADMITTED..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    if [[ "$path" == "$candidate" ]]; then ok=1; break; fi
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "FCI73P_SCOPE_FAIL unexpected path: $path" >&2
    exit 20
  fi
done
if git diff --name-only "$ADMITTED..HEAD" | grep -Eq '^(src|reference)/'; then
  echo 'FCI73P_PRODUCTION_REFERENCE_DELTA=FAIL' >&2
  exit 21
fi
echo 'FCI73P_GOVERNANCE_ONLY_DELTA=PASS'

owner_paths=(
  src/runtime/mod_groundwater_accuracy_binding.f90
  src/runtime/mod_groundwater_multiswap_coupler.f90
  src/runtime/mod_groundwater_multiswap_publication.f90
  src/runtime/mod_groundwater_multiswap_swap_phase.f90
  src/runtime/mod_groundwater_multiswap_topology.f90
  src/runtime/mod_groundwater_multiswap_transaction.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  tests/fgc/mod_fgc25_multiswap_fixture.f90
  tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh
  tests/fgc/test_fgc25_corrector_tile_fail_closed.f90
  tests/fgc/test_fgc25_multicell_isolation.f90
  tests/fgc/test_fgc25_multiswap_commit.f90
  tests/fgc/test_fgc25_multiswap_qualification.f90
  tests/fgc/test_fgc25_permutation_determinism.f90
  tests/fgc/test_fgc25_single_tile_equivalence.f90
)
for path in "${owner_paths[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$OWNER_QUALIFIED:$path")"
done
echo 'FCI73P_PRODUCTION_BLOBS_PRESERVED=PASS'

fvq_paths=(
  .github/workflows/fvq87-fgc25-multiswap-independent.yml
  qualification/F-VQ87_STATUS.json
  tests/qualification/fvq87/run_fvq87_fgc25_multiswap_independent_gate.sh
  tests/qualification/fvq87/test_fvq87_fgc25_multiswap_independent.f90
)
for path in "${fvq_paths[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$FVQ87_CLOSEOUT:$path")"
done
echo 'FCI73P_FVQ87_EVIDENCE_PRESERVED=PASS'

test "$(git rev-parse "$FGC20_AUTH:src/runtime/mod_groundwater_tile_aggregation.f90")" = d62ecba039d9bef178acde6900b81e9d5b0931eb
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_tile_aggregation.f90)" = d62ecba039d9bef178acde6900b81e9d5b0931eb
test "$(git rev-parse "$FGC22_AUTH:src/runtime/mod_groundwater_accuracy_binding.f90")" = b8ac03e810c73519b433f7851c6fd143ba26676a
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_accuracy_binding.f90)" = b8ac03e810c73519b433f7851c6fd143ba26676a
for spec in \
  src/runtime/mod_coupling_application_accuracy_contract.f90:c07d573d21e7d013ab962c0a9d28102ab7b5cdfc \
  src/runtime/mod_coupling_application_accuracy_adapter.f90:9212d600e89c85287e9280832c7e0a94befb642e \
  src/runtime/mod_groundwater_coupling_policy.f90:5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976; do
  path="${spec%%:*}"; blob="${spec##*:}"
  test "$(git rev-parse "$FGC22_AUTH:$path")" = "$blob"
  test "$(git rev-parse "HEAD:$path")" = "$blob"
done
if grep -Eq 'use[[:space:]]+mod_reference_richards_temporal_indicator|use[[:space:]]+mod_groundwater_accuracy_binding' src/runtime/mod_groundwater_multiswap_*.f90; then
  echo 'FCI73P_GC22_DEPENDENCY_BOUNDARY=FAIL' >&2
  exit 22
fi
echo 'FCI73P_FGC20_FGC22_INHERITANCE=PASS'

owner_log="$(mktemp)"
work="$(mktemp -d)"
cleanup() { rm -f "$owner_log"; rm -rf "$work"; }
trap cleanup EXIT
bash tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh | tee "$owner_log"
grep -q '^F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS$' "$owner_log"
echo 'FCI73P_OWNER_GATE_CURRENT_CANONICAL=PASS'

python3 - <<'PY'
from pathlib import Path
pub = Path('src/runtime/mod_groundwater_multiswap_publication.f90').read_text()
txn = Path('src/runtime/mod_groundwater_multiswap_transaction.f90').read_text()
gw = Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
ledger = Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text()
assert pub.index('if (.not. multiswap_publication_preflight') < pub.index('call executor%commit_candidate')
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
]: assert needle in txn, needle
sig='subroutine gw_commit_prepared_backend_ifc(self, prepare_token)'
segment=gw[gw.index(sig):gw.index('end subroutine gw_commit_prepared_backend_ifc')]
assert 'status' not in segment.lower()
assert 'call service%commit_prepared_backend(prepared%backend_prepare_token)' in gw
start=ledger.index('subroutine groundwater_mass_commit_prepared')
end=ledger.index('end subroutine groundwater_mass_commit_prepared', start)
segment=ledger[start:end]
assert 'prepared_ready_for_commit' in segment
assert 'error stop' in segment
assert 'self%committed_swap_outward_exchange_m = self%prepared_total_swap_m' in segment
assert 'self%committed_exchange_count = self%prepared_committed_exchange_count' in segment
PY
echo 'FCI73P_PUBLICATION_BOUNDARY_AUDIT=PASS'

git cat-file -e "$FGC21_OWNER^{commit}"
python3 - "$FGC21_OWNER" "$work/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
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
  mkdir -p "$dir"; : > "$dir/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${SOURCES[@]}" -o "$dir/test_fvq87" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then cat "$dir/compiler.txt" >&2; exit 31; fi
  "$dir/test_fvq87" > "$out"
}
compile_and_run 0 "$work/o0.txt"
compile_and_run 2 "$work/o2.txt"
for marker in FVQ87_PREPARE_REJECTION_ATOMICITY FVQ87_DUPLICATE_TILE_PRETRIAL_REJECTION FVQ87_STALE_ORIGIN_PRETRIAL_REJECTION FVQ87_NONCONVERGED_CELL_ROLLBACK FVQ87_WEIGHTED_MASS_ACTION_REACTION FVQ87_INDEPENDENT_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done
diff -u "$work/o0.txt" "$work/o2.txt"
oracle_sha="$(sha256sum "$work/o0.txt" | awk '{print $1}')"
test "$oracle_sha" = "$EXPECTED_ORACLE_SHA"
cat "$work/o0.txt"
echo "FCI73P_INDEPENDENT_ORACLE_SHA256=$oracle_sha"
echo 'FCI73P_INDEPENDENT_ORACLE_O0_O2_IDENTITY=PASS'
echo 'F_CI73P_FINAL_GATE=PASS'
