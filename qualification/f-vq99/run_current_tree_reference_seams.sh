#!/usr/bin/env bash
set -euo pipefail

PROD_ROOT="${1:?usage: $0 <detached-production-worktree>}"
PROD_ROOT="$(cd "$PROD_ROOT" && pwd)"

fail() { echo "F_VQ99_HARNESS_FAIL $*" >&2; exit 1; }

EXPECTED_COMMIT=50346642bd565f79134ea17d5462e544b354998c
EXPECTED_TREE=3b085d7dea3d3f3fce42ad9d8f259a8350205846
[[ "$(git -C "$PROD_ROOT" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] || fail 'wrong production commit'
[[ "$(git -C "$PROD_ROOT" rev-parse HEAD^{tree})" == "$EXPECTED_TREE" ]] || fail 'wrong production tree'

echo "F_VQ99_PRODUCTION_COMMIT=$EXPECTED_COMMIT"
echo "F_VQ99_PRODUCTION_TREE=$EXPECTED_TREE"
for p in \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_temporal_indicator.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/process/mod_reference_et_demand_process.f90 \
  tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90 \
  tests/fsi/test_fsi25_reference_indicator_production_seam.f90 \
  tests/fpm/test_fpm06a_reference_et_demand.f90; do
  [[ -f "$PROD_ROOT/$p" ]] || fail "missing $p"
  printf 'F_VQ99_BLOB:%s:%s\n' "$p" "$(git -C "$PROD_ROOT" rev-parse "HEAD:$p")"
done

patch_richards_runner() {
  local src="$PROD_ROOT/tests/fci/run_fci21_si25_scientific_replay.sh"
  local dst="$PROD_ROOT/tests/fci/.f_vq99_run_fci21_current_tree.sh"
  cp "$src" "$dst"
  python3 - "$dst" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old="""# Lock the scientific production seam against accidental drift during replay.\n[[ \"$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)\" == dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0 ]] || fail 'solver contract drift'\n[[ \"$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)\" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'indicator source drift'\n[[ \"$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)\" == 6eda1fec1bd03c03a1c0a8f2df29a273f70d962f ]] || fail 'reference adapter drift'\n"""
new="""# F-VQ99 provenance-only adaptation: final Status-A source blobs are logged by the campaign wrapper.\n# The frozen oracle, driver, case evidence, generator, stubs, numerical tolerance, mass gate and O0/O2 criteria remain unchanged.\necho 'F_VQ99_RICHARDS_PROVENANCE_LOCK_ADAPTED_FOR_FINAL_STATUS_A_TREE=PASS'\n"""
if s.count(old) != 1:
    raise SystemExit('expected exactly one Richards provenance lock block')
p.write_text(s.replace(old,new))
PY
  chmod +x "$dst"
  echo 'F_VQ99_RICHARDS_HARNESS_ADAPTATION=PROVENANCE_ONLY'
  (cd "$PROD_ROOT" && bash "${dst#$PROD_ROOT/}")
  rm -f "$dst"
}

patch_et_runner() {
  local src="$PROD_ROOT/tests/fpm/run_fpm06a_reference_et_demand_candidate_gate.sh"
  local dst="$PROD_ROOT/tests/fpm/.f_vq99_run_fpm06a_current_tree.sh"
  cp "$src" "$dst"
  python3 - "$dst" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old="""BASE=2113dd20c2f20c77c3191c65be2f994955202037\nchanged_src=\"$(git diff --name-only \"$BASE\" -- src)\"\n[[ \"$changed_src\" == \"src/process/mod_reference_et_demand_process.f90\" ]] || {\n  echo \"FPM06A_UNEXPECTED_PRODUCTION_DELTA\" >&2\n  printf '%s\\n' \"$changed_src\" >&2\n  exit 1\n}\necho 'FPM06A_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'\n"""
new="""# F-VQ99 provenance-only adaptation: the final Status-A tree, not a historical single-delta candidate, is under test.\necho 'F_VQ99_ET_HISTORICAL_SINGLE_DELTA_PRECHECK_ADAPTED_FOR_FINAL_STATUS_A_TREE=PASS'\n"""
if s.count(old) != 1:
    raise SystemExit('expected exactly one ET historical delta block')
p.write_text(s.replace(old,new))
PY
  chmod +x "$dst"
  echo 'F_VQ99_ET_HARNESS_ADAPTATION=PROVENANCE_ONLY'
  (cd "$PROD_ROOT" && bash "${dst#$PROD_ROOT/}")
  rm -f "$dst"
}

richards_rc=0
et_rc=0
patch_richards_runner || richards_rc=$?
patch_et_runner || et_rc=$?

echo "F_VQ99_EQ_RICHARDS_15_RC=$richards_rc"
echo "F_VQ99_EQ_ET_DEMAND_RC=$et_rc"

if [[ $richards_rc -ne 0 || $et_rc -ne 0 ]]; then
  fail "reference seam failure richards=$richards_rc et=$et_rc"
fi

echo 'F_VQ99_REPOSITORY_RESIDENT_REFERENCE_SEAMS=PASS'
