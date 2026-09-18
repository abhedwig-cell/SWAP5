#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fsi39-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_SI39_FAIL $*" >&2; exit 1; }

BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
expected=$'src/runtime/mod_fmr_serialized_reference_backend.f90\nsrc/solver/mod_b110_default_mvg_provider.f90'
[[ "$(git diff --name-only "$BASE" -- src | sort)" == "$expected" ]] || { git diff --name-only "$BASE" -- src >&2; fail "unexpected production delta"; }

python3 - <<'PY'
from pathlib import Path
p=Path('src/solver/mod_b110_default_mvg_provider.f90').read_text()
r=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
for required in [
  'ksatexm_extension_enabled = .false.',
  'enable_ksatexm_extension',
  'c(10) > c(3) .and. relsat > c(11)',
  '(relsat-c(11))/(1.0_real64-c(11))',
  'term1*c(10) + (1.0_real64-term1)*c(12)',
  'if (.not. ksatexm_applied) hconduc = min(hconduc,c(3))'
]:
  assert required in p, required
assert 'logical :: ksatexm_extension_active = .false.' in r
assert 'enable_ksatexm_extension=parameters%ksatexm_extension_active' in r
print('F_SI39_STATIC_EXACT_FORMULA_AND_OPTIN=PASS')
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/provider.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi39_b110_ksatexm.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/provider.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in F_SI39_DEFAULT_DISABLED_PRESERVATION=PASS F_SI39_HUPSEL_SATURATED_KSATEXM=PASS F_SI39_HUPSEL_NEAR_SATURATED_INTERPOLATION=PASS F_SI39_BELOW_THRESHOLD_NOOP=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker $marker"
  done
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_SI39_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_SI39_OWNER_QUALIFICATION=PASS'
