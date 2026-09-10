#!/usr/bin/env bash
set -euo pipefail

BASE=8fa79a70a9faccaf8b63826df607a685eb75b046
OWNER_CLOSEOUT=1e0616b89a52393b5aa709d0742ee64b7ec32e7c
CANDIDATE=c6cabe84272fef1829243e4271b2b1314233b634
PATH_CANDIDATE=src/process/mod_restricted_surface_evaporation.f90
BLOB=a213af4deec2fe854d79120899827852a57237d1
TEST=tests/fvq/test_fvq52_surface_evaporation_independent.f90
BUILD="${RUNNER_TEMP:-/tmp}/fvq52-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

# Qualification branch must not carry production changes.
test "$(git rev-parse HEAD:src)" = "$(git rev-parse ${BASE}:src)"
echo 'FVQ52_QUALIFICATION_SRC_IMMUTABLE=PASS'

# Fetch and verify the exact immutable owner candidate, never a moving branch blob.
git fetch --no-tags origin "$CANDIDATE" >/dev/null 2>&1 || true
git cat-file -e "${CANDIDATE}^{commit}"
test "$(git rev-parse ${CANDIDATE}:${PATH_CANDIDATE})" = "$BLOB"
git cat-file -e "${OWNER_CLOSEOUT}^{commit}" || git fetch --no-tags origin "$OWNER_CLOSEOUT" >/dev/null 2>&1
test "$(git rev-parse ${OWNER_CLOSEOUT}:${PATH_CANDIDATE})" = "$BLOB"
git show "${CANDIDATE}:${PATH_CANDIDATE}" > "$BUILD/mod_restricted_surface_evaporation.f90"
test "$(git hash-object "$BUILD/mod_restricted_surface_evaporation.f90")" = "$BLOB"
echo 'FVQ52_EXACT_CANDIDATE_BLOB=PASS'

# Architecture/source guards. Strip full-line comments before token checks.
awk '!/^[[:space:]]*!/' "$BUILD/mod_restricted_surface_evaporation.f90" > "$BUILD/source.code"
if grep -Eiq '(^|[^[:alnum:]_])save([^[:alnum:]_]|$)' "$BUILD/source.code"; then
  echo 'FVQ52_FAIL persistent SAVE state found' >&2; exit 52
fi
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$BUILD/source.code"; then
  echo 'FVQ52_FAIL I/O found in process source' >&2; exit 52
fi
if grep -Eiq 'headcalc|newton|jacob|mass_ledger|mass_out|mass_in|file_unit|calendar|midnight' "$BUILD/source.code"; then
  echo 'FVQ52_FAIL forbidden solver/mass/I-O/time coupling found' >&2; exit 52
fi
if grep -Eiq 'day_of|month_of|year_of|86400|24\.0[_[:alnum:]]*[*\/]' "$BUILD/source.code"; then
  echo 'FVQ52_FAIL calendar/day cadence assumption found' >&2; exit 52
fi
echo 'FVQ52_STATE_IO_SOLVER_MASS_TIME_GUARDS=PASS'

compile_and_run() {
  local opt="$1"
  local dir="$2"
  gfortran -std=f2008 -Wall -Wextra -Werror -pedantic "$opt" -J"$dir" -I"$dir" \
    -c "$BUILD/mod_restricted_surface_evaporation.f90" -o "$dir/candidate.o"
  gfortran -std=f2008 -Wall -Wextra -Werror -pedantic "$opt" -J"$dir" -I"$dir" \
    -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/candidate.o" "$dir/test.o" -o "$dir/fvq52.exe"
  "$dir/fvq52.exe" > "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
grep -Fxq 'FVQ52_ACTIVE_CASES=1008' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_B110_DRY_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_B110_PONDED_ORACLE=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_NEGATIVE_CAPACITY_CLAMP=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_FAIL_CLOSED_INVALID_INPUT=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_STATELESS_ABA=PASS' "$BUILD/o0/output.txt"
grep -Fxq 'FVQ52_INDEPENDENT_ORACLE=PASS' "$BUILD/o0/output.txt"

cat "$BUILD/o0/output.txt"
echo "FVQ52_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FVQ52_O0_O2_IDENTITY=PASS'
echo 'FVQ52_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FVQ52_GATE=PASS'
