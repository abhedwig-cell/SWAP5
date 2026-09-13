#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
IMPLEMENTATION=0ba31e5e6ab6702dfd6ddc76aba71e7162d80947
OWNER_RESTART=2a0db2524fba6e258316ce82630c60ea1c9c673a
GOVERNANCE=09ef05c60c5e45af218980001c8ad8ec30da2e9e
ORCH=src/runtime/mod_groundwater_predictor_corrector_window.f90
ADAPTER=src/runtime/mod_groundwater_swap_forcing_adapter.f90
FMR_ADAPTER=src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
ORCH_BLOB=fa2a5a45d558fbaaea242438915cdb7420b6503c
ADAPTER_BLOB=f3bf2effebc772b1e3417232d2baabe49ebb8da0
FMR_ADAPTER_BLOB=649b3587a730d2ae3b0e3b8a512fadc216e202f6
OWNER_FIXTURE_BLOB=d3cd07965f6fc0d0628557b18d65f3bbc9396888
FGC17_BLOB=fc598d14eabafcb025bb55621f7b00d6d1816f10
FGC18_BLOB=f0fc25592624360802713a9487813d119e7dc4e9
FGC19_BLOB=d37f1926dafde9d941939cf4147d799cb7478bfc
TEST=tests/fvq/test_fvq64_fgc21_independent_sequences.f90

for object in "$OWNER" "$IMPLEMENTATION" "$OWNER_RESTART" "$GOVERNANCE"; do git cat-file -e "$object^{commit}"; done
git merge-base --is-ancestor "$OWNER" HEAD
[[ "$(git rev-parse "HEAD:$ORCH")" == "$ORCH_BLOB" ]]
[[ "$(git rev-parse "HEAD:$ADAPTER")" == "$ADAPTER_BLOB" ]]
[[ "$(git rev-parse "HEAD:$FMR_ADAPTER")" == "$FMR_ADAPTER_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_coupling_contract.f90")" == "$FGC17_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90")" == "$FGC18_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/runtime/mod_groundwater_interface_mass_ledger.f90")" == "$FGC19_BLOB" ]]
[[ "$(git rev-parse "$OWNER:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90")" == "$OWNER_FIXTURE_BLOB" ]]
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src)" ]]
echo 'FVQ64_CANDIDATE_AND_PRODUCTION_BLOBS_LOCKED=PASS'

allowed=(
  integration/f-vq/F-VQ64_PRE_REGISTRATION.json
  integration/f-vq/F-VQ64_ARCHITECTURE_AUDIT.json
  integration/f-vq/F-VQ64_STATUS.json
  tests/fvq/test_fvq64_fgc21_independent_sequences.f90
  tests/fvq/run_fvq64_fgc21_independent_qualification.sh
  .github/workflows/fvq64-fgc21-independent-qualification.yml
)
mapfile -t changed < <(git diff --name-only "$OWNER..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FVQ64_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done
echo 'FVQ64_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

python3 - <<'PY'
from pathlib import Path
import json
p=Path('src/runtime/mod_groundwater_predictor_corrector_window.f90').read_text()
a=Path('src/runtime/mod_groundwater_swap_forcing_adapter.f90').read_text()
f=Path('src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90').read_text()
low=p.lower()
for forbidden in ['.swp','midnight','modflow','headcalc%','open(','read(']:
    assert forbidden not in low, ('orchestrator', forbidden)
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
assert 'call fail_result' not in p[pos_swap:]
assert 'error stop' in p[pos_swap:]
assert 'interface_head_m_to_swap_pressure_head_cm' in f
assert 'typed_forcing%bottom_head = pressure_head_cm' in f
assert 'typed_parameters%bottom_mode == 5' in f
for forbidden in ['headcalc','hnew','hold','pressure_head(']:
    assert forbidden not in f.lower(), ('fmr-adapter', forbidden)
assert 'solver-private' in a.lower()
assert 'mass_tolerance' not in p.lower()
audit=json.loads(Path('integration/f-vq/F-VQ64_ARCHITECTURE_AUDIT.json').read_text())
ids=[x['id'] for x in audit['invariants']]
assert ids == list(range(1,31)), ids
assert all(x['verdict'].startswith('preserved') for x in audit['invariants'])
status=json.loads(Path('integration/f-vq/F-VQ64_STATUS.json').read_text())
assert status['candidate_owner_final']=='1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f'
assert status['mass_conservation']=='HARD_EXACT_NO_INTERFACE_TOLERANCE'
print('FVQ64_STATIC_TRANSACTION_PUBLICATION_ORDER=PASS')
print('FVQ64_STATIC_EXACT_MASS_AND_TYPED_HEAD=PASS')
print('FVQ64_STATIC_NO_HIDDEN_IO_CALENDAR_MODFLOW=PASS')
print('FVQ64_ALL_30_ARCHITECTURE_AUDIT_PRESENT=PASS')
PY

BUILD="${TMPDIR:-/tmp}/swap5-fvq64-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

# Reuse only the owner dummy fixture definitions, not its test procedures or output.
# The independent program below owns all scenarios and all pass/fail expectations.
python3 - "$OWNER" "$BUILD/fixture.f90" <<'PY'
from pathlib import Path
import subprocess,sys
owner=sys.argv[1]; out=Path(sys.argv[2])
text=subprocess.check_output(['git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],text=True)
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
)

for opt in 0 2; do
  dir="$BUILD/o$opt"; mkdir -p "$dir"
  : > "$dir/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
    "${SOURCES[@]}" "$BUILD/fixture.f90" "$TEST" -o "$dir/test" 2>"$dir/compiler.txt"
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FVQ64_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}" >&2
    cat "$dir/compiler.txt" >&2
    exit 21
  fi
  "$dir/test" > "$dir/output.txt" 2>&1 || { cat "$dir/output.txt" >&2; exit 22; }
  grep -Fq 'F-VQ64 INDEPENDENT F-GC21 SEQUENCES PASS' "$dir/output.txt"
  echo "FVQ64_INDEPENDENT_SEQUENCE_O${opt}=PASS"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ64_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ64_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'F-VQ64 INDEPENDENT QUALIFICATION GATE PASS'
