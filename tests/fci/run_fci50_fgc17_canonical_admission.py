#!/usr/bin/env python3
import json
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868"
PREREG = ROOT / "integration/f-ci/F-CI50_PRE_REGISTRATION.json"
CONTRACT = ROOT / "src/runtime/mod_groundwater_coupling_contract.f90"
POLICY = ROOT / "src/runtime/mod_groundwater_coupling_policy.f90"
TEST = ROOT / "tests/fci/test_fci50_fgc17_admission.f90"
EXPECTED_BLOBS = {
    "src/runtime/mod_groundwater_coupling_contract.f90": "fc598d14eabafcb025bb55621f7b00d6d1816f10",
    "src/runtime/mod_groundwater_coupling_policy.f90": "5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976",
}
EXPECTED_MARKERS = {
    "FCI50_GENERIC_WINDOW=PASS",
    "FCI50_DATUM_HEAD_MAPPING=PASS",
    "FCI50_QBOT_INTERFACE_SIGN_UNITS=PASS",
    "FCI50_EXACT_FLUX_PAIRING=PASS",
    "FCI50_POLICY_FAIL_CLOSED=PASS",
    "FCI50_FGC17_ADMISSION_REPLAY PASS",
}


def run(cmd, cwd=ROOT):
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True)


def require(condition, message):
    if not condition:
        raise SystemExit(f"FCI50_ADMISSION_FAIL: {message}")


def audit_metadata_and_source():
    prereg = json.loads(PREREG.read_text())
    require(prereg["canonical_base"]["sha"] == BASE, "canonical base mismatch")
    require(prereg["donor_authority"]["closeout_head"] ==
            "f0e9465c78237fd974369d0ffcfaba9adc6d7b54", "donor closeout mismatch")
    require(prereg["exit_target"] ==
            "QUALIFIED_FGC17_TYPED_GROUNDWATER_INTERFACE_ADMITTED_TO_CURRENT_CANONICAL",
            "unexpected exit target")

    recorded = {item["path"]: item["donor_blob"] for item in prereg["source_allowlist"]}
    require(recorded == EXPECTED_BLOBS, "preregistered donor blob map mismatch")

    for path, expected_blob in EXPECTED_BLOBS.items():
        actual_blob = run(["git", "hash-object", path]).stdout.strip()
        require(actual_blob == expected_blob,
                f"donor blob mismatch for {path}: {actual_blob} != {expected_blob}")

    changed = run(["git", "diff", "--name-only", f"{BASE}...HEAD"]).stdout.splitlines()
    changed_src = {p for p in changed if p.startswith("src/")}
    require(changed_src == set(EXPECTED_BLOBS), f"unexpected src delta: {sorted(changed_src)}")

    contract = CONTRACT.read_text().lower()
    policy = POLICY.read_text().lower()
    require("bottom_boundary_elevation_m" in contract, "explicit datum field missing")
    require("pressure_head_cm * cm_to_m" in contract, "H=z+psi conversion missing")
    require("-qbot_cm_per_day * cm_to_m / day_to_s" in contract, "qbot sign/unit conversion missing")
    require("q_groundwater_m_per_s = -q_swap_m_per_s" in contract, "exact opposite flux assignment missing")
    require("mod_coupling_application_accuracy_contract" not in policy,
            "interface policy illegally depends on application-accuracy contract")
    require("canonical_numerical_config_t" not in policy,
            "interface policy illegally depends on Richards numerical config")
    require("gw_head_tolerance_provenance_governed_external" in policy,
            "governed provenance class missing")


def compile_and_run(opt):
    compiler = shutil.which("gfortran")
    require(compiler is not None, "gfortran unavailable")
    with tempfile.TemporaryDirectory(prefix=f"fci50-{opt[1:]}-") as tmp:
        build = pathlib.Path(tmp)
        exe = build / "fci50_replay"
        cmd = [
            compiler,
            "-std=f2008",
            "-Wall",
            "-Wextra",
            "-fcheck=all",
            "-ffpe-trap=invalid,zero,overflow",
            opt,
            "-J", str(build),
            "-I", str(build),
            str(CONTRACT),
            str(POLICY),
            str(TEST),
            "-o", str(exe),
        ]
        run(cmd)
        completed = run([str(exe)], cwd=build)
        lines = {line.strip() for line in completed.stdout.splitlines() if line.strip()}
        require(EXPECTED_MARKERS.issubset(lines),
                f"missing replay markers at {opt}: {sorted(EXPECTED_MARKERS-lines)}")
        return completed.stdout


def main():
    audit_metadata_and_source()
    out_o0 = compile_and_run("-O0")
    out_o2 = compile_and_run("-O2")
    require(out_o0 == out_o2, "O0/O2 replay output differs")
    print("FCI50_DONOR_SOURCE_IDENTITY=PASS")
    print("FCI50_SRC_ALLOWLIST=PASS")
    print("FCI50_POLICY_SEPARATION=PASS")
    print("FCI50_O0_O2_IDENTITY=PASS")
    print("FCI50_CANONICAL_ADMISSION_GATE PASS")


if __name__ == "__main__":
    main()
