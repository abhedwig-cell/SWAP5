#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

POSTIMAGE = "7bbc7360280ddf27419293db4160bee0b070f7f9"
PREIMAGE = "c19a04721a05c6a00ba264e7477969807dcb258f"
ADMISSION_HEAD = "7c7f8519c94499f3628ef1a08181fdd5d8418d07"
OWNER = "66fd08ca96d8be69cf6f996202e21ce624db526b"
FVQ65 = "b1fd9e15a22d4dd68997ec38c074ce343eec0a70"
OLD_MOVING_AUTH = "8a1aeedbaeb5bd015e7e8d098d605968bbecd94e"
TX = "src/transaction/mod_transaction_reference.f90"
TX_BLOB = "d5a71a526efaebd82054580c3186f8e3545db331"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci-canonical.yml",
    ".github/workflows/fci57p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI57P_PRE_REGISTRATION.json",
    "integration/f-ci/F-CI57P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI57P_EVIDENCE.json",
    "integration/f-ci/F-CI57P_STATUS.json",
    "tests/fci/run_fci57p_current_canonical_postimage_reconciliation.py",
}


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI57P_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == POSTIMAGE, f"canonical race: expected {POSTIMAGE}, got {canonical}")
    print("FCI57P_CANONICAL_SOURCE_POSTIMAGE_PIN=PASS")

    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI57 merge parents: {parents}")
    print("FCI57P_TRUE_TWO_PARENT_FCI57_MERGE=PASS")

    prod_ref_delta = git("diff", "--name-only", f"{POSTIMAGE}..HEAD", "--", "src", "reference")
    require(prod_ref_delta == "", f"production/reference delta after F-CI57 promotion: {prod_ref_delta}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed on F-CI57P")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed on F-CI57P")
    print("FCI57P_PRODUCTION_REFERENCE_POSTIMAGE_IMMUTABLE=PASS")

    for ref in (POSTIMAGE, ADMISSION_HEAD, OWNER, FVQ65):
        require(git("rev-parse", f"{ref}:{TX}") == TX_BLOB, f"transaction blob mismatch at {ref}")
    require(git("rev-parse", f"{OLD_MOVING_AUTH}:{TX}") != TX_BLOB, "old moving authority unexpectedly already has admitted transaction blob")
    print("FCI57P_EXACT_FKT18_TRANSACTION_BLOB_LINEAGE=PASS")

    fvq_status = json.loads(git("show", f"{FVQ65}:integration/f-vq/F-VQ65_STATUS.json"))
    require(fvq_status.get("decision") == "INDEPENDENTLY_QUALIFIED_FKT18_FAIL_CLOSED_MASS_COMPLETENESS_READY_FOR_CANONICAL_ADMISSION", "F-VQ65 decision drift")
    require(fvq_status.get("independent_qualification") is True, "F-VQ65 independent qualification not true")
    require(fvq_status.get("source_identity", {}).get("transaction_source_identical_to_fkt18_authority") is True, "F-VQ65 source identity not locked")
    print("FCI57P_FVQ65_INDEPENDENT_AUTHORITY_PINNED=PASS")

    fci57 = json.loads(Path("integration/f-ci/F-CI57_STATUS.json").read_text())
    require(fci57.get("decision") == "QUALIFIED_F_CI57_READY_FOR_CANONICAL_PROMOTION", "F-CI57 prepromotion decision drift")
    require(fci57.get("ready_for_canonical_promotion") is True, "F-CI57 readiness drift")
    require(fci57.get("canonical_admission") is False, "F-CI57 prepromotion status unexpectedly claims admission")
    print("FCI57P_PREPROMOTION_AUTHORITY_PINNED=PASS")

    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed <= ALLOWED_BRANCH_DELTA, f"unexpected F-CI57P branch delta: {sorted(changed - ALLOWED_BRANCH_DELTA)}")
    require(".github/workflows/fci-canonical.yml" in changed, "moving preservation workflow not reconciled")
    print("FCI57P_GOVERNANCE_ONLY_BRANCH_DELTA=PASS")

    base_text = git("show", f"{POSTIMAGE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    cur_prefix, cur_suffix = current_text.split(MARKER, 1)
    require(cur_prefix == base_prefix, "historical/frozen workflow prefix changed")
    require(f"AUTH={OLD_MOVING_AUTH}" in base_suffix, "source postimage lacks expected old moving authority")

    expected_suffix = base_suffix
    auth_anchor = f"          AUTH={OLD_MOVING_AUTH}\n          git merge-base --is-ancestor \"$AUTH\" HEAD\n"
    auth_replacement = (
        f"          AUTH={OLD_MOVING_AUTH}\n"
        f"          TX={TX}\n"
        f"          TX_BLOB={TX_BLOB}\n"
        "          git merge-base --is-ancestor \"$AUTH\" HEAD\n"
        "          test \"$(git rev-parse \"HEAD:$TX\")\" = \"$TX_BLOB\" || {\n"
        "            echo \"FCI_CANONICAL_PRESERVATION_FAIL admitted F-KT18 transaction postimage drift: $TX\" >&2\n"
        "            exit 41\n"
        "          }\n"
        "          echo 'FCI57P_MOVING_TRANSACTION_REFERENCE_POSTIMAGE=PASS'\n"
    )
    require(auth_anchor in expected_suffix, "moving authority anchor missing")
    expected_suffix = expected_suffix.replace(auth_anchor, auth_replacement, 1)

    tx_line = f"            {TX}\n"
    require(expected_suffix.count(tx_line) == 1, "transaction path occurrence not exactly one in dependency surface")
    expected_suffix = expected_suffix.replace(tx_line, "", 1)

    marker_anchor = "          echo 'FCI52_MOVING_PM08D7_FIXED_WEIR_TRANSACTIONAL_RUNTIME_PRESERVATION=PASS'\n"
    marker_add = marker_anchor + "          echo 'FCI57_MOVING_FAIL_CLOSED_MASS_COMPLETENESS_PRESERVATION=PASS'\n"
    require(marker_anchor in expected_suffix, "F-CI52 marker anchor missing")
    expected_suffix = expected_suffix.replace(marker_anchor, marker_add, 1)
    require(cur_suffix == expected_suffix, "fci-canonical moving-preservation delta exceeds exact F-CI57P reconciliation")
    print("FCI57P_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI57P_OLD_MOVING_SURFACE_PRESERVED_EXCEPT_EXPLICIT_TRANSACTION_POSTIMAGE=PASS")

    prereg = json.loads(Path("integration/f-ci/F-CI57P_PRE_REGISTRATION.json").read_text())
    require(prereg.get("source_postimage") == POSTIMAGE, "pre-registration postimage drift")
    require(prereg.get("old_moving_authority") == OLD_MOVING_AUTH, "pre-registration old authority drift")
    require(prereg.get("transaction_blob") == TX_BLOB, "pre-registration transaction blob drift")

    audit = json.loads(Path("integration/f-ci/F-CI57P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("production_source_changed") is False, "architecture audit production change")
    require(audit.get("reference_changed") is False, "architecture audit reference change")
    require(audit.get("mass_conservation") == "PRESERVED_AND_GOVERNANCE_LOCK_STRENGTHENED", "mass conservation audit")
    inv = audit.get("invariants", [])
    require([x.get("id") for x in inv] == list(range(1, 31)), "architecture invariant IDs")
    require(all(x.get("status") == "PASS" for x in inv), "architecture invariant failure")
    print("FCI57P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI57P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
