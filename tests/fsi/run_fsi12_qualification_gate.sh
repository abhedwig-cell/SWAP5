#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI11_HEAD="9f488bfb4805791e9513bfa7146c59d38423917b"
TMP_CORE="$ROOT/tests/fsi/.fsi12-core-$$.sh"
BUILD="${TMPDIR:-/tmp}/swap5-fsi12-qualification-$$"
REG="$BUILD/fsi11"
mkdir -p "$BUILD"
cleanup() {
  rm -f "$TMP_CORE"
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $REG"; then
    git -C "$ROOT" worktree remove --force "$REG" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT

cd "$ROOT"
# Preserve the already successful control-poison core from the first gate while
# replacing only its historically invalid legacy-direct harness.
awk '/^# Legacy direct-call compatibility:/{exit} {print}' tests/fsi/run_fsi12_explicit_controls_gate.sh > "$TMP_CORE"
chmod +x "$TMP_CORE"
bash "$TMP_CORE"
echo 'F-SI12_CONTROL_POISON_CORE PASS'

bash tests/fsi/run_fsi12_legacy_direct_identity_gate.sh

# Exact prior qualification, evaluated in its own source tree.
git worktree add --detach "$REG" "$FSI11_HEAD" >/dev/null
(
  cd "$REG"
  bash tests/fsi/run_fsi11_root_sink_provider_gate.sh >/dev/null
  bash tests/fsi/run_fsi11_swkimpl1_reject_gate.sh >/dev/null
  bash tests/fsi/run_fsi11_fsi10_pinned_regression_gate.sh >/dev/null
)
git worktree remove --force "$REG" >/dev/null
echo 'F-SI12_FSI11_PINNED_REGRESSION PASS'

# Request-side implicit-K remains explicitly outside the admitted route.
grep -Fq 'if (request%numerical%conductivity_implicit_mode /= 0) then' src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq "route = 'legacy-implicit-k-deferred'" src/adapter/mod_reference_richards_legacy_binding.f90
echo 'F-SI12_SWKIMPL1_REQUEST_HOLD PRESERVED'

bash tests/fci/run_fci03_gate.sh >/dev/null
echo 'F-SI12_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI12_EXPLICIT_SOLVER_CONTROLS QUALIFIED_CANDIDATE'
echo 'F-SI12_SWKIMPL1 NOT_ADMITTED'
echo 'F-SI12_MACROPORE NOT_ADMITTED'
echo 'F-SI12_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI12_QUALIFICATION_GATE PASS'
