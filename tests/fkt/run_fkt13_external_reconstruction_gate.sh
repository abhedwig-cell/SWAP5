#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt13-external-reconstruction-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# F-KT13 extends but must not weaken the complete F-KT12 typed restore gate.
bash tests/fkt/run_fkt12_committed_restore_gate.sh

DONOR=tests/fkt/test_fkt05_reusable_checkpoint.f90
EXPECTED_DONOR_BLOB=1e476c3492044fe3b87118fc84e079e9574a3d92
ACTUAL_DONOR_BLOB="$(git hash-object "$DONOR")"
if [[ "$ACTUAL_DONOR_BLOB" != "$EXPECTED_DONOR_BLOB" ]]; then
  echo "F-KT13 donor drift: expected $EXPECTED_DONOR_BLOB got $ACTUAL_DONOR_BLOB" >&2
  exit 1
fi

python3 - "$DONOR" "$BUILD/mod_fkt05_test_model.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
marker = '\nprogram test_fkt05_reusable_checkpoint\n'
if src.count(marker) != 1:
    raise SystemExit(f'F-KT13 model extraction anchor count={src.count(marker)}')
Path(sys.argv[2]).write_text(src.split(marker, 1)[0] + '\n', encoding='utf-8')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
MODULE_SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  "$BUILD/mod_fkt05_test_model.f90"
  tests/fkt/mod_fkt12_mass_complete_test_model.f90
  tests/fkt/mod_fkt13_process_support.f90
  tests/fkt/mod_fkt13_persistence_adapter.f90
)
PROGRAMS=(
  test_fkt13_trusted_reconstruction
  fkt13_reference
  fkt13_producer
  fkt13_consumer
  fkt13_negative_probe
)

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == o2 ]] && FLAG=-O2
  MODDIR="$BUILD/$OPT/mod"
  OBJDIR="$BUILD/$OPT/obj"
  mkdir -p "$MODDIR" "$OBJDIR"
  OBJECTS=()
  for SRC in "${MODULE_SOURCES[@]}"; do
    BASE="$(basename "$SRC" .f90)"
    OBJ="$OBJDIR/$BASE.o"
    gfortran "${COMMON[@]}" "$FLAG" -I "$MODDIR" -J "$MODDIR" -c "$SRC" -o "$OBJ"
    OBJECTS+=("$OBJ")
  done
  for PROGRAM in "${PROGRAMS[@]}"; do
    gfortran "${COMMON[@]}" "$FLAG" -I "$MODDIR" -J "$MODDIR" \
      "${OBJECTS[@]}" "tests/fkt/$PROGRAM.f90" -o "$BUILD/$OPT/$PROGRAM"
  done

  "$BUILD/$OPT/test_fkt13_trusted_reconstruction" > "$BUILD/$OPT/unit.out" 2>&1 || {
    cat "$BUILD/$OPT/unit.out" >&2
    exit 1
  }
  "$BUILD/$OPT/fkt13_reference" > "$BUILD/$OPT/reference.out" 2>&1 || {
    cat "$BUILD/$OPT/reference.out" >&2
    exit 1
  }

  ARTIFACT="$BUILD/$OPT/valid.restart"
  "$BUILD/$OPT/fkt13_producer" "$ARTIFACT" > "$BUILD/$OPT/producer.out" 2>&1 || {
    cat "$BUILD/$OPT/producer.out" >&2
    exit 1
  }

  # The artifact whitelist is part of the architecture gate: no forcing,
  # solver scratch, warm starts, Jacobians or duplicated immutable parameters.
  python3 - "$ARTIFACT" "$BUILD/$OPT" <<'PY'
from pathlib import Path
import sys
artifact = Path(sys.argv[1])
outdir = Path(sys.argv[2])
lines = artifact.read_text(encoding='utf-8').splitlines()
expected_prefixes = [
    'SWAP5_FKT13_ARTIFACT_V1',
    'schema_version=',
    'layout_id=',
    'codec_id=',
    'lineage_id=',
    'revision=',
    'time_bound=',
    'committed_time_bits=',
    'water_bits=',
    'SWAP5_FKT13_END',
]
if len(lines) != len(expected_prefixes):
    raise SystemExit(f'F-KT13 artifact line count {len(lines)} != {len(expected_prefixes)}')
for line, prefix in zip(lines, expected_prefixes):
    if prefix.endswith('='):
        if not line.startswith(prefix):
            raise SystemExit(f'F-KT13 artifact field mismatch: {line!r} expected prefix {prefix!r}')
    elif line != prefix:
        raise SystemExit(f'F-KT13 artifact sentinel mismatch: {line!r} expected {prefix!r}')
for forbidden in ('forcing', 'scratch', 'jacobian', 'newton', 'warm', 'parameter'):
    if forbidden in artifact.read_text(encoding='utf-8').lower():
        raise SystemExit(f'F-KT13 forbidden persisted content: {forbidden}')

def write_variant(name, mutate):
    data = list(lines)
    data = mutate(data)
    (outdir / name).write_text('\n'.join(data) + '\n', encoding='utf-8')

write_variant('wrong_schema.restart', lambda d: d[:1] + ['schema_version=2'] + d[2:])
write_variant('wrong_layout.restart', lambda d: d[:2] + ['layout_id=13002'] + d[3:])
write_variant('unknown_codec.restart', lambda d: d[:3] + ['codec_id=999999'] + d[4:])
write_variant('truncated.restart', lambda d: d[:-2])
write_variant('duplicate_revision.restart', lambda d: d[:6] + [d[5]] + d[6:])
write_variant('inconsistent_time.restart', lambda d: d[:6] + ['time_bound=0'] + d[7:])
write_variant('invalid_lineage.restart', lambda d: d[:4] + ['lineage_id=0'] + d[5:])
write_variant('invalid_revision.restart', lambda d: d[:5] + ['revision=-1'] + d[6:])
write_variant('invalid_payload.restart', lambda d: d[:8] + ['water_bits=9221120237041090560'] + d[9:])
print('FKT13_EXTERNAL_ARTIFACT_FIELD_WHITELIST=PASS')
PY

  "$BUILD/$OPT/fkt13_consumer" "$ARTIFACT" > "$BUILD/$OPT/consumer.out" 2>&1 || {
    cat "$BUILD/$OPT/consumer.out" >&2
    exit 1
  }

  grep '^FKT13_ENDPOINT ' "$BUILD/$OPT/reference.out" > "$BUILD/$OPT/reference.endpoint"
  grep '^FKT13_ENDPOINT ' "$BUILD/$OPT/consumer.out" > "$BUILD/$OPT/consumer.endpoint"
  cmp "$BUILD/$OPT/reference.endpoint" "$BUILD/$OPT/consumer.endpoint"

  : > "$BUILD/$OPT/negative.out"
  for CASE_STATUS in \
    wrong_schema.restart:3 \
    wrong_layout.restart:4 \
    unknown_codec.restart:5 \
    truncated.restart:2 \
    duplicate_revision.restart:2 \
    inconsistent_time.restart:6 \
    invalid_lineage.restart:6 \
    invalid_revision.restart:6 \
    invalid_payload.restart:7; do
    CASE="${CASE_STATUS%%:*}"
    EXPECTED="${CASE_STATUS##*:}"
    "$BUILD/$OPT/fkt13_negative_probe" "$BUILD/$OPT/$CASE" "$EXPECTED" >> "$BUILD/$OPT/negative.out" 2>&1 || {
      cat "$BUILD/$OPT/negative.out" >&2
      exit 1
    }
  done

done

# Both compiler policies must produce the same external representation and
# exactly the same observable qualification result.
cmp "$BUILD/o0/valid.restart" "$BUILD/o2/valid.restart"
cmp "$BUILD/o0/unit.out" "$BUILD/o2/unit.out"
cmp "$BUILD/o0/reference.out" "$BUILD/o2/reference.out"
cmp "$BUILD/o0/producer.out" "$BUILD/o2/producer.out"
cmp "$BUILD/o0/consumer.out" "$BUILD/o2/consumer.out"
cmp "$BUILD/o0/negative.out" "$BUILD/o2/negative.out"

for marker in \
  'FKT13_ATOMIC_TRUSTED_RECONSTRUCTION_VALID=PASS' \
  'FKT13_NO_INDEPENDENT_OVERWRITE_PATH=PASS' \
  'FKT13_SCHEMA_LAYOUT_PROVENANCE_PHYSICAL_TIME_FAIL_CLOSED=PASS' \
  'FKT13_TRUSTED_RECONSTRUCTION_UNIT_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/o0/unit.out" || { cat "$BUILD/o0/unit.out" >&2; exit 1; }
done
for marker in \
  'FKT13_CONTINUOUS_REFERENCE_MASS_AND_PROVENANCE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/reference.out" || { cat "$BUILD/o0/reference.out" >&2; exit 1; }
done
for marker in \
  'FKT13_PRODUCER_T1_EXPORT_AND_EXTERNAL_WRITE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/producer.out" || { cat "$BUILD/o0/producer.out" >&2; exit 1; }
done
for marker in \
  'FKT13_RECONSTRUCTION_RESTORE_ZERO_TRANSFER=PASS' \
  'FKT13_NEXT_CHECKPOINT_AND_CANDIDATE_PROVENANCE_EXACT=PASS' \
  'FKT13_MASS_CONTINUATION_WITHOUT_STORAGE_RESET=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/consumer.out" || { cat "$BUILD/o0/consumer.out" >&2; exit 1; }
done
[[ "$(grep -Fc 'FKT13_NEGATIVE_EXPECTED_REJECTION' "$BUILD/o0/negative.out")" -eq 9 ]] || {
  cat "$BUILD/o0/negative.out" >&2
  exit 1
}

cat "$BUILD/o0/unit.out"
cat "$BUILD/o0/reference.out"
cat "$BUILD/o0/producer.out"
cat "$BUILD/o0/consumer.out"
cat "$BUILD/o0/negative.out"
echo 'FKT13_TWO_SEPARATE_OS_PROCESSES_PRODUCER_THEN_CONSUMER=PASS'
echo 'FKT13_CONTINUOUS_VERSUS_PROCESS_RESTART_ENDPOINT_EXACT=PASS'
echo 'FKT13_EXTERNAL_REPRESENTATION_O0_O2_IDENTITY=PASS'
echo 'FKT13_EXTERNAL_NEGATIVE_CASES_FAIL_CLOSED=PASS'
echo 'FKT13_EXTERNAL_RECONSTRUCTION_QUALIFICATION_GATE PASS'
