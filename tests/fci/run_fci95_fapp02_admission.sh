#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

canonical_preimage="e5ce2f3a410207cb5eaf03c9b10f1a29636146b3"
binding="src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90"
expected_binding_blob="456c87437e83d1d362d41fbf9820e70d96353ff9"
contract="src/solver/mod_soil_water_solver_contract.f90"
expected_contract_blob="276941d76ba951a89c43899e61fd0532418d8230"
state_binding="src/solver/mod_reference_richards_state_binding.f90"
expected_state_binding_blob="a2488ce3a6a6eff665a59d3dd68907d26f8304ec"
fvq102_authority="22c3f54187ebbf661ac5601c181163e3f3905889"

[[ "$(git merge-base "$canonical_preimage" HEAD)" == "$canonical_preimage" ]]
echo 'FCI95_CANONICAL_PREIMAGE=PASS'

[[ "$(git rev-parse "HEAD:${binding}")" == "$expected_binding_blob" ]]
echo 'FCI95_EXACT_QUALIFIED_BINDING_BLOB=PASS'

mapfile -t production_delta < <(git diff --name-only "$canonical_preimage"...HEAD -- src/)
[[ "${#production_delta[@]}" -eq 1 ]]
[[ "${production_delta[0]}" == "$binding" ]]
echo 'FCI95_SINGLE_PRODUCTION_DELTA=PASS'

[[ "$(git rev-parse "HEAD:${contract}")" == "$expected_contract_blob" ]]
[[ "$(git rev-parse "HEAD:${state_binding}")" == "$expected_state_binding_blob" ]]
echo 'FCI95_DEPENDENCY_LOCKS=PASS'

# Inherit only a persisted independent PASS tied to the exact same binding blob.
git cat-file -e "${fvq102_authority}^{commit}"
status_text="$(git show "${fvq102_authority}:integration/f-vq/F-VQ102_STATUS.json")"
grep -Fq '"final_verdict": "QUALIFIED_INDEPENDENT_READY_FOR_CURRENT_CANONICAL_ADMISSION"' <<<"$status_text"
grep -Fq '"binding_blob": "456c87437e83d1d362d41fbf9820e70d96353ff9"' <<<"$status_text"
grep -Fq '"conclusion": "success"' <<<"$status_text"
echo 'FCI95_INDEPENDENT_EVIDENCE_INHERITANCE=PASS'

# Admission-time surface guard: no widened authority appeared in the promoted module.
if grep -Ein '\b(open|close|read|write)\s*\(|path|file[_ -]?unit|command_argument|environment_variable|MOD_swap_base|use variables|HeadCalc|Richards' "$binding"; then
  echo 'FCI95_BOUNDED_APPLICATION_AUTHORITY=FAIL'
  exit 1
fi
echo 'FCI95_BOUNDED_APPLICATION_AUTHORITY=PASS'

grep -Fq 'if (legacy_swbotb == 6) then' "$binding"
grep -Fq 'binding%typed_bottom_mode = 2' "$binding"
grep -Fq 'binding%typed_bottom_flux = 0.0_real64' "$binding"
grep -Fq 'state%qbot = request%boundary%bottom_flux' "$state_binding"
echo 'FCI95_SEMANTIC_CHAIN_LOCK=PASS'

echo 'FCI95_FAPP02_CANONICAL_ADMISSION_GATE=PASS'
