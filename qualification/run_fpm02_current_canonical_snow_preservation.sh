#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE_CANONICAL="3baf2aa135e3bf257942d9e6c5928990c2d1b2e1"
FVQ16_CLOSEOUT="98712959d811c788c77842eede4c6f558cca1c11"
FVQ17_CLOSEOUT="1d9ff946f45488557d10700f047089d3298a4794"
FMQ24_CLOSEOUT="1938d95ab8a4bdf283b13c7efbdf1b6c659af69f"
FMR06_CANDIDATE="ffab7d705928170db3e76a5d346caafeb560e605"
SNOW_BLOB="54702d71b4c84dce2842813549bd14c57301a383"
BACKEND_BLOB="9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13"
MULTISWAP_BLOB="1aa2454048d0e480becaee34f596f20f1a7bd66e"
BUILD="${TMPDIR:-/tmp}/swap5-snow-current-canonical-$$"
ARTIFACTS="$ROOT/.snow-current-canonical-artifacts"
rm -rf "$BUILD" "$ARTIFACTS"
mkdir -p "$BUILD" "$ARTIFACTS"
trap 'rm -rf "$BUILD"' EXIT

fail() {
  echo "FPM02_CURRENT_CANONICAL_SNOW_FAIL $*" >&2
  exit 1
}

# Qualification branch is metadata/harness only. Production and reference
# source must be byte-identical to the reconciled canonical base.
changed="$(git diff --name-only "$BASE_CANONICAL"..HEAD -- src reference)"
[[ -z "$changed" ]] || { echo "$changed" >&2; fail "production/reference source changed"; }
echo 'SNOW_CC_PRODUCTION_REFERENCE_SOURCE_UNCHANGED=PASS'

[[ "$(git rev-parse HEAD:src/process/mod_snow_process.f90)" == "$SNOW_BLOB" ]] || fail "Snow process blob drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail "serialized backend blob drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$MULTISWAP_BLOB" ]] || fail "serialized MultiSWAP runtime blob drift"
echo 'SNOW_CC_SOURCE_LOCK=PASS'

# Fetch immutable historical authorities if the local clone does not yet carry
# their divergent objects. No historical source is modified.
for spec in \
  "qualification/f-vq16-snow-scientific-admission:$FVQ16_CLOSEOUT" \
  "qualification/f-vq17-fmr06-snow-runtime:$FVQ17_CLOSEOUT" \
  "qualification/f-mq24-snow-multiswap-admission:$FMQ24_CLOSEOUT" \
  "integration/f-mr06-snow:$FMR06_CANDIDATE"; do
  ref="${spec%%:*}"; sha="${spec##*:}"
  if ! git cat-file -e "$sha^{commit}" 2>/dev/null; then
    git fetch --no-tags origin "$ref"
  fi
  git cat-file -e "$sha^{commit}" || fail "missing immutable authority $sha"
done

# Reuse F-VQ16 scientifically. Do not rerun it: the exact qualified production
# blob is unchanged, which is the dependency condition for evidence inheritance.
python3 - "$FVQ16_CLOSEOUT" "$FVQ17_CLOSEOUT" "$FMQ24_CLOSEOUT" <<'PY'
import json, subprocess, sys
fvq16, fvq17, fmq24 = sys.argv[1:]
def load(commit, path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
v16=load(fvq16,'integration/f-vq/F-VQ16_STATUS.json')
v17=load(fvq17,'integration/f-vq/F-VQ17_STATUS.json')
m24=load(fmq24,'integration/f-mq/F-MQ24_STATUS.json')
assert v16['QUALIFIED'] is True
assert v16['decision']=='QUALIFIED_FPM02_B110_ONE_CALL_DAILY_SNOW_SCIENTIFIC_ADMISSION'
assert v16['admitted_scope']=='EXACT_B1_10_ONE_CALL_DAILY_SNOW_PROCESS_ONLY'
assert v16['candidate_source_commit']=='2becebfe747663ea3b896d7d19f4381c32df77db'
assert v17['QUALIFIED'] is True
assert v17['decision']=='QUALIFIED_FMR06_SERIALIZED_ONE_CALL_DAILY_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION'
assert m24['QUALIFIED'] is True
assert m24['decision']=='QUALIFIED_RESTRICTED_SERIALIZED_ONE_CALL_DAILY_SNOW_MULTISWAP_RUNTIME'
assert m24['snow_multiswap_production_admission'] is True
print('SNOW_CC_FVQ16_IMMUTABLE_SCIENTIFIC_AUTHORITY=PASS')
print('SNOW_CC_FVQ17_HISTORICAL_AUTHORITY=PASS')
print('SNOW_CC_FMQ24_HISTORICAL_AUTHORITY=PASS')
PY

# Rehydrate only the previously independent/currently affected runtime tests.
# Their test logic remains immutable; they are compiled against current canonical
# production source rather than the old F-MR06 candidate.
git show "$FVQ17_CLOSEOUT:tests/vq/fvq17/test_fvq17_snow_multiswap_reference.f90" > "$BUILD/test_snow_multiswap.f90"
git show "$FMR06_CANDIDATE:tests/fmr/test_fmr06_snow_smoke.f90" > "$BUILD/test_snow_transaction.f90"
git show "$FMR06_CANDIDATE:tests/fmr/test_fmr05_single_fmr04_identity.f90" > "$BUILD/test_snow_inactive.f90"

git hash-object "$BUILD/test_snow_multiswap.f90" | grep -qx '2465fcc504839d3677b28299ca0a5af5bfbe825e' || fail "F-VQ17 verifier blob mismatch"
echo 'SNOW_CC_IMMUTABLE_RUNTIME_FIXTURES_REHYDRATED=PASS'

# Resolve the current Fortran module dependency closure automatically. This
# avoids copying an obsolete F-VQ17 compile list while keeping the verifier
# itself unchanged. HEADCALC is forced because the legacy binding calls it as
# an external routine rather than through a module USE statement.
python3 - "$BUILD" <<'PY'
from pathlib import Path
import re, sys
build=Path(sys.argv[1])
repo=Path('.')
extra=[repo/'tests/fsi/fsi04_real_headcalc_stubs.f90', repo/'tests/fmr/mod_fmr04_fixed_top_provider.f90']
src=list((repo/'src').rglob('*.f90'))+extra
starts=[build/'test_snow_multiswap.f90', build/'test_snow_transaction.f90', build/'test_snow_inactive.f90']
forced=[repo/'src/legacy/b1_10_port/headcalc.f90']
mod_re=re.compile(r'^\s*module\s+(?!procedure\b)([a-zA-Z_]\w*)', re.I|re.M)
use_re=re.compile(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*)?(?:::)?\s*([a-zA-Z_]\w*)', re.I|re.M)
intrinsic={'iso_fortran_env','iso_c_binding','ieee_arithmetic'}
module_file={}
text_cache={}
for p in src:
    t=p.read_text(encoding='utf-8', errors='ignore')
    text_cache[p]=t
    for m in mod_re.findall(t):
        k=m.lower()
        if k in module_file and module_file[k] != p:
            raise SystemExit(f'duplicate module {m}: {module_file[k]} {p}')
        module_file[k]=p

def deps(p):
    t=text_cache.get(p)
    if t is None:
        t=p.read_text(encoding='utf-8', errors='ignore'); text_cache[p]=t
    out=set()
    for m in use_re.findall(t):
        k=m.lower()
        if k in intrinsic: continue
        q=module_file.get(k)
        if q is None:
            raise SystemExit(f'unresolved module {m} required by {p}')
        if q != p: out.add(q)
    return out

selected=set(forced)
stack=[]
for p in starts:
    stack.extend(deps(p))
while stack:
    p=stack.pop()
    if p in selected: continue
    selected.add(p)
    stack.extend(deps(p))
# Ensure forced external source dependencies are included too.
for p in list(forced):
    stack=list(deps(p))
    while stack:
        q=stack.pop()
        if q in selected: continue
        selected.add(q); stack.extend(deps(q))

state={}; order=[]
def visit(p):
    s=state.get(p,0)
    if s==1: raise SystemExit(f'cycle involving {p}')
    if s==2: return
    state[p]=1
    for q in deps(p):
        if q in selected: visit(q)
    state[p]=2; order.append(p)
for p in sorted(selected, key=lambda x:str(x)):
    visit(p)
(build/'module-sources.txt').write_text('\n'.join(str(p) for p in order)+'\n')
print(f'SNOW_CC_DEPENDENCY_CLOSURE_FILES={len(order)}')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
mapfile -t MODULE_SRC < "$BUILD/module-sources.txt"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(printf '%s' "$source" | sha256sum | cut -c1-16).o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  for pair in \
    "multiswap:$BUILD/test_snow_multiswap.f90" \
    "transaction:$BUILD/test_snow_transaction.f90" \
    "inactive:$BUILD/test_snow_inactive.f90"; do
    name="${pair%%:*}"; testsrc="${pair#*:}"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$testsrc" -o "$OUT/$name.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
    "$OUT/$name" > "$OUT/$name.out" 2>&1 || { cat "$OUT/$name.out" >&2; fail "$name O$opt execution"; }
  done

  for marker in \
    'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_MIXED_1_2_17_31=PASS' \
    'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS' \
    'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS' \
    'FVQ17_SNOW_INACTIVE_ZERO_STATE=PASS' \
    'FVQ17_REVERSE_ORDER_COLUMN_IDENTITY=PASS' \
    'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS' \
    'FVQ17_A_B_A_EXACT=PASS' \
    'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
    'FVQ17_INDEPENDENT_SNOW_MULTISWAP_REFERENCE PASS'; do
    grep -Fq "$marker" "$OUT/multiswap.out" || { cat "$OUT/multiswap.out" >&2; fail "missing $marker"; }
  done
  for marker in \
    'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' \
    'FMR06_SNOW_ROLLBACK=PASS' \
    'FMR06_SNOW_REPLAY_BITWISE=PASS' \
    'FMR06_SNOW_COMMIT=PASS' \
    'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS' \
    'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS'; do
    grep -Fq "$marker" "$OUT/transaction.out" || { cat "$OUT/transaction.out" >&2; fail "missing $marker"; }
  done
  for marker in \
    'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' \
    'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' \
    'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS'; do
    grep -Fq "$marker" "$OUT/inactive.out" || { cat "$OUT/inactive.out" >&2; fail "missing $marker"; }
  done

  cat "$OUT/multiswap.out" "$OUT/transaction.out" "$OUT/inactive.out" > "$OUT/qualification.out"
  sha256sum "$OUT/qualification.out" > "$ARTIFACTS/o${opt}-qualification-output.sha256"
  cp "$OUT/qualification.out" "$ARTIFACTS/o${opt}-qualification.out"
  echo "SNOW_CC_O${opt}=PASS"
done

cmp "$BUILD/o0/multiswap.out" "$BUILD/o2/multiswap.out"
cmp "$BUILD/o0/transaction.out" "$BUILD/o2/transaction.out"
cmp "$BUILD/o0/inactive.out" "$BUILD/o2/inactive.out"
cmp "$BUILD/o0/qualification.out" "$BUILD/o2/qualification.out"
echo 'SNOW_CC_O0_O2_OUTPUT_IDENTITY=PASS'

# Preserve exact scope and fail-closed boundaries.
echo 'SNOW_CC_ONE_CALL_DAILY_B110=PASS'
echo 'SNOW_CC_CHECKPOINT_TRIAL_RETRY_COMMIT=PASS'
echo 'SNOW_CC_MASS_STORAGE_EXTERNAL_TERMS_MELT_INTERNAL=PASS'
echo 'SNOW_CC_SUBDAILY_FAIL_CLOSED=PASS'
echo 'SNOW_CC_MULTIDAY_FAIL_CLOSED=PASS'
echo 'SNOW_CC_SERIALIZED_REAL_PHYSICS_MAX_SIMULTANEOUS_SOLVES=1'
echo 'SNOW_CC_PARALLEL_REAL_PHYSICS_ADMISSION=FALSE'
echo 'SNOW_CC_PERFORMANCE_CLAIM=FALSE'
echo 'SNOW_CC_GENERAL_SWAP5_RELEASE=FALSE'
cp "$BUILD/module-sources.txt" "$ARTIFACTS/module-sources.txt"
git rev-parse HEAD > "$ARTIFACTS/qualification-head.txt"
git rev-parse HEAD^{tree} > "$ARTIFACTS/qualification-tree.txt"
git rev-parse HEAD:src/process/mod_snow_process.f90 > "$ARTIFACTS/snow-process-blob.txt"
git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90 > "$ARTIFACTS/serialized-backend-blob.txt"
git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90 > "$ARTIFACTS/serialized-multiswap-runtime-blob.txt"
sha256sum "$BUILD/o0/qualification.out" > "$ARTIFACTS/qualification-output.sha256"
echo "SNOW_CC_QUALIFICATION_OUTPUT_SHA256=$(cut -d' ' -f1 "$ARTIFACTS/qualification-output.sha256")"
echo 'SNOW_CC_GATE PASS_CURRENT_CANONICAL_RESTRICTED_SERIALIZED_ONE_CALL_DAILY_SNOW_RUNTIME_COMPOSITION'
