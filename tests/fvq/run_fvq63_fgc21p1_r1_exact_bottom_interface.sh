#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq63-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

OWNER=dcde6360f902081c94927486455e5233b81dfc1b
SOURCE_POSTIMAGE=89f7d11413e1f3ae24c648f24f56577b982f23e6
RESTART=c6494f913303b7aefc4f9c53c6c157082d54ea4b
GOVERNANCE=09ef05c60c5e45af218980001c8ad8ec30da2e9e
BLOCKED=95e05490d3f60325361a9036dc720c7954093307

# Qualification branch must not change production source relative to the exact owner authority.
if test -n "$(git diff --name-only "$OWNER" -- src)"; then
  echo 'FVQ63_PRODUCTION_SOURCE_DELTA_FROM_OWNER' >&2
  git diff --name-only "$OWNER" -- src >&2
  exit 1
fi
echo 'FVQ63_NO_PRODUCTION_SOURCE_DELTA_FROM_OWNER=PASS'

git merge-base --is-ancestor "$OWNER" HEAD
git merge-base --is-ancestor "$SOURCE_POSTIMAGE" HEAD
git merge-base --is-ancestor "$RESTART" HEAD
git cat-file -e "$GOVERNANCE^{commit}"
git cat-file -e "$BLOCKED^{commit}"
echo 'FVQ63_PINNED_LINEAGE=PASS'

python3 - <<'PY'
import json, subprocess
from pathlib import Path
owner='dcde6360f902081c94927486455e5233b81dfc1b'
restart='c6494f913303b7aefc4f9c53c6c157082d54ea4b'
expected_blobs={
 'src/kernel/mod_kernel_transactions.f90':'c7c5b7d3357e4e6739c8f647d6232baca45563e6',
 'src/runtime/mod_canonical_contracts.f90':'3cbb81b25626e6574ae83416f088dc52882f91fc',
 'src/runtime/mod_canonical_interval_runtime.f90':'f41f725df4be883d277a8fd5afe5a6f1bc14ad1b',
 'src/runtime/mod_fmr_serialized_reference_backend.f90':'d565b893a08d92c46077995fdec544584aa04664',
 'src/transaction/mod_transaction_reference.f90':'834487df4e7a38c7c8ffd83805d98933714c6977',
}
for path,expected in expected_blobs.items():
    actual=subprocess.check_output(['git','rev-parse',f'HEAD:{path}'],text=True).strip()
    assert actual==expected,(path,actual,expected)
    owner_blob=subprocess.check_output(['git','rev-parse',f'{owner}:{path}'],text=True).strip()
    assert owner_blob==expected,(path,'owner',owner_blob,expected)
print('FVQ63_SOURCE_BLOBS_EXACT=PASS')

status=json.loads(Path('integration/f-gc/F-GC21P1_R1_STATUS.json').read_text())
assert status['decision']=='OWNER_QUALIFIED_F_GC21P1_AFTER_WARNING_HYGIENE_REMEDIATION_NOT_INDEPENDENTLY_QUALIFIED_NOT_CANONICALLY_ADMITTED'
assert status['qualified_source_postimage']=='89f7d11413e1f3ae24c648f24f56577b982f23e6'
assert status['mass_conservation']=='HARD_PRESERVED_NO_TOLERANCE_RELAXATION'
assert status['owner_qualified'] is True
assert status['independently_qualified'] is False
assert status['canonical_admission'] is False
assert status['production_groundwater_coupling_admission'] is False

audit=json.loads(Path('integration/f-gc/F-GC21P1_R1_ARCHITECTURE_AUDIT.json').read_text())
assert audit['overall']=='30_OF_30_NO_ADVERSE_DELTA_AFTER_WARNING_HYGIENE_REMEDIATION'
assert audit['mass_conservation']['status']=='HARD_UNCHANGED'
assert audit['mass_conservation']['tolerance_relaxed'] is False
assert len(audit['invariants'])==30
print('FVQ63_OWNER_AUTHORITY_STATUS_LOCK=PASS')

# R1 must restore exactly the two baseline equality predicates.
checks=[
 ('src/transaction/mod_transaction_reference.f90',
  '    published%covers_requested_interval = origin_t0 == requested_t0 .and. origin_t1 == requested_t1\n'),
 ('src/runtime/mod_canonical_interval_runtime.f90',
  '          result%interface_sensitivity%covers_requested_interval = &\n'
  '               result%mass%accepted_transaction_count == 1 .and. &\n'
  '               result%interface_sensitivity%origin_t0 == interval%t0 .and. &\n'
  '               result%interface_sensitivity%origin_t1 == interval%t1\n')]
for path,predicate in checks:
    current=Path(path).read_text()
    baseline=subprocess.check_output(['git','show',f'{restart}:{path}'],text=True)
    assert current.count(predicate)==1,(path,'current equality count')
    assert baseline.count(predicate)==1,(path,'baseline equality count')
assert 'origin_t0 <= requested_t0 .and. origin_t0 >= requested_t0' not in Path(checks[0][0]).read_text()
assert 'origin_t0 <= interval%t0' not in Path(checks[1][0]).read_text()
print('FVQ63_CANONICAL_EQUALITY_SEMANTICS_EXACT=PASS')

# Independent static checks on the accepted exchange route.
tx=Path('src/transaction/mod_transaction_reference.f90').read_text()
can=Path('src/runtime/mod_canonical_interval_runtime.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
kernel=Path('src/kernel/mod_kernel_transactions.f90').read_text()
assert 'result%accepted_bottom_outward_exchange_native = half1_outcome%bottom_outward_exchange_native +' in tx
assert 'half2_outcome%bottom_outward_exchange_native' in tx
assert 'result%terminal_bottom_outward_flux_native = half2_outcome%terminal_bottom_outward_flux_native' in tx
assert 'result%accepted_bottom_outward_exchange_native = outcome%bottom_outward_exchange_native' in tx
assert 'candidate_exchange = aggregate_exchange + tx%accepted_bottom_outward_exchange_native' in can
assert 'aggregate_bottom_available .and. ieee_is_finite(aggregate_bottom_exchange)' in can
assert 'outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration' in backend
assert 'outcome%terminal_bottom_outward_flux_native = -solve_result%bottom_flux' in backend
assert 'result%bottom_interface_exchange_available = runtime_result%bottom_interface_exchange_available' in kernel
print('FVQ63_ACCEPTED_EXCHANGE_ROUTE_STATIC=PASS')

# Added production lines relative to restart must contain no hidden time/I-O/coupler assumptions.
diff=subprocess.check_output(['git','diff','--unified=0',restart,'--','src'],text=True).lower().splitlines()
added='\n'.join(line[1:] for line in diff if line.startswith('+') and not line.startswith('+++'))
for forbidden in ['86400','midnight','.swp','modflow','headcalc%','cm_to_m','m_to_cm']:
    assert forbidden not in added,forbidden
print('FVQ63_NO_HIDDEN_TIME_IO_COUPLER_ASSUMPTION_IN_DELTA=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  : > "$OUT/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o" 2>>"$OUT/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$OUT/mod_canonical_contracts.o" 2>>"$OUT/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_interval_runtime.f90 -o "$OUT/mod_canonical_interval_runtime.o" 2>>"$OUT/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/kernel/mod_kernel_transactions.f90 -o "$OUT/mod_kernel_transactions.o" 2>>"$OUT/compiler.txt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq63_fgc21p1_r1_exact_bottom_interface.f90 -o "$OUT/test.o" 2>>"$OUT/compiler.txt"

  if grep -E 'Warning:' "$OUT/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FVQ63_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}" >&2
    cat "$OUT/compiler.txt" >&2
    exit 1
  fi
  grep -Fq '[-Wcompare-reals]' "$OUT/compiler.txt" || {
    echo "FVQ63_EXPECTED_BASELINE_COMPARE_REAL_WARNING_NOT_OBSERVED_O${opt}" >&2
    cat "$OUT/compiler.txt" >&2
    exit 1
  }
  echo "FVQ63_BASELINE_WARNING_CLASS_ISOLATED_O${opt}=PASS"

  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_canonical_interval_runtime.o" \
    "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FVQ63_REJECTED_FULL_EXCHANGE_EXCLUDED=PASS' \
    'FVQ63_RETRY_EXCHANGE_EXCLUDED=PASS' \
    'FVQ63_MODEL_CERTIFICATE_EXCHANGE=PASS' \
    'FVQ63_MISSING_AND_NONFINITE_EXCHANGE_FAIL_CLOSED=PASS' \
    'FVQ63_CANONICAL_ACCEPTED_AGGREGATE_AND_MASS=PASS' \
    'FVQ63_PARTIAL_CANONICAL_ROLLBACK_NO_PUBLICATION=PASS' \
    'FVQ63_INDEPENDENT_EXACT_BOTTOM_INTERFACE_QUALIFICATION PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  done
  echo "FVQ63_INDEPENDENT_RUNTIME_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ63_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ63_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"

# Supporting preservation only: owner test is not the independent decision test.
OWNER_BUILD="$BUILD/owner-support"
mkdir -p "$OWNER_BUILD"
gfortran "${COMMON[@]}" -O0 -J "$OWNER_BUILD" -I "$OWNER_BUILD" -c \
  src/transaction/mod_transaction_reference.f90 -o "$OWNER_BUILD/mod_transaction_reference.o" 2>/dev/null
gfortran "${COMMON[@]}" -O0 -J "$OWNER_BUILD" -I "$OWNER_BUILD" -c \
  src/runtime/mod_canonical_contracts.f90 -o "$OWNER_BUILD/mod_canonical_contracts.o" 2>/dev/null
gfortran "${COMMON[@]}" -O0 -J "$OWNER_BUILD" -I "$OWNER_BUILD" -c \
  src/runtime/mod_canonical_interval_runtime.f90 -o "$OWNER_BUILD/mod_canonical_interval_runtime.o" 2>/dev/null
gfortran "${COMMON[@]}" -O0 -J "$OWNER_BUILD" -I "$OWNER_BUILD" -c \
  tests/fgc/test_fgc21p1_exact_bottom_interface_result.f90 -o "$OWNER_BUILD/test.o" 2>/dev/null
gfortran -O0 "$OWNER_BUILD/mod_transaction_reference.o" "$OWNER_BUILD/mod_canonical_contracts.o" \
  "$OWNER_BUILD/mod_canonical_interval_runtime.o" "$OWNER_BUILD/test.o" -o "$OWNER_BUILD/test"
"$OWNER_BUILD/test" > "$OWNER_BUILD/output.txt" 2>&1
grep -Fq 'FGC21P1_EXACT_BOTTOM_INTERFACE_RESULT_TEST PASS' "$OWNER_BUILD/output.txt"
echo 'FVQ63_OWNER_TEST_SUPPORTING_PRESERVATION=PASS'

echo 'FVQ63_INDEPENDENT_QUALIFICATION_GATE PASS'
