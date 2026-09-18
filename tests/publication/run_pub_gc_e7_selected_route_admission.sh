#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail(){ echo "PUB_GC_E7_ROUTE_GATE_FAIL $*" >&2; exit 1; }

# Re-run the currently admitted owner qualification.  This dynamically proves
# that the WU03 adapter still fails closed for unsupported ET/interception
# selectors on the branch being tested.
bash tests/fapp/run_ppa_wu03_common_forcing_adapter.sh > /tmp/pub_gc_e7_wu03.txt 2>&1 || {
  cat /tmp/pub_gc_e7_wu03.txt >&2
  fail "PPA-WU03 preservation/current qualification"
}
grep -Fq 'PPA_WU03_UNSUPPORTED_OPTIONS_FAIL_CLOSED=PASS' /tmp/pub_gc_e7_wu03.txt || fail "missing fail-closed marker"
grep -Fq 'PPA-WU03 COMMON FORCING OWNER QUALIFICATION PASS' /tmp/pub_gc_e7_wu03.txt || fail "missing WU03 gate marker"

python3 - <<'PY'
import json
from datetime import date
from pathlib import Path

binding=json.loads(Path("docs/publication/PUB_GC_E7_SELECTED_ROUTE_BINDING.json").read_text())
selection=json.loads(Path("docs/publication/PUB_GC_E7_STANDALONE_SELECTION_RESULT.json").read_text())
fapp03=json.loads(Path("integration/f-app/F-APP03_HUPSEL_AUTHORITY_RESTORED.json").read_text())
wu03=json.loads(Path("integration/audits/PPA_WU03_STATUS.json").read_text())
adapter=Path("src/adapter/mod_ppa_wu03_common_forcing_adapter.f90").read_text().lower()

assert selection["status"]=="FROZEN_BEFORE_COUPLED_OUTPUT"
assert selection["coupled_output_observed"] is False
assert selection["selected_days"]["median_dynamics_control"]["date"]=="2003-06-17"
assert selection["selected_days"]["high_dynamics_day"]["date"]=="2003-05-20"

route=binding["application_route"]
start=date.fromisoformat(route["crop_start"])
end=date.fromisoformat(route["crop_end"])
for d in binding["selected_dates"]:
    dd=date.fromisoformat(d)
    assert start <= dd <= end, (d,start,end)

auth=fapp03["restored_official_distribution"]
assert auth["sha256"]==binding["exact_distribution"]["sha256"]
assert fapp03["hupsel_fixture_members"]["swap.swp"]["sha256"]==binding["exact_distribution"]["swap_swp_sha256"]
assert fapp03["hupsel_fixture_members"]["potato.crp"]["sha256"]==binding["exact_distribution"]["potato_crp_sha256"]
assert fapp03["selectors_confirmed_from_exact_Hupsel_inputs"]["SWETR"]==0
assert route["global_SWETR"]==0
assert route["potato_SWCF"]==2
assert route["potato_SWINTER"]==3

assert wu03["state"]=="CANONICAL_ADMITTED_CLOSED"
env=wu03["admitted_candidate_envelope"]
assert "SWETR=1" in env["et"]
assert "SWINTER=0" in env["interception"]
claims="\n".join(wu03["explicit_nonclaims"]).lower()
assert "swetr=0" in claims and "pmdirect" in claims
assert "swinter=3" in claims and "rutter" in claims

# Source-level fail-closed semantics: any ET mode other than the single
# admitted reference mode is rejected, and interception mode other than NONE
# is rejected before a forcing result is produced.
assert "if (config%et_mode /= ppa_wu03_et_reference)" in adapter
assert "diagnostics%status = ppa_wu03_unsupported_et" in adapter
assert "if (config%interception_mode /= ppa_wu03_interception_none)" in adapter
assert "diagnostics%status = ppa_wu03_unsupported_interception" in adapter

print("PUB_GC_E7_SELECTED_ROUTE_BINDING=PASS")
print("PUB_GC_E7_SELECTED_DATES_PRECOUPLED_FREEZE=PASS")
print("PUB_GC_E7_EXACT_HUPSEL_AUTHORITY=PASS")
print("PUB_GC_E7_PMDIRECT_PRODUCTION_ADMISSION=FAIL_CLOSED_EXPECTED")
print("PUB_GC_E7_RUTTER_PRODUCTION_ADMISSION=FAIL_CLOSED_EXPECTED")
print("PUB_GC_E7_COMPONENT_PARTICIPANT_AVAILABLE=NO")
print("PUB_GC_E7_LIVE_MODFLOW_SKIPPED_COMPONENT_UNAVAILABLE=PASS")
print("PUB_GC_E7_OUTCOME=REALISTIC_COMPONENT_DOMAIN_LIMIT")
PY

cat /tmp/pub_gc_e7_wu03.txt | grep '^PPA_WU03_' || true
echo 'PUB-GC E7 SELECTED ROUTE ADMISSION QUALIFICATION PASS'
