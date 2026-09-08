#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr11-pre-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F-MR11_PRE_ADMISSION_FAIL $*" >&2; exit 1; }

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:${path}")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch ${path}: ${actual} != ${expected}"
  echo "F-MR11_SOURCE_LOCK PASS ${path} ${actual}"
}

# Exact F-SI12 -> F-SI16 production seam. These replace the older F-SI11-era
# solver blobs carried by F-MR10; they are expected deltas in F-MR11.
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c
check_blob src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6

echo "F-MR11_FSI12_FSI16_SOLVER_POSTIMAGE_LOCK PASS"

# Reuse the functional halves of the qualified F-MR10 and F-MR09 gates. Their
# leading source/delta locks intentionally pin the older F-SI11 solver and are
# therefore not valid regressions after the qualified F-SI12->F-SI16 overlay.
# Everything from the static runtime assertions through compilation, execution,
# O0/O2 comparison and scientific-output checks is preserved byte-for-byte.
make_functional_gate() {
  local source="$1" output="$2" label="$3"
  python3 - "$source" "$output" "$label" <<'PY'
from pathlib import Path
import sys
src, out, label = sys.argv[1:]
text = Path(src).read_text()
marker = "python3 - <<'PY'\n"
pos = text.find(marker)
if pos < 0:
    raise SystemExit(f"missing functional marker in {src}")
tail = text[pos:]
header = f'''#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BUILD="${{TMPDIR:-/tmp}}/swap5-{label}-functional-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
'''
Path(out).write_text(header + tail)
PY
  chmod +x "$output"
}

make_functional_gate tests/fmr/run_fmr10_root_uptake_binding_gate.sh "$BUILD/fmr10-functional.sh" fmr10
make_functional_gate tests/fmr/run_fmr09_root_sink_runtime_gate.sh "$BUILD/fmr09-functional.sh" fmr09

bash "$BUILD/fmr10-functional.sh"
echo "F-MR11_FMR10_FUNCTIONAL_REGRESSION PASS"

bash "$BUILD/fmr09-functional.sh"
echo "F-MR11_FMR09_FUNCTIONAL_REGRESSION PASS"

echo "F-MR11_PRE_ADMISSION_GATE PASS"
