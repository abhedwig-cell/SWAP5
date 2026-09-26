#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "TEMPORAL08_P2_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
src=Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text().lower()

required=[
    "fmr_groundwater_temporal_budget_policy_t",
    "fmr_gw_history_temporal_coefficient = 0.65_real64",
    "fmr_gw_history_temporal_floor_cm = 1.0e-5_real64",
    "numerical_continuation_layout_id == fmr_numerical_continuation_richards_temporal_history",
    "transaction%temporal_mode == tx_temporal_model_certificate",
    "temporal_budget_policy%enabled = .true.",
    "temporal_budget_policy%coefficient = fmr_gw_history_temporal_coefficient",
    "temporal_budget_policy%floor_cm = fmr_gw_history_temporal_floor_cm",
    "temporal_budget_policy=temporal_budget_policy",
    "if (.not. allocated(config%tiles(i)%initial_right_derivative)) then",
    "any(.not. ieee_is_finite(config%tiles(i)%initial_right_derivative))",
]
for token in required:
    assert token in src, token

# Scope must remain inside the mode-5 groundwater branch and the bootstrap
# must continue rejecting the process owners excluded by the admitted profile.
for token in [
    "groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5",
    "drainage_response_active",
    "root_extraction_active",
    "macropore_active",
    "snow_active",
    "tabulated_hydraulics_active",
]:
    assert token in src, token

print("FPE_TEMPORAL08_BOOTSTRAP_BINDING_STATIC=PASS")
print("FPE_TEMPORAL08_BOUNDED_GROUNDWATER_SCOPE_STATIC=PASS")
print("FPE_TEMPORAL08_SEEDED_HISTORY_REQUIRED_STATIC=PASS")
PY

bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh | tee /tmp/temporal08-ppa-wu01.txt
grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS' /tmp/temporal08-ppa-wu01.txt || fail "PPA-WU01 owner marker"
grep -Fq 'PPA_WU01_GROUNDWATER_ACTIVE_PROCESS_COMPOSITION_FAIL_CLOSED=PASS' /tmp/temporal08-ppa-wu01.txt || fail "bounded profile marker"

echo 'FPE_TEMPORAL08_P2_BOOTSTRAP_PRESERVATION=PASS'
