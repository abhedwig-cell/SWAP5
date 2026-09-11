#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-FAST}"
case "$PROFILE" in
  FAST|CANONICAL|RELEASE|DEEP) ;;
  *) echo "usage: $0 {FAST|CANONICAL|RELEASE|DEEP}" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftb07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

CANONICAL=c7379b6b5b5f529ff96de3087379712bd665276a
MODULE=src/runtime/mod_coupling_application_accuracy_contract.f90
TEST=tests/fci/test_fci44_application_accuracy_contract_admission.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
TRANSACTION=src/transaction/mod_transaction_reference.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
FGC10=a1201dc870e4f5088f50b8d00e92e83457743174

fail() { echo "FTB07_QUALIFICATION_FAIL:$*" >&2; exit 47; }

python3 testbank/runners/validate_ftb07_application_accuracy_adoption.py

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical race'

grep -Fq 'logical :: h_app_available = .false.' "$MODULE" || fail 'H_app absence default'
grep -Fq 'real(real64) :: h_app_cm = 0.0_real64' "$MODULE" || fail 'H_app scalar default'
grep -Fq 'logical :: a_temporal_available = .false.' "$MODULE" || fail 'A_temporal absence default'
grep -Fq 'real(real64) :: a_temporal = 0.0_real64' "$MODULE" || fail 'A_temporal scalar default'
grep -Fq 'if (.not. self%h_app_externally_qualified) return' "$MODULE" || fail 'H_app external qualification guard'
grep -Fq 'if (.not. self%a_temporal_externally_qualified) return' "$MODULE" || fail 'A_temporal external qualification guard'
grep -Fq 'if (self%application_provenance_id <= 0_int64) return' "$MODULE" || fail 'application provenance guard'
grep -Fq 'if (self%temporal_allocation_provenance_id <= 0_int64) return' "$MODULE" || fail 'temporal provenance guard'
grep -Fq 'if (self%a_temporal > 1.0_real64) return' "$MODULE" || fail 'A_temporal upper bound'
grep -Fq 'config%model_temporal_indicator_budget_available = .false.' "$MODULE" || fail 'stale availability clearing'
grep -Fq 'config%model_temporal_indicator_budget = 0.0_real64' "$MODULE" || fail 'stale value clearing'
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$MODULE"; then
  fail 'application contract contains file I/O'
fi
if grep -Eq 'use[[:space:]]+mod_(kernel|transaction|soil_water|reference_richards)' "$MODULE"; then
  fail 'application contract depends on kernel/solver/transaction internals'
fi

echo 'FTB07_FAIL_CLOSED_CONTRACT_STATIC=PASS'
echo 'FTB07_NO_IO_OR_HIDDEN_NUMERIC_POLICY_STATIC=PASS'

grep -Fq 'model_temporal_indicator_budget_available' "$CONTRACTS" || fail 'generic carrier availability missing'
grep -Fq 'model_temporal_indicator_budget' "$CONTRACTS" || fail 'generic carrier value missing'
grep -Fq 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' "$BACKEND" || fail 'budget availability binding missing'
grep -Fq 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' "$BACKEND" || fail 'budget value binding missing'
grep -Fq 'self%last_observation%temporal_head_budget = self%temporal_indicator_budget' "$BACKEND" || fail 'native head-budget diagnostic missing'
grep -Fq 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' "$BACKEND" || fail 'head-domain normalization missing'
grep -Fq 'outcome%temporal_indicator = normalized_indicator' "$BACKEND" || fail 'dimensionless certificate transfer missing'
grep -Fq 'indicator_result%head_inf_bound = bounded_norm/sqrt(indicator_result%min_mass_weight)' "$INDICATOR" || fail 'Richards native head indicator construction missing'
echo 'FTB07_CURRENT_CANONICAL_CONSUMER_BINDING=PASS'
echo 'FTB07_DIMENSIONLESS_CERTIFICATE_NORMALIZATION=PASS'

git show "$FGC10:integration/f-gc/F-GC10_CLOSEOUT.json" > "$BUILD/fgc10.json"
python3 - "$BUILD/fgc10.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x['production_coupling_admission'] is False
assert x['numeric_policy_qualified'] is False
assert x['application_class_accuracy_qualified'] is False
assert x['mass_conservation_relaxed'] is False
non='\n'.join(x['hard_nonclaims'])
for text in ('no numeric H_app','no numeric A_temporal','no complete coupled-system head-error budget','no production SWAP-MODFLOW admission','no weakening or tradeoff of mass conservation'):
    assert text in non, text
print('FTB07_NONCLAIM_GOVERNANCE=PASS')
PY

if [[ "$PROFILE" == FAST ]]; then
  echo 'FTB07_PROFILE_FAST=PASS'
  exit 0
fi

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_one() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$TRANSACTION" -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$CONTRACTS" -o "$out/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$MODULE" -o "$out/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/application_contract.o" "$out/test.o" -o "$out/ftb07.exe"
  "$out/ftb07.exe" > "$out/output.txt"
  for marker in \
    'FCI44_CONTRACT_MATRIX=PASS' \
    'FCI44_NO_DEFAULT_NUMERIC_POLICY=PASS' \
    'FCI44_STALE_BUDGET_CLEARING=PASS' \
    'FCI44_APPLICATION_ACCURACY_CONTRACT=PASS'; do
    grep -Fq "$marker" "$out/output.txt" || fail "$tag missing marker $marker"
  done
}

run_one -O0 o0
cat "$BUILD/o0/output.txt"
echo 'FTB07_FCI44_CONTRACT_MATRIX_CURRENT_CANONICAL_O0=PASS'

if [[ "$PROFILE" == CANONICAL ]]; then
  echo 'FTB07_PROFILE_CANONICAL=PASS'
  exit 0
fi

"$BUILD/o0/ftb07.exe" > "$BUILD/o0/output-repeat.txt"
cmp -s "$BUILD/o0/output.txt" "$BUILD/o0/output-repeat.txt" || fail 'O0 repeated-run transcript drift'
run_one -O2 o2
"$BUILD/o2/ftb07.exe" > "$BUILD/o2/output-repeat.txt"
cmp -s "$BUILD/o2/output.txt" "$BUILD/o2/output-repeat.txt" || fail 'O2 repeated-run transcript drift'
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 transcript drift'
echo 'FTB07_REPEAT_RUN_DETERMINISM=PASS'
echo 'FTB07_O0_O2_BIT_IDENTITY=PASS'
echo 'FTB07_NUMERIC_H_APP=NOT_SET'
echo 'FTB07_NUMERIC_A_TEMPORAL=NOT_SET'
echo 'FTB07_APPLICATION_CLASS_ACCURACY=NOT_QUALIFIED'
echo 'FTB07_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE'
echo 'FTB07_MASS_CONSERVATION_RELAXED=NO'
echo "FTB07_PROFILE_${PROFILE}=PASS"
