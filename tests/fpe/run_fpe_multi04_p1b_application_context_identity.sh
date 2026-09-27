#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi04-p1b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/probe.py" <<'PY'
import ctypes, os, sys
from pathlib import Path
lib=ctypes.CDLL(str(Path(os.environ["FGC49D_APPLICATION_LIB"]).resolve()))
init=lib.fgc49d_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
handle=ctypes.c_int64(); h1=ctypes.c_double(); h2=ctypes.c_double()
assert init(ctypes.byref(handle),ctypes.byref(h1),ctypes.byref(h2))==0
capture=lib.fgc49d_capture_origins_c; capture.restype=ctypes.c_int; capture.argtypes=[ctypes.c_int64]
trial=lib.fgc49d_trial_cell_heads_c; trial.restype=ctypes.c_int
trial.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
tangent=lib.fgc49d_trial_response_tangents_c; tangent.restype=ctypes.c_int
tangent.argtypes=[ctypes.c_int64,ctypes.c_int,ctypes.POINTER(ctypes.c_double)]
discard=lib.fgc49d_discard_candidates_c; discard.restype=ctypes.c_int; discard.argtypes=[ctypes.c_int64]
abort=lib.fgc49d_abort_prepublication_c; abort.restype=ctypes.c_int; abort.argtypes=[ctypes.c_int64]
release=lib.fgc49d_release_context_c; release.restype=ctypes.c_int; release.argtypes=[ctypes.c_int64]
assert capture(handle.value)==0
heads=(ctypes.c_double*2)(h1.value,h2.value)
flux=(ctypes.c_double*2)()
tan=(ctypes.c_double*2)()
assert trial(handle.value,2,heads,flux)==0
assert tangent(handle.value,2,tan)==0
print("MULTI04_P1B_FLUX="+",".join(f"{x:.17e}" for x in flux))
print("MULTI04_P1B_TANGENT="+",".join(f"{x:.17e}" for x in tan))
assert discard(handle.value)==0
assert abort(handle.value)==0
assert release(handle.value)==0
print("FGC49D_MULTI04_P1B=PASS")
print("F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS")
PY

for workers in 1 2 4; do
  fixture="$BUILD/fixture_w${workers}.f90"
  runner="$BUILD/run_w${workers}.sh"
  cp tests/fgc/support/mod_fgc49d_application_context_fixture.f90 "$fixture"
  python3 - "$fixture" "$workers" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); workers=int(sys.argv[2]); s=p.read_text()
if workers>1:
    decl="  type(fmr_serialized_reference_backend_t), target, save :: backend\n"
    repl=decl+f"  integer, parameter :: MULTI04_WORKERS = {workers}\n  type(fmr_serialized_reference_backend_t), target, save :: worker_backends(MULTI04_WORKERS)\n"
    if decl not in s: raise SystemExit("backend declaration seam missing")
    s=s.replace(decl,repl,1)
    init="    call backend%initialize(top)\n"
    repl=init+"    do i = 1, MULTI04_WORKERS\n      call worker_backends(i)%initialize(top)\n    end do\n"
    if init not in s: raise SystemExit("backend init seam missing")
    s=s.replace(init,repl,1)
    bind="    call context%bind(plan, registry, handles, ledgers, status)\n"
    repl="    call context%bind(plan, registry, handles, ledgers, status, worker_backends=worker_backends, &\n         worker_count=MULTI04_WORKERS)\n"
    if bind not in s: raise SystemExit("context bind seam missing")
    s=s.replace(bind,repl,1)
p.write_text(s)
PY

  cp tests/fgc/run_fgc49d_production_application_context.sh "$runner"
  python3 - "$runner" "$fixture" "$BUILD/probe.py" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); fixture=Path(sys.argv[2]).resolve(); probe=Path(sys.argv[3]).resolve()
s=p.read_text()
s=s.replace('ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"','ROOT="$(pwd)"',1)
s=s.replace('tests/fgc/support/mod_fgc49d_application_context_fixture.f90',str(fixture))
s=s.replace('python3 tests/fgc/test_fgc49d_production_application_context.py',f'python3 "{probe}"')
p.write_text(s)
PY
  bash "$runner" > "$BUILD/w${workers}.txt"
  grep '^MULTI04_P1B_' "$BUILD/w${workers}.txt" > "$BUILD/w${workers}.values"
  grep -Fq 'FGC49D_MULTI04_P1B=PASS' "$BUILD/w${workers}.txt"
done

diff -u "$BUILD/w1.values" "$BUILD/w2.values"
diff -u "$BUILD/w1.values" "$BUILD/w4.values"
cat "$BUILD/w1.values"
echo 'FPE_MULTI04_P1B_APPLICATION_CONTEXT_Q_IDENTITY=PASS'
echo 'FPE_MULTI04_P1B_APPLICATION_CONTEXT_TANGENT_IDENTITY=PASS'
echo 'FPE_MULTI04_P1B_APPLICATION_CONTEXT_DISCARD_ABORT=PASS'
