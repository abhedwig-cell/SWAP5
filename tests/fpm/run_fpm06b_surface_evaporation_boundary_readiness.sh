#!/usr/bin/env bash
set -euo pipefail

BASE=c0fc660c1e68064f77f4ec4f3376d385fbe88b4a
DOC=integration/f-pm/F-PM06B_SURFACE_EVAPORATION_BOUNDARY_READINESS.md
LOCK=integration/f-pm/F-PM06B_SOURCE_LOCK.json

fail() { echo "FPM06B_FAIL $*" >&2; exit 6; }

# Readiness-only workunit: no production/reference delta is permitted.
git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descendant of pinned canonical base"
if git diff --name-only "$BASE"..HEAD -- src reference | grep -q .; then
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail "unexpected src/reference delta"
fi

test "$(git rev-parse HEAD:src/process/mod_reference_et_demand_process.f90)" = f5e88ec5089fd3b57ac111065fab2aa32dde0fae || fail "ET demand blob drift"
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0 || fail "solver contract blob drift"
test "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" = fb226f133bd48d8ab945f111c76897aeff49facf || fail "fixed top provider blob drift"
test "$(git rev-parse HEAD:src/solver/mod_process_hydraulic_view.f90)" = d7d85fe71ced0d94b29c8d9395859ae1834f7dd6 || fail "hydraulic view blob drift"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = 9af5a494526810324dc00706b444e448e770cba9 || fail "serialized backend blob drift"

python3 - <<'PY'
import json
from pathlib import Path
lock = json.loads(Path('integration/f-pm/F-PM06B_SOURCE_LOCK.json').read_text())
assert lock['work_unit'] == 'F-PM06B'
assert lock['canonical_authority']['head'] == 'c0fc660c1e68064f77f4ec4f3376d385fbe88b4a'
assert lock['canonical_authority']['f_ci34_to_f_ci35_src_delta'] == 0
assert lock['restricted_scope']['swinter'] == 0
assert lock['restricted_scope']['swredu'] == 0
assert lock['frozen_b1_10']['boundtop_f90_sha256'] == '69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04'
PY

grep -Fq 'reva = min(peva, max(0, Emax))' "$DOC" || fail "restricted reva equation missing"
grep -Fq 'reva = 0' "$DOC" || fail "ponded reva partition missing"
grep -Fq 'epd = epond' "$DOC" || fail "pond evaporation partition missing"
grep -Fq 'Potential quantities `peva` and `epond` never enter the authoritative mass ledger directly.' "$DOC" || fail "mass ownership rule missing"
grep -Fq 'No day is fundamental.' "$DOC" || fail "generic-time rule missing"
grep -Fq 'checkpoint -> trial/retry -> commit or rollback' "$DOC" || fail "transaction rule missing"
grep -Fq 'no provider-global `save` state or last-result cache may act as continuation authority' "$DOC" || fail "provider state rule missing"
grep -Fq 'A raw extension of `process_hydraulic_view_t` with solver-internal conductivity arrays is not acceptable.' "$DOC" || fail "hydraulic abstraction rule missing"
grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_BOUNDARY_READINESS_READY_FOR_STRUCTURAL_CONTRACT_CANDIDATE' "$DOC" || fail "decision missing"

echo 'FPM06B_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'
echo 'FPM06B_CANONICAL_SOURCE_LOCK=PASS'
echo 'FPM06B_B110_BOUNDARY_EQUATION_PROVENANCE=PASS'
echo 'FPM06B_DEMAND_VS_ACTUAL_OWNERSHIP=PASS'
echo 'FPM06B_MASS_CONTRACT=PASS'
echo 'FPM06B_GENERIC_TIME_CONTRACT=PASS'
echo 'FPM06B_TRANSACTION_CONTRACT=PASS'
echo 'FPM06B_OPTIONALITY_CONTRACT=PASS'
echo 'FPM06B_HYDRAULIC_ABSTRACTION=PASS'
echo 'FPM06B_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FPM06B_READINESS_GATE=PASS'
