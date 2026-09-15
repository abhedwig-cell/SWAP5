#!/usr/bin/env bash
set -euo pipefail

CANONICAL=dffc021507460ab1a613dfd2e916def7f3db1ea7
OWNER_CHECKPOINT=fc5f9cc6bb4cc98f55dbe4ff0160dacdf1d4ee13
HISTORICAL_OWNER=4e7da5fd014c0eb799c6637a07dfd2f3e3c487c9
OWNER_BRANCH=work/f-gc28-groundwater-coupling-v1-completion-audit

# Independent evidence-only audit. No production/reference delta is allowed.
git merge-base --is-ancestor "$CANONICAL" HEAD
while IFS= read -r path; do
  case "$path" in
    .github/workflows/f-vq98-fgc28-groundwater-coupling-v1-completion-audit.yml|tests/qualification/fvq98/*|qualification/F-VQ98*) ;;
    *) echo "FVQ98_SCOPE_ALLOWLIST=FAIL:$path"; exit 1 ;;
  esac
done < <(git diff --name-only "$CANONICAL" HEAD)
echo "FVQ98_SCOPE_ALLOWLIST=PASS"

git fetch --no-tags origin \
  "refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "refs/heads/${OWNER_BRANCH}:refs/remotes/origin/${OWNER_BRANCH}"

LIVE_CANONICAL=$(git rev-parse refs/remotes/origin/integration/f-ci-canonical)
LIVE_OWNER=$(git rev-parse "refs/remotes/origin/${OWNER_BRANCH}")
[[ "$LIVE_CANONICAL" == "$CANONICAL" ]] || { echo "FVQ98_LIVE_CANONICAL_LOCK=FAIL:$LIVE_CANONICAL"; exit 1; }
[[ "$LIVE_OWNER" == "$OWNER_CHECKPOINT" ]] || { echo "FVQ98_OWNER_RECONCILE_LOCK=FAIL:$LIVE_OWNER"; exit 1; }
echo "FVQ98_LIVE_CANONICAL_LOCK=PASS"
echo "FVQ98_OWNER_RECONCILE_LOCK=PASS"

python3 - "$CANONICAL" "$OWNER_CHECKPOINT" "$HISTORICAL_OWNER" <<'PY'
import json, subprocess, sys
canonical, owner, historical = sys.argv[1:]

def show(ref, path):
    return subprocess.check_output(["git", "show", f"{ref}:{path}"], text=True)

def obj(ref, path):
    return json.loads(show(ref, path))

def blob(ref, path):
    return subprocess.check_output(["git", "rev-parse", f"{ref}:{path}"], text=True).strip()

def require(cond, marker, detail=""):
    if not cond:
        raise SystemExit(f"{marker}=FAIL{':' + detail if detail else ''}")
    print(f"{marker}=PASS")

# Frozen denominator and the exact six historical closure obligations.
hist = obj(historical, "integration/f-gc/F-GC28_STATUS.json")
req = "Restricted direct-groundwater production composition spanning qualified tile aggregation, application/temporal binding, accepted whole-window response tangent, coupling restart/replay, MultiSWAP execution/diagnostics and external aquifer adapter conformance, followed by independent qualification and canonical admission."
require(hist["hard_blockers"][0]["id"] == "G05_END_TO_END_DIRECT_GROUNDWATER_COMPOSITION", "FVQ98_FROZEN_G05_ID")
require(hist["hard_blockers"][0]["frozen_requirement"] == req, "FVQ98_FROZEN_G05_REQUIREMENT")
obs = hist["technical_closure_obligations"]
require(len(obs) == 6 and [x["order"] for x in obs] == [1,2,3,4,5,6], "FVQ98_SIX_OBLIGATION_DENOMINATOR")
expected_requirements = [
 "accepted whole-window response tangent and one-corrector composition",
 "compose qualified multi-tile area-weighted exact-mass primitive into current production path",
 "compose application/temporal accuracy binding without universal numeric defaults",
 "accepted-boundary restart/split-run/replay with no prepared/rejected transfer leakage",
 "MultiSWAP direct-groundwater execution, deterministic aggregation, transaction isolation and full coupling-window diagnostics",
 "restricted external groundwater/MODFLOW adapter conformance plus end-to-end exact-mass and bounded-head production admission",
]
require([x["requirement"] for x in obs] == expected_requirements, "FVQ98_FROZEN_OBLIGATION_TEXT")

rec = obj(owner, "integration/f-gc/F-GC28_RECONCILE_CHECKPOINT.json")
require(rec["current_canonical"]["head"] == canonical, "FVQ98_RECONCILE_CANONICAL_PIN")
require(len(rec["technical_closure_obligations"]) == 6, "FVQ98_RECONCILE_SIX_OBLIGATIONS")
require(all(x["reconciled_status"] == "CLOSED_PENDING_F_VQ98_AUDIT" for x in rec["technical_closure_obligations"]), "FVQ98_OWNER_CLOSURE_MAPPING")
require(rec["production_mutations_in_reconcile"] == [], "FVQ98_RECONCILE_NO_PRODUCTION_MUTATION")

expected_blobs = {
 "src/runtime/mod_groundwater_predictor_corrector_window.f90": "fa2a5a45d558fbaaea242438915cdb7420b6503c",
 "src/runtime/mod_groundwater_tile_aggregation.f90": "d62ecba039d9bef178acde6900b81e9d5b0931eb",
 "src/runtime/mod_groundwater_accuracy_binding.f90": "b8ac03e810c73519b433f7851c6fd143ba26676a",
 "src/runtime/mod_groundwater_coupling_response.f90": "645141676536ae8289b9d52433798a965c7baa04",
 "src/runtime/mod_groundwater_coupled_restart.f90": "0596933ff3ae89c61ab7a0913189a4fa3179e50b",
 "src/runtime/mod_groundwater_multiswap_coupler.f90": "f2bf0e7d144fd3c0b9dc18f24f24eb4ffb7ffa0f",
 "src/adapter/mod_groundwater_external_gateway.f90": "f307f17e2fd20983432f91e91ac90aaae8311849",
 "src/runtime/mod_groundwater_coupling_contract.f90": "fc598d14eabafcb025bb55621f7b00d6d1816f10",
 "src/runtime/mod_groundwater_exchange_service_contract.f90": "e99ae052fccd9992b76c12a91422a987dce059e2",
 "src/runtime/mod_coupling_application_accuracy_contract.f90": "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc",
}
for path, expected in expected_blobs.items():
    require(blob(canonical, path) == expected, "FVQ98_PRODUCTION_BLOB_LOCK", path)
print("FVQ98_ALL_G05_PRODUCTION_BLOBS_LOCKED=PASS")

# Obligation 2: GC20 standalone current-canonical closure.
gc20 = obj(canonical, "integration/f-ci/F-CI77_STATUS.json")
require(gc20["status"] == "CLOSED_CANONICAL_ADMITTED" and gc20["canonical_admission"] is True, "FVQ98_GC20_CANONICAL_CLOSE")
require(gc20["owner_authority"]["production_blob"] == expected_blobs["src/runtime/mod_groundwater_tile_aggregation.f90"], "FVQ98_GC20_BLOB_AUTHORITY")
require(gc20["current_canonical_gate"]["FVQ87_independent_evidence_reused"] == "PASS" and gc20["current_canonical_gate"]["O0_O2_identity"] == "PASS", "FVQ98_GC20_INDEPENDENT_EVIDENCE")
require("no forced one-column/one-groundwater-cell mapping" in gc20["contract_preserved"], "FVQ98_GC20_MAPPING_SEMANTICS")

# Obligation 3: GC22 standalone current-canonical closure.
gc22 = obj(canonical, "integration/f-ci/F-CI78_STATUS.json")
require(gc22["state"] == "CLOSED_CANONICAL_ADMITTED", "FVQ98_GC22_CANONICAL_CLOSE")
require(gc22["owner_authority"]["production_blob"] == expected_blobs["src/runtime/mod_groundwater_accuracy_binding.f90"], "FVQ98_GC22_BLOB_AUTHORITY")
q22 = gc22["qualification"]
require(q22["application_interface_accuracy_separation"] == "PASS" and q22["temporal_interface_tolerance_separation"] == "PASS" and q22["no_universal_project_numeric_default"] == "PASS", "FVQ98_GC22_ACCURACY_OWNERSHIP")

# Obligation 1: GC23 whole-window tangent.
gc23 = obj(canonical, "integration/f-gc/F-GC23_STATUS.json")
require(gc23["status"] == "CANONICALLY_ADMITTED_CLOSED", "FVQ98_GC23_CANONICAL_CLOSE")
require(gc23["independent_qualification_work_unit"] == "F-VQ95" and gc23["independent_qualification_checkpoint"] == "da64ffb1f4cd5105e2809a02ddae02f50a9c853b", "FVQ98_GC23_INDEPENDENT_AUTHORITY")
require(gc23["production_source_blob"] == expected_blobs["src/runtime/mod_groundwater_coupling_response.f90"], "FVQ98_GC23_BLOB_AUTHORITY")

# Obligation 4: GC24 coupled restart/replay.
gc24p = obj(canonical, "integration/f-ci/F-CI65P_STATUS.json")
require(gc24p["production_canonical_admitted"] is True and gc24p["postimage_reconciled"] is True and gc24p["moving_current_preservation_reconciled"] is True, "FVQ98_GC24_POSTIMAGE_CLOSE")
require(gc24p["authorities"]["F_VQ86_independent_status"] == "0fea1f7a17ccff9f41b4d2dee71feab526313a01", "FVQ98_GC24_INDEPENDENT_AUTHORITY")
require(gc24p["production_postimage"]["src/runtime/mod_groundwater_coupled_restart.f90"] == expected_blobs["src/runtime/mod_groundwater_coupled_restart.f90"], "FVQ98_GC24_BLOB_AUTHORITY")

# Obligation 5: GC25 MultiSWAP transaction/diagnostic composition.
gc25p = obj(canonical, "integration/f-ci/F-CI73P_STATUS.json")
require(gc25p["scope"]["production_canonical_admitted"] is True and gc25p["scope"]["postimage_reconciled"] is True and gc25p["scope"]["moving_preservation_installed"] is True, "FVQ98_GC25_POSTIMAGE_CLOSE")
require(gc25p["authorities"]["F_VQ87_independent_head"] == "37c02ac3747bfaacdb8b3408b8228f3deb2b9824", "FVQ98_GC25_INDEPENDENT_AUTHORITY")
require(gc25p["production_authority_blobs"]["src/runtime/mod_groundwater_multiswap_coupler.f90"] == expected_blobs["src/runtime/mod_groundwater_multiswap_coupler.f90"], "FVQ98_GC25_BLOB_AUTHORITY")

# Obligation 6a: GC26 external gateway boundary.
gc26 = obj(canonical, "integration/f-gc/F-GC26_CANONICAL_ADMISSION.json")
require(gc26["scientific_verdict"] == "CANONICAL_ADMISSION_APPROVED", "FVQ98_GC26_CANONICAL_ADMISSION")
require(gc26["independent_qualification_authority"]["successful_head"] == "ae97f0d47c183a64e470be5badca220d95a65cb0" and gc26["independent_qualification_authority"]["conclusion"] == "success", "FVQ98_GC26_INDEPENDENT_AUTHORITY")
require(gc26["admitted_production_payload"]["src/adapter/mod_groundwater_external_gateway.f90"] == expected_blobs["src/adapter/mod_groundwater_external_gateway.f90"], "FVQ98_GC26_BLOB_AUTHORITY")

# Obligation 6b and cross-obligation end-to-end proof: GC27.
gc27 = obj(canonical, "integration/f-gc/F-GC27_CANONICAL_ADMISSION.json")
require(gc27["verdict"] == "CANONICALLY_ADMITTED_METADATA_ONLY" and gc27["production_mutations"] == [], "FVQ98_GC27_CANONICAL_ADMISSION")
iq = gc27["independent_qualification"]
require(iq["verdict"] == "INDEPENDENTLY_QUALIFIED" and iq["authority_head"] == "d45abdfb7fbd3f1ce5f68866586c5e9e67252f54" and iq["workflow_run_id"] == 35031745967, "FVQ98_GC27_INDEPENDENT_AUTHORITY")
for path, expected in expected_blobs.items():
    require(gc27["admitted_production_blobs"].get(path) == expected, "FVQ98_GC27_END_TO_END_BLOB_SET", path)
close27 = obj(canonical, "integration/f-gc/F-GC27_CLOSEOUT.json")
require(close27["verdict"] == "CLOSED_CANONICAL_ADMITTED" and close27["production_mutations_in_fgc27"] == [], "FVQ98_GC27_CLOSEOUT")

# G01-G04 remain foundations; F-GC28 itself must add no production semantics.
require(rec["preserved_foundation"]["G01"].startswith("preservation authority retained"), "FVQ98_G01_G04_PRESERVATION_DECLARED")
print("FVQ98_G02_G04_PRESERVATION_DECLARED=PASS")
print("FVQ98_SIX_G05_OBLIGATIONS_CLOSED=PASS")
print("FVQ98_NO_PRODUCTION_MUTATION=PASS")
print("F-VQ98 F-GC28 COMPLETION AUDIT PASS")
PY
