#!/usr/bin/env python3
import json
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "42544af575db522d012db491db801615577048df"
CONTRACT = ROOT / "src/runtime/mod_groundwater_coupling_contract.f90"
POLICY = ROOT / "src/runtime/mod_groundwater_coupling_policy.f90"
TEST = ROOT / "tests/fgc/test_fgc17_typed_groundwater_interface.f90"
PREREG = ROOT / "integration/f-gc/F-GC17_PRE_REGISTRATION.json"
EXPECTED_SRC = {
    "src/runtime/mod_groundwater_coupling_contract.f90",
    "src/runtime/mod_groundwater_coupling_policy.f90",
}
EXPECTED_MARKERS = {
    "FGC17_GENERIC_WINDOW=PASS",
    "FGC17_DATUM_REQUIRED=PASS",
    "FGC17_H_EQUALS_Z_PLUS_PSI=PASS",
    "FGC17_HEAD_UNIT_ROUNDTRIP=PASS",
    "FGC17_QBOT_SIGN_UNIT_MAPPING=PASS",
    "FGC17_QSWAP_EQUALS_NEGATIVE_QGW=PASS",
    "FGC17_RESIDUAL_TYPE_SEPARATION=PASS",
    "FGC17_NO_DEFAULT_HEAD_TOLERANCE=PASS",
    "FGC17_PROVENANCE_BOUND_POLICY=PASS",
    "FGC17_FAIL_CLOSED_NONFINITE=PASS",
    "FGC17_TYPED_INTERFACE PASS",
}


def run(cmd, cwd=ROOT):
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True)


def require(condition, message):
    if not condition:
        raise SystemExit(f"FGC17_QUALIFICATION_FAIL: {message}")


def audit_scope():
    prereg = json.loads(PREREG.read_text())
    require(prereg["canonical_base"]["sha"] == BASE, "canonical base drift")
    require(prereg["canonical_base"]["F_CI49_admitted"] is True, "F-CI49 entry gate not frozen admitted")
    require(set(prereg["production_source_allowlist"]) == EXPECTED_SRC, "production source allowlist mismatch")
    require(prereg["exit_target"] ==
            "QUALIFIED_TYPED_DIRECT_GROUNDWATER_INTERFACE_DATUM_SIGN_UNITS_CONVERGENCE_POLICY_READY_FOR_CANONICAL_ADMISSION",
            "unexpected exit target")

    changed = run(["git", "diff", "--name-only", f"{BASE}...HEAD"]).stdout.splitlines()
    changed_src = {path for path in changed if path.startswith("src/")}
    require(changed_src == EXPECTED_SRC, f"unexpected production source delta: {sorted(changed_src)}")


def audit_contract_source():
    contract = CONTRACT.read_text().lower()
    policy = POLICY.read_text().lower()

    require("bottom_boundary_elevation_m" in contract, "explicit lower-face elevation datum missing")
    require("pressure_head_cm * cm_to_m" in contract, "H=z+psi mapping missing")
    require("-qbot_cm_per_day * cm_to_m / day_to_s" in contract, "native qbot sign/unit mapping missing")
    require("q_groundwater_m_per_s = -q_swap_m_per_s" in contract, "exact action/reaction assignment missing")
    require("mod_swap" not in contract and "variables" not in contract, "coupling contract leaked legacy globals")

    require("mod_coupling_application_accuracy_contract" not in policy,
            "F-GC17 policy must not bind application accuracy contract")
    require("canonical_numerical_config_t" not in policy,
            "F-GC17 policy must not reuse Richards numerical policy carrier")
    require("gw_head_tolerance_provenance_governed_external" in policy,
            "governed external tolerance provenance class missing")

    assignments = [line.strip() for line in policy.splitlines() if "head_tolerance_m =" in line]
    require(assignments == ["real(real64) :: head_tolerance_m = 0.0_real64"],
            f"head tolerance default must remain fail-closed zero only: {assignments}")


def compile_and_run(opt):
    compiler = shutil.which("gfortran")
    require(compiler is not None, "gfortran unavailable")
    with tempfile.TemporaryDirectory(prefix=f"fgc17-{opt[1:]}-") as tmp:
        build = pathlib.Path(tmp)
        exe = build / "fgc17_test"
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
        require(EXPECTED_MARKERS.issubset(lines), f"missing runtime markers at {opt}: {sorted(EXPECTED_MARKERS-lines)}")
        return completed.stdout


def main():
    audit_scope()
    audit_contract_source()
    out_o0 = compile_and_run("-O0")
    out_o2 = compile_and_run("-O2")
    require(out_o0 == out_o2, "O0/O2 runtime output differs")
    print("FGC17_SOURCE_SCOPE=PASS")
    print("FGC17_POLICY_SEPARATION=PASS")
    print("FGC17_O0_O2_IDENTITY=PASS")
    print("FGC17_QUALIFICATION PASS")


if __name__ == "__main__":
    main()
