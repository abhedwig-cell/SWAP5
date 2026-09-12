#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc21p1-r1-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

RESTART=c6494f913303b7aefc4f9c53c6c157082d54ea4b
BLOCKED=95e05490d3f60325361a9036dc720c7954093307
TX=src/transaction/mod_transaction_reference.f90
CAN=src/runtime/mod_canonical_interval_runtime.f90

python3 - <<'PY'
from pathlib import Path
import subprocess

restart='c6494f913303b7aefc4f9c53c6c157082d54ea4b'
files={
 'tx':'src/transaction/mod_transaction_reference.f90',
 'can':'src/runtime/mod_canonical_interval_runtime.f90',
}
current={k:Path(v).read_text() for k,v in files.items()}
baseline={k:subprocess.check_output(['git','show',f'{restart}:{v}'],text=True) for k,v in files.items()}
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()

tx_pred='    published%covers_requested_interval = origin_t0 == requested_t0 .and. origin_t1 == requested_t1\n'
can_pred=(
 '          result%interface_sensitivity%covers_requested_interval = &\n'
 '               result%mass%accepted_transaction_count == 1 .and. &\n'
 '               result%interface_sensitivity%origin_t0 == interval%t0 .and. &\n'
 '               result%interface_sensitivity%origin_t1 == interval%t1\n'
)
for label,text,pred in [('tx-current',current['tx'],tx_pred),('tx-baseline',baseline['tx'],tx_pred),
                        ('can-current',current['can'],can_pred),('can-baseline',baseline['can'],can_pred)]:
    assert text.count(pred)==1,(label,text.count(pred))

for text,label in [(current['tx'],'tx'),(current['can'],'can')]:
    assert 'origin_t0 <= requested_t0 .and. origin_t0 >= requested_t0' not in text,(label,'paired ordered tx identity')
    assert 'origin_t0 <= interval%t0' not in text,(label,'paired ordered canonical identity')
    assert 'origin_t1 <= interval%t1' not in text,(label,'paired ordered canonical identity')

# The P1 exchange feature must still be present after warning-hygiene remediation.
assert 'accepted_bottom_outward_exchange_native' in current['tx']
for token in ['candidate_exchange = aggregate_exchange + tx%accepted_bottom_outward_exchange_native',
              'bottom_outward_exchange_native']:
    assert token in current['can'],token
assert 'outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration' in backend
print('FGC21P1_R1_CANONICAL_EQUALITY_RESTORED=PASS')
print('FGC21P1_R1_P1_EXCHANGE_FEATURE_PRESERVED=PASS')
PY

changed_from_blocked="$(git diff --name-only "$BLOCKED" -- src | sort)"
expected_remediation="$(printf '%s\n' "$CAN" "$TX" | sort)"
[[ "$changed_from_blocked" == "$expected_remediation" ]] || {
  echo 'FGC21P1_R1_UNEXPECTED_REMEDIATION_SOURCE_DELTA' >&2
  printf 'actual:\n%s\nexpected:\n%s\n' "$changed_from_blocked" "$expected_remediation" >&2
  exit 1
}

# No F-GC21P1 exchange symbol may be removed by R1.
if git diff "$BLOCKED" -- "$TX" "$CAN" | grep -E '^-[^-].*(bottom_outward_exchange_native|accepted_bottom_outward_exchange_native|bottom_interface_exchange_available|terminal_bottom_outward_flux_native)'; then
  echo 'FGC21P1_R1_EXCHANGE_SEMANTIC_REMOVAL' >&2
  exit 1
fi
echo 'FGC21P1_R1_REMEDIATION_SOURCE_SCOPE_EXACT=PASS'

for spec in \
  'src/transaction/mod_transaction_reference.f90:bottom_interface_exchange_available' \
  'src/runtime/mod_canonical_contracts.f90:bottom_outward_exchange_native' \
  'src/runtime/mod_canonical_interval_runtime.f90:accumulate_accepted_bottom_interface' \
  'src/kernel/mod_kernel_transactions.f90:terminal_bottom_outward_flux_native' \
  'src/runtime/mod_fmr_serialized_reference_backend.f90:-solve_result%bottom_flux * step_duration'; do
  file="${spec%%:*}"
  token="${spec#*:}"
  grep -Fq -- "$token" "$file" || { echo "FGC21P1_R1_MISSING_SOURCE_SEMANTIC $file $token" >&2; exit 1; }
done
echo 'FGC21P1_R1_REQUIRED_SOURCE_SEMANTICS=PASS'

python3 - <<'PY'
from pathlib import Path
transaction=Path('src/transaction/mod_transaction_reference.f90').read_text()
canonical=Path('src/runtime/mod_canonical_interval_runtime.f90').read_text()
kernel=Path('src/kernel/mod_kernel_transactions.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
contracts=Path('src/runtime/mod_canonical_contracts.f90').read_text()
for text,name in [(transaction,'transaction'),(canonical,'canonical-runtime'),(kernel,'kernel'),(contracts,'canonical-contract')]:
    low=text.lower()
    for forbidden in ['86400','cm_to_m','m_to_cm','modflow','.swp','midnight','headcalc%']:
        assert forbidden not in low,(name,forbidden)
assert 'half1_outcome%bottom_outward_exchange_native +' in transaction
assert 'half2_outcome%bottom_outward_exchange_native' in transaction
assert 'result%terminal_bottom_outward_flux_native = half2_outcome%terminal_bottom_outward_flux_native' in transaction
assert 'result%accepted_bottom_outward_exchange_native = outcome%bottom_outward_exchange_native' in transaction
assert 'candidate_exchange = aggregate_exchange + tx%accepted_bottom_outward_exchange_native' in canonical
assert 'if (aggregate_bottom_available .and. ieee_is_finite(aggregate_bottom_exchange)' in canonical
assert 'result%bottom_interface_exchange_available = runtime_result%bottom_interface_exchange_available' in kernel
assert 'outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration' in backend
assert 'outcome%terminal_bottom_outward_flux_native = -solve_result%bottom_flux' in backend
assert 'outcome%bottom_interface_exchange_available = .true.' in backend
print('FGC21P1_R1_ACCEPTED_ROUTE_STATIC=PASS')
print('FGC21P1_R1_GENERIC_NATIVE_UNIT_TRANSPORT=PASS')
print('FGC21P1_R1_NO_SOLVER_INTERNAL_COUPLER_DEPENDENCY=PASS')
PY

changed_src="$(git diff --name-only "$RESTART" -- src | sort)"
expected_src="$(printf '%s\n' \
  src/kernel/mod_kernel_transactions.f90 \
  src/runtime/mod_canonical_contracts.f90 \
  src/runtime/mod_canonical_interval_runtime.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/transaction/mod_transaction_reference.f90 | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FGC21P1_R1_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf 'actual:\n%s\nexpected:\n%s\n' "$changed_src" "$expected_src" >&2
  exit 1
}
echo 'FGC21P1_R1_PRODUCTION_DELTA_EXACT=PASS'

# All warnings remain fatal except GCC/GFortran's compare-reals class. That class is
# intentionally non-fatal only because the two restored predicates are canonical baseline
# semantics, verified byte-for-byte above rather than rewritten in production to silence CI.
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
    tests/fgc/test_fgc21p1_exact_bottom_interface_result.f90 -o "$OUT/test.o" 2>>"$OUT/compiler.txt"
  if grep -E 'Warning:' "$OUT/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC21P1_R1_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}" >&2
    cat "$OUT/compiler.txt" >&2
    exit 1
  fi
  grep -Fq '[-Wcompare-reals]' "$OUT/compiler.txt" || {
    echo "FGC21P1_R1_EXPECTED_CANONICAL_COMPARE_REAL_WARNING_NOT_OBSERVED_O${opt}" >&2
    cat "$OUT/compiler.txt" >&2
    exit 1
  }
  echo "FGC21P1_R1_WARNING_CLASS_ISOLATED_O${opt}=PASS"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_canonical_interval_runtime.o" \
    "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FGC21P1_TWO_HALF_REJECTED_FULL_EXCLUDED=PASS' \
    'FGC21P1_RETRY_REJECTED_EXCHANGE_EXCLUDED=PASS' \
    'FGC21P1_MODEL_CERTIFICATE_ACCEPTED_ONLY=PASS' \
    'FGC21P1_MISSING_INTERFACE_RESULT_FAILS_CLOSED=PASS' \
    'FGC21P1_CANONICAL_ACCEPTED_SUBSTEP_AGGREGATION=PASS' \
    'FGC21P1_INCOMPLETE_CANONICAL_INTERVAL_NO_PUBLICATION=PASS' \
    'FGC21P1_EXACT_BOTTOM_INTERFACE_RESULT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FGC21P1_R1_TRANSACTION_CANONICAL_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FGC21P1_R1_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FGC21P1_R1_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FGC21P1_R1_OWNER_GATE PASS'
