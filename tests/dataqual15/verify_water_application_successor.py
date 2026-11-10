"""Qualify the bounded application successor and retain the native writer gate."""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "7535a9e650aa01ca3ee711353c2e2801e2872f00"
APPLICATION = "6f2ba26ead83ffb8222a332746b93a014f4e461b"
STATUS = "integration/dataqual15/STATUS.json"
ENTRY = "tests/dataqual15/verify_current_native_admission.py"
GATE = "tests/dataqual15/verify_water_application_successor.py"
WORKFLOW = ".github/workflows/fci-canonical.yml"
SELECTOR_TEST = "tests/runtime/test_fapp01_minimal_soil_water_application_host.f90"
RECEIPT = "integration/dataqual15/WATER_APPLICATION_INTEGRATION_20261109.json"
RECEIPT_SHA = "ba0dc5c0d9df38e5026136f136f534a0e104066b28dd45211458dfd1109c582e"
AREAS = ("src", "app", "reference", "tools")
ANCHOR = b'          if [[ -f tests/dataqual15/verify_current_native_admission.py ]]; then\n'
SUCCESSOR = b'          if [[ -f integration/dataqual15/WATER_APPLICATION_INTEGRATION_20261109.json ]]; then\n            python3 -m pip install -r tests/dataqual15_hupsel/requirements-science.txt\n            python3 -B tests/dataqual15/test_current_native_admission.py\n            python3 -B tests/dataqual15/verify_water_application_successor.py --output "$RUNNER_TEMP/native-admission"\n'


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def normalized(path):
    return (ROOT / path).read_bytes().replace(b"\r\n", b"\n")


def guard():
    subprocess.run(["git", "merge-base", "--is-ancestor", BASE, "HEAD"], cwd=ROOT, check=True)
    assert not git("diff", APPLICATION, "HEAD", "--", *AREAS), "application source differs from tested head"
    assert not git("diff", "HEAD", "--", *AREAS, STATUS, ENTRY, GATE, RECEIPT, WORKFLOW, SELECTOR_TEST), "dirty application authority"
    assert not git("ls-files", "--others", "--exclude-standard", "--", *AREAS), "untracked application source"
    assert not git("diff", BASE, "HEAD", "--", "tests/dataqual15_hupsel"), "historical native gate changed"
    for path in (ENTRY, STATUS, SELECTOR_TEST):
        assert normalized(path) == git("show", f"{BASE}:{path}"), f"frozen authority changed: {path}"
    old_workflow = git("show", f"{BASE}:{WORKFLOW}")
    assert old_workflow.count(ANCHOR) == 1
    assert normalized(WORKFLOW) == old_workflow.replace(ANCHOR, SUCCESSOR + ANCHOR.replace(b"if", b"elif", 1))
    raw = normalized(RECEIPT)
    assert sha256(raw).hexdigest() == RECEIPT_SHA, "local integration evidence differs"
    return json.loads(raw)


def selector_contract(output):
    results = []
    for opt in ("O0", "O2"):
        folder = output / opt
        folder.mkdir(parents=True)
        executable = folder / ("fapp01.exe" if os.name == "nt" else "fapp01")
        subprocess.run(["gfortran", "-" + opt, "-std=f2008", "-fcheck=all",
                        str(ROOT / "src/runtime/mod_fmr_soil_water_application_host.f90"),
                        str(ROOT / SELECTOR_TEST),
                        "-o", str(executable)], cwd=folder, check=True)
        results.append(subprocess.check_output([executable], cwd=folder))
    assert results[0] == results[1] and b"FAPP01_UNKNOWN_MODEL_FAIL_CLOSED=PASS" in results[0]
    return sha256(results[0].replace(b"\r\n", b"\n")).hexdigest()


def main(output):
    receipt = guard()
    output.mkdir(parents=True)
    selector_sha = selector_contract(output / "selector")
    with tempfile.TemporaryDirectory(prefix="swap5-native-predecessor-") as temporary:
        source = Path(temporary) / "source"
        git("-c", "core.autocrlf=false", "worktree", "add", "--detach", str(source), BASE)
        try:
            preserved = output / "predecessor"
            subprocess.run([sys.executable, "-B", str(source / ENTRY), "--output", str(preserved)],
                           cwd=source, check=True)
        finally:
            git("worktree", "remove", str(source))
    predecessor = json.loads((preserved / "RESULT.json").read_text())
    assert predecessor["head"] == BASE
    assert predecessor["status"] == "EXACT_CURRENT_PHASE_DEPLOYED_WRITERS_AND_COMPLETE_PRIOR_ADMISSION_PASS"
    guard()
    result = {"status": "WATER_APPLICATION_SUCCESSOR_AND_NATIVE_PREDECESSOR_PASS",
              "head": git("rev-parse", "HEAD").decode().strip(), "application": receipt["integration_commit"],
              "predecessor": predecessor["head"], "predecessor_status": predecessor["status"],
              "selector_o0_o2_sha256": selector_sha, "local_integration_receipt_sha256": RECEIPT_SHA,
              "whole_scientific_admission": False}
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(result["status"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    main(parser.parse_args().output.resolve())
