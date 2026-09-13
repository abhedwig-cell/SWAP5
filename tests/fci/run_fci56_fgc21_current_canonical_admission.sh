#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RESTART=df51575e18777856a47a5d0d1e2e1c7456be4601
COMPOSITION=09895c05b5d2e11ead16bfcdf018d210da18eb77
GOVERNANCE=09ef05c60c5e45af218980001c8ad8ec30da2e9e
OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
IMPLEMENTATION=0ba31e5e6ab6702dfd6ddc76aba71e7162d80947
FVQ64=466119889a3f09b33ede638322e897bded2472a3
FVQ64_EXEC=c6429070beda4aed509f2785f83baf9c8280cc79
ORCH=src/runtime/mod_groundwater_predictor_corrector_window.f90
ADAPTER=src/runtime/mod_groundwater_swap_forcing_adapter.f90
FMR_ADAPTER=src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
ORCH_BLOB=fa2a5a45d558fbaaea242438915cdb7420b6503c
ADAPTER_BLOB=f3bf2effebc772b1e3417232d2baabe49ebb8da0
FMR_ADAPTER_BLOB=649b3587a730d2ae3b0e3b8a512fadc216e202f6
FGC17_BLOB=fc598d14eabafcb025bb55621f7b00d6d1816f10
FGC18_BLOB=f0fc25592624360802713a9487813d119e7dc4e9
FGC19_BLOB=d37f1926dafde9d941939cf4147d799cb7478bfc
KERNEL_TX_BLOB=c7c5b7d3357e4e6739c8f647d6232baca45563e6
CANONICAL_CONTRACTS_BLOB=3cbb81b25626e6574ae83416f088dc52882f91fc
CANONICAL_RUNTIME_BLOB=f41f725df4be883d277a8fd5afe5a6f1bc14ad1b
FMR_BACKEND_BLOB=d565b893a08d92c46077995fdec544584aa04664
TRANSACTION_REF_BLOB=834487df4e7a38c7c8ffd83805d98933714c6977
EXPECTED_OUTPUT_SHA256=79affb467d34646f19aef510653d319f53b82861678a7dc27e6cf9affcbbdf10

for object in "$RESTART" "$COMPOSITION" "$GOVERNANCE" "$OWNER" "$IMPLEMENTATION" "$FVQ64" "$FVQ64_EXEC"; do
  git cat-file -e "$object^{commit}"
done
[[ "$(git rev-parse "$COMPOSITION^")" == "$RESTART" ]]
git merge-base --is-ancestor "$COMPOSITION" HEAD
git merge-base --is-ancestor "$IMPLEMENTATION" "$OWNER"
git merge-base --is-ancestor "$OWNER" "$FVQ64"
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$RESTART" ]] || {
  echo "FCI56_LIVE_CANONICAL_DRIFT expected=$RESTART actual=$LIVE_CANONICAL" >&2
  exit 19
}
echo 'FCI56_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

mapfile -t prod_changed < <(git diff --name-only "$RESTART..$COMPOSITION" | sort)
expected_prod=(
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
)
mapfile -t expected_sorted < <(printf '%s\n' "${expected_prod[@]}" | sort)
[[ "${prod_changed[*]}" == "${expected_sorted[*]}" ]] || {
  printf 'FCI56_COMPOSITION_SCOPE_FAIL actual: %s\n' "${prod_changed[*]}" >&2
  exit 20
}
[[ "$(git rev-parse "HEAD:$ORCH")" == "$ORCH_BLOB" ]]
[[ "$(git rev-parse "HEAD:$ADAPTER")" == "$ADAPTER_BLOB" ]]
[[ "$(git rev-parse "HEAD:$FMR_ADAPTER")" == "$FMR_ADAPTER_BLOB" ]]
[[ "$(git rev-parse "$COMPOSITION:$ORCH")" == "$ORCH_BLOB" ]]
[[ "$(git rev-parse "$COMPOSITION:$ADAPTER")" == "$ADAPTER_BLOB" ]]
[[ "$(git rev-parse "$COMPOSITION:$FMR_ADAPTER")" == "$FMR_ADAPTER_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_coupling_contract.f90")" == "$FGC17_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90")" == "$FGC18_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_interface_mass_ledger.f90")" == "$FGC19_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/kernel/mod_kernel_transactions.f90")" == "$KERNEL_TX_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_canonical_contracts.f90")" == "$CANONICAL_CONTRACTS_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_canonical_interval_runtime.f90")" == "$CANONICAL_RUNTIME_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90")" == "$FMR_BACKEND_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/transaction/mod_transaction_reference.f90")" == "$TRANSACTION_REF_BLOB" ]]
[[ -z "$(git diff --name-only "$COMPOSITION..HEAD" -- src reference)" ]]
echo 'FCI56_PRODUCTION_COMPOSITION_AND_BASE_BLOBS_LOCKED=PASS'

allowed=(
  integration/f-ci/F-CI56_PRE_REGISTRATION.json
  integration/f-ci/F-CI56_ARCHITECTURE_AUDIT.json
  integration/f-ci/F-CI56_STATUS.json
  tests/fci/run_fci56_fgc21_current_canonical_admission.sh
  .github/workflows/fci56-fgc21-current-canonical-admission.yml
)
mapfile -t qual_changed < <(git diff --name-only "$COMPOSITION..HEAD")
for path in "${qual_changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || { echo "FCI56_QUALIFICATION_SCOPE_FAIL unexpected path: $path" >&2; exit 21; }
done
for path in "${allowed[@]}"; do [[ -f "$path" ]]; done
echo 'FCI56_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

python3 - "$FVQ64" <<'PY'
from pathlib import Path
import json, subprocess, sys
fvq64=sys.argv[1]
p=Path('src/runtime/mod_groundwater_predictor_corrector_window.f90').read_text()
a=Path('src/runtime/mod_groundwater_swap_forcing_adapter.f90').read_text()
f=Path('src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90').read_text()
low='\n'.join([p,a,f]).lower()
for forbidden in ['.swp','midnight','headcalc%','file unit','open(','read(','write(']:
    assert forbidden not in low, forbidden
for forbidden in ['modflow','86400']:
    assert forbidden not in p.lower(), ('orchestrator', forbidden)
assert p.count('checkpoint=swap_checkpoint') == 2
assert p.count('call groundwater_trial_from_checkpoint') == 2
assert 'qbot_mean_cm_per_day = -exchange_cm / duration_day' in p
assert 'pair_groundwater_flux_from_swap' in p
assert 'result%corrector_swap_outward_exchange_cm * CM_TO_M' in p
assert 'abs(result%residual%flux_residual_m_per_s) > 0.0_real64' in p
assert 'ledger%stage_exchange' in p and 'ledger%prepare_trial' in p
assert 'groundwater_prepare_candidate' in p
pos_swap=p.index('call executor%commit_candidate')
pos_gw=p.index('call groundwater_commit_prepared')
pos_ledger=p.index('call ledger%commit_prepared')
assert pos_swap < pos_gw < pos_ledger
pos_irreversible=p.index('result%diagnostics%swap_committed = .true.', pos_swap)
end_main=p.index('end subroutine run_restricted_groundwater_coupling_window', pos_irreversible)
publication_tail=p[pos_irreversible:end_main]
assert 'call fail_result' not in publication_tail
assert 'error stop' in publication_tail
assert 'interface_head_m_to_swap_pressure_head_cm' in f
assert 'typed_forcing%bottom_head = pressure_head_cm' in f
assert 'typed_parameters%bottom_mode == 5' in f
for forbidden in ['headcalc','hnew','hold','pressure_head(']:
    assert forbidden not in f.lower(), ('fmr-adapter', forbidden)
assert 'solver-private' in a.lower()
assert 'mass_tolerance' not in p.lower()
pre=json.loads(Path('integration/f-ci/F-CI56_PRE_REGISTRATION.json').read_text())
assert pre['restart_canonical']=='df51575e18777856a47a5d0d1e2e1c7456be4601'
assert pre['production_composition']=='09895c05b5d2e11ead16bfcdf018d210da18eb77'
audit=json.loads(Path('integration/f-ci/F-CI56_ARCHITECTURE_AUDIT.json').read_text())
ids=[x['id'] for x in audit['invariants']]
assert ids == list(range(1,31)), ids
assert all(x['verdict'].startswith('preserved') for x in audit['invariants'])
status=json.loads(Path('integration/f-ci/F-CI56_STATUS.json').read_text())
assert status['mass_conservation']=='HARD_EXACT_NO_INTERFACE_TOLERANCE'
assert status['decision'] in {
    'PENDING_CURRENT_CANONICAL_ADMISSION_EVIDENCE',
    'QUALIFIED_F_CI56_READY_FOR_CANONICAL_PROMOTION'
}
fvq_status=json.loads(subprocess.check_output(
    ['git','show',fvq64+':integration/f-vq/F-VQ64_STATUS.json'], text=True))
assert fvq_status['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert fvq_status['independent_qualification'] is True
assert fvq_status['canonical_admission'] is False
assert fvq_status['candidate_owner_final']=='1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f'
assert fvq_status['orchestrator_blob']=='fa2a5a45d558fbaaea242438915cdb7420b6503c'
assert fvq_status['mass_conservation']=='HARD_EXACT_NO_INTERFACE_TOLERANCE'
print('FCI56_STATIC_TRANSACTION_PUBLICATION_ORDER=PASS')
print('FCI56_STATIC_EXACT_MASS_AND_TYPED_HEAD=PASS')
print('FCI56_STATIC_NO_HIDDEN_IO_CALENDAR_MODFLOW=PASS')
print('FCI56_ALL_30_ARCHITECTURE_AUDIT_PRESENT=PASS')
print('FCI56_FVQ64_INDEPENDENT_AUTHORITY_LOCKED=PASS')
PY

BUILD="${TMPDIR:-/tmp}/swap5-fci56-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$OWNER" "$BUILD/fixture.f90" <<'PY'
from pathlib import Path
import subprocess,sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY
git show "$FVQ64:tests/fvq/test_fvq64_fgc21_independent_sequences.f90" > "$BUILD/independent.f90"

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
)
for opt in 0 2; do
  dir="$BUILD/o$opt"; mkdir -p "$dir"
  : > "$dir/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    "${SOURCES[@]}" "$BUILD/fixture.f90" "$BUILD/independent.f90" -o "$dir/test" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FCI56_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}" >&2
    cat "$dir/compiler.txt" >&2
    exit 22
  fi
  "$dir/test" > "$dir/output.txt" 2>&1 || { cat "$dir/output.txt" >&2; exit 23; }
  grep -Fq 'F-VQ64 INDEPENDENT F-GC21 SEQUENCES PASS' "$dir/output.txt"
  echo "FCI56_INDEPENDENT_SEQUENCE_O${opt}=PASS"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
ACTUAL_SHA256="$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
[[ "$ACTUAL_SHA256" == "$EXPECTED_OUTPUT_SHA256" ]] || {
  echo "FCI56_INDEPENDENT_OUTPUT_HASH_MISMATCH expected=$EXPECTED_OUTPUT_SHA256 actual=$ACTUAL_SHA256" >&2
  exit 24
}
echo 'FCI56_O0_O2_OUTPUT_IDENTITY=PASS'
echo "FCI56_OUTPUT_SHA256=$ACTUAL_SHA256"
echo 'F-CI56 CURRENT-CANONICAL ADMISSION GATE PASS'
