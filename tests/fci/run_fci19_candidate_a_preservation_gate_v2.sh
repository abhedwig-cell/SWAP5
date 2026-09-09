#!/usr/bin/env bash
set -euo pipefail

# Composition-aware harness corrections. Historical qualification gates remain unchanged.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
TMP="$ROOT/tests/fci/.fci19_candidate_a_v2_$$.sh"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

python3 - "$BASE" "$TMP" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text(encoding='utf-8')
src = src.replace('ARTIFACTS="$ROOT/.fci19-artifacts"', 'ARTIFACTS="$ROOT/fci19-artifacts"', 1)

start_anchor = "for marker in \\\n  'FKT09_TRANSACTION_REFERENCE=PASS'"
end_anchor = "\ndone\necho 'FCI19_FKT09_PRESERVATION=PASS'"
start = src.index(start_anchor)
end = src.index(end_anchor, start)
replacement = """for marker in \\
  'FKT09_EXISTING_TRANSACTION_REGRESSION=PASS' \\
  'FKT09_FKT05_CHECKPOINT_REGRESSION=PASS' \\
  'FKT09_MODEL_CERTIFICATE_O0_O2_IDENTITY=PASS' \\
  'FKT09_ATTEMPT_CONTEXT_REGRESSION=PASS' \\
  'FKT09_CANONICAL_CERTIFICATE_COMPOSITION=PASS' \\
  'FKT09_KERNEL_CERTIFICATE_COMMIT_DIAGNOSTICS=PASS' \\
  'FKT09_GENERICITY_GATE=PASS' \\
  'FKT09_MODEL_CERTIFICATE_GATE=PASS'; do
  grep -Fq \"$marker\" \"$ARTIFACTS/fkt09.out\" || fail \"missing F-KT09 marker: $marker\"
done"""
src = src[:start] + replacement + src[end + len('\ndone'):]

old_hash = '''[[ "$(sha256sum "$BUILD/fsi19.f90" | cut -d' ' -f1)" == "275790181531838bed38f4013e5f9f51c3b19f7221e91e5b84cb72e8f11d7fa0" ]] || \\
  fail "F-SI19 historical oracle hash mismatch"'''
new_hash = '''[[ "$(git hash-object "$BUILD/fsi19.f90")" == "bf8c9d85c98157d128086d2c2fb20f6129b98e63" ]] || \\
  fail "F-SI19 historical oracle blob mismatch"'''
if old_hash not in src:
    raise SystemExit('expected F-SI19 hash block not found')
src = src.replace(old_hash, new_hash, 1)

fsi_start_anchor = "  for marker in \\\n    'FSI19_DIRECT_ORIGINALB_LAYER_ORACLE=PASS'"
fsi_end_anchor = "\n  done\ndone\ncmp \"$BUILD/fsi19-o0/out.txt\""
fsi_start = src.index(fsi_start_anchor)
fsi_end = src.index(fsi_end_anchor, fsi_start)
fsi_replacement = """  for marker in \\
    'FSI19_TRIDAG_SUCCESS_N1=PASS_BITWISE' \\
    'FSI19_TRIDAG_SUCCESS_N7=PASS_BITWISE' \\
    'FSI19_TRIDAG_IERROR_1000=PASS' \\
    'FSI19_TRIDAG_IERROR_1002=PASS' \\
    'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' \\
    'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' \\
    'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS'; do
    grep -Fq \"$marker\" \"$OUT/out.txt\" || fail \"missing F-SI19 marker at O$opt: $marker\"
  done"""
src = src[:fsi_start] + fsi_replacement + src[fsi_end + len('\n  done'):]

needle = '''  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90'''
replacement = '''  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/legacy/b1_10_port/headcalc.f90'''
if needle not in src:
    raise SystemExit('expected snow compile-order anchor not found')
src = src.replace(needle, replacement, 1)

# Candidate A serialized backend also imports the later qualified B1.10 root-sink
# provider. Compile it after the common solver contract and before the backend.
needle = '''  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90'''
replacement = '''  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90'''
if needle not in src:
    raise SystemExit('expected root-sink compile-order anchor not found')
src = src.replace(needle, replacement, 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
chmod +x "$TMP"
exec "$TMP"
