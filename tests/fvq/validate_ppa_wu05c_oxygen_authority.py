#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

def load_json(path):
    return json.loads((ROOT / path).read_text())

def require(cond, msg):
    if not cond:
        raise AssertionError(msg)

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def authority():
    prereg = load_json("integration/audits/PPA_WU05C_PREREGISTRATION.json")
    contract = load_json("integration/audits/PPA_WU05C_OXYGEN_AUTHORITY_CONTRACT.json")
    status = load_json("integration/audits/PPA_WU05C_STATUS.json")
    b111 = (ROOT / "reference/swap-4.3.1/snapshots/B1.11.yml").read_text()
    b0_manifest = (ROOT / "reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
    diff = (ROOT / "docs/verification/legacy-differences.md").read_text()
    swap007 = (ROOT / "reference/swap-4.3.1/patches/SWAP-007/README.md").read_text()
    root = (ROOT / "src/process/mod_root_water_uptake_process.f90").read_text()
    fci31 = (ROOT / "integration/f-ci/F-CI31_STATUS.json").read_text()
    fgc30 = (ROOT / "integration/f-gc/F-GC30_CLOSEOUT.json").read_text()

    require(prereg["workunit"] == "PPA-WU05-C", "wrong prereg workunit")
    require(contract["workunit"] == "PPA-WU05-C", "wrong contract workunit")
    require(status["work_unit"] == "PPA-WU05-C", "wrong status workunit")

    ids = contract["authority"]["corrected_reference"]["files"]
    require(ids["SWAP/oxygenstress.f90"] == "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87", "oxygen hash drift")
    require(ids["SWAP/rootextraction.f90"] == "8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5", "rootextraction hash drift")
    require(ids["SWAP/RWU_micro.f90"] == "cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477", "RWU_micro hash drift")
    require(ids["SWAP/oxygenstress.f90"] in b111, "corrected oxygenstress identity missing from B1.11 snapshot")
    for path in ("SWAP/rootextraction.f90", "SWAP/RWU_micro.f90", "SWAP/temperature.f90"):
        require(ids[path] in b0_manifest, f"unchanged B0/B1.11 identity missing for {path}")

    require("SWAP-007" in diff, "SWAP-007 ledger authority missing")
    require("Newton" in swap007 and "overflow" in swap007.lower(), "SWAP-007 numerical guard authority missing")
    require(contract["authority"]["admitted_correction"]["physics_change"] is False, "SWAP-007 misclassified")
    require(contract["invariants"]["swap007"].startswith("Any migrated oxygen Newton path"), "SWAP-007 target rule missing")

    require("root_extraction_sink" in root and "actual_uptake_total" in root, "current root sink owner surface missing")
    require("oxygen" in fci31.lower(), "F-CI31 oxygen nonclaim missing")
    require("root uptake" in fgc30.lower() and "fail closed" in fgc30.lower(), "F-GC30 root derivative hold missing")

    rep = contract["families"]["SWOXYGEN_2_SWOXYGENTYPE_2_REPRODUCTION"]
    require(rep["persistent_physical_state"] == [], "reproduction state must remain empty")
    require(rep["production_status"] == "NOT_IMPLEMENTED", "review cannot admit production")
    require(contract["families"]["SWOXYGEN_1_FEDDES_WETNESS"]["persistent_physical_state"] == "UNKNOWN_DO_NOT_INFER", "Feddes state inferred")
    require(contract["families"]["SWOXYGEN_2_SWOXYGENTYPE_1_BARTHOLOMEUS"]["persistent_physical_state"] == "UNKNOWN_DO_NOT_INFER", "Bartholomeus state inferred")

    merge_base = git("merge-base", "HEAD", "origin/integration/f-ci-canonical")
    changed = git("diff", "--name-only", f"{merge_base}...HEAD").splitlines()
    bad = [p for p in changed if p.startswith("src/") or p.startswith("reference/")]
    require(not bad, f"review-only unit mutated production/reference: {bad}")
    allowed_prefixes = (
        ".github/workflows/ppa-wu05c-",
        "docs/audits/PPA_WU05C_",
        "integration/audits/PPA_WU05C_",
        "tests/fvq/validate_ppa_wu05c_",
    )
    extra = [p for p in changed if not p.startswith(allowed_prefixes)]
    require(not extra, f"unexpected WU05-C files: {extra}")

    print("PPA_WU05C_B111_IDENTITY_BINDING=PASS")
    print("PPA_WU05C_SWAP007_PRESERVATION=PASS")
    print("PPA_WU05C_SINGLE_ROOT_MASS_OWNER=PASS")
    print("PPA_WU05C_REPRODUCTION_STATE_BOUNDARY=PASS")
    print("PPA_WU05C_C2_C3_FAIL_CLOSED=PASS")
    print("PPA_WU05C_ZERO_PRODUCTION_REFERENCE_DELTA=PASS")

def independent():
    contract = load_json("integration/audits/PPA_WU05C_OXYGEN_AUTHORITY_CONTRACT.json")
    status = load_json("integration/audits/PPA_WU05C_STATUS.json")
    doc = (ROOT / "docs/audits/PPA_WU05C_OXYGEN_STRESS_AUTHORITY.md").read_text()

    require(contract["production_admission"] == "NONE_REVIEW_ONLY", "production claim in contract")
    require(status["production_admission"] == "NONE_REVIEW_ONLY", "production claim in status")
    require(contract["review_verdict"] == "OXYGEN_FAMILY_BOUNDARIES_FROZEN_C1_READY_FOR_SEPARATE_IMPLEMENTATION_AUTHORITY_C2_C3_SOURCE_HELD", "unexpected verdict")
    require("UNKNOWN_DO_NOT_INFER" in json.dumps(contract), "missing uncertainty hold")
    require("PPA-WU05-C1" in doc and "PPA-WU05-C2" in doc and "PPA-WU05-C3" in doc and "PPA-WU05-C4" in doc, "migration slices missing")
    require("does not claim" in doc.lower(), "nonclaim section missing")
    require("one accepted root-water mass receipt" in doc, "single mass-owner contract missing")
    require("SOURCE_MATERIALIZATION_REQUIRED" in doc, "source hold missing")
    require("100,000" in doc and "zero bitwise mismatches" in doc, "historical C1 qualification not represented")
    require("no physical persistent state" in doc.lower() or "physical persistent state     none" in doc, "C1 state statement missing")
    require("must not be generalized" in doc.lower(), "family non-generalization rule missing")

    slices = contract["migration_slices"]
    require([x["id"] for x in slices] == ["PPA-WU05-C1","PPA-WU05-C2","PPA-WU05-C3","PPA-WU05-C4"], "slice order drift")
    require(slices[0]["state"] == "DEFINED_NOT_IMPLEMENTED", "C1 state drift")
    require(slices[1]["state"].startswith("HELD_") and slices[2]["state"].startswith("HELD_"), "C2/C3 must remain held")

    print("PPA_WU05C_FAMILY_SEPARATION=PASS")
    print("PPA_WU05C_HISTORICAL_EVIDENCE_BOUNDED=PASS")
    print("PPA_WU05C_MASS_OWNER_CONTRACT=PASS")
    print("PPA_WU05C_MIGRATION_SLICING=PASS")
    print("PPA_WU05C_REVIEW_ONLY_NONCLAIMS=PASS")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--mode", choices=["authority","independent"], required=True)
    a = p.parse_args()
    authority() if a.mode == "authority" else independent()
    print(f"PPA-WU05-C {a.mode.upper()} VALIDATION PASS")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"PPA-WU05-C VALIDATION FAIL: {exc}", file=sys.stderr)
        raise
