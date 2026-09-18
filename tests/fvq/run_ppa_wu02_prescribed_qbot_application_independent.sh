#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "PPA_WU02_INDEPENDENT_FAIL $*" >&2; exit 1; }

CANONICAL="$(git merge-base HEAD origin/integration/f-ci-canonical)"\n[[ -n "$CANONICAL" ]] || fail "cannot resolve current canonical merge base"
BOOT="src/runtime/mod_fmr_production_application_bootstrap.f90"

changed_src="$(git diff --name-only "$CANONICAL"...HEAD -- src | sort)"
[[ "$changed_src" == "$BOOT" ]] || fail "production scope widened: $changed_src"

# The scientific qbot owner is intentionally inherited, not rewritten here.
for locked in \
  src/adapter/mod_b110_serialized_context_binding.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/solver/mod_reference_richards_temporal_indicator.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/legacy/b1_10_port/headcalc.f90; do
  [[ "$(git rev-parse "HEAD:$locked")" == "$(git rev-parse "$CANONICAL:$locked")" ]] || fail "science owner drift: $locked"
done

grep -Fq '"conclusion": "success"' qualification/F-VQ75_STATUS.json || fail 'independent F-VQ75 PASS absent'
grep -Fq '"unsupported_nearby_bottom_mode_fail_closed": true' qualification/F-VQ75_STATUS.json || fail 'F-VQ75 fail-closed evidence absent'
grep -Fq '"O0_O2_semantic_identity": true' qualification/F-VQ75_STATUS.json || fail 'F-VQ75 O0/O2 evidence absent'
grep -Fq '"production_canonical_admitted": true' integration/f-ci/F-CI62P_STATUS.json || fail 'F-CI62P production admission absent'

# Independent application-surface audit: exactly one additional homogeneous
# profile is admitted; groundwater ownership remains mode 5 only.
python3 - <<'PY'
from pathlib import Path
src=Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text()
assert "prescribed_qbot_profile = .true." in src
assert "prescribed_qbot_profile = prescribed_qbot_profile .and. config%tiles(i)%parameters%bottom_mode == 2" in src
assert "if (.not. groundwater_profile .and. .not. standalone_profile .and. .not. prescribed_qbot_profile) then" in src
assert "tile%parameters%bottom_mode /= 2" in src
assert "ready = self%registry%active_count() == size(self%columns) .and. all(self%participant_handles > 0_int64) .and. &" in src
assert "all(self%parameters%bottom_mode == 5)" in src
for forbidden in ("readswap", "open(", "command_argument", "environment_variable"):
    assert forbidden not in src.lower(), forbidden
print("PPA_WU02_INDEPENDENT_APPLICATION_SURFACE=PASS")
print("PPA_WU02_INDEPENDENT_GROUNDWATER_OWNERSHIP_PRESERVED=PASS")
PY

# Observe the owner runtime gate rather than introducing a second physics oracle.
tmp="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu02-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
bash tests/fapp/run_ppa_wu02_prescribed_qbot_application_admission.sh >"$tmp/wu02.txt" 2>&1 || {
  cat "$tmp/wu02.txt" >&2
  fail 'owner application runtime replay'
}
for marker in \
  'PPA_WU02_NONZERO_PRESCRIBED_QBOT_REACHED=PASS' \
  'PPA_WU02_GENERIC_TIME_ENDPOINT=PASS' \
  'PPA_WU02_STANDALONE_HARD_MASS=PASS' \
  'PPA_WU02_O0_O2_OUTPUT_IDENTITY=PASS' \
  'PPA-WU02 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS'; do
  grep -Fq "$marker" "$tmp/wu02.txt" || { cat "$tmp/wu02.txt" >&2; fail "missing marker $marker"; }
done

# Prior application profiles and exact legacy zero-flux mapping remain untouched.
bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh >"$tmp/wu01.txt" 2>&1 || {
  cat "$tmp/wu01.txt" >&2
  fail 'PPA-WU01 preservation'
}
grep -Fq 'PPA_WU01_STANDALONE_REFERENCE_RICHARDS_RUNTIME=PASS' "$tmp/wu01.txt" || fail 'mode7 application preservation'
grep -Fq 'PPA_WU01_FGC49D_CONTEXT_FROM_PRODUCTION_OWNER=PASS' "$tmp/wu01.txt" || fail 'mode5 groundwater preservation'

binding="src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90"
[[ "$(git rev-parse "HEAD:$binding")" == "$(git rev-parse "$CANONICAL:$binding")" ]] || fail 'SWBOTB=6 adapter changed'
grep -Fq 'if (legacy_swbotb == 6) then' "$binding" || fail 'SWBOTB=6 mapping absent'
grep -Fq 'binding%typed_bottom_flux = 0.0_real64' "$binding" || fail 'SWBOTB=6 zero flux absent'

echo 'PPA_WU02_INDEPENDENT_FVQ75_SCIENCE_INHERITANCE=PASS'
echo 'PPA_WU02_INDEPENDENT_WU01_PRESERVATION=PASS'
echo 'PPA_WU02_INDEPENDENT_SWBOTB6_PRESERVATION=PASS'
echo 'PPA-WU02 INDEPENDENT QUALIFICATION PASS'
