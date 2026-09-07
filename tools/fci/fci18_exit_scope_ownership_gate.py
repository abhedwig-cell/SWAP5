#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCOPE = ROOT / "integration" / "f-ci" / "F-CI18_EXIT_SCOPE_OWNERSHIP.json"
CONTRACT = ROOT / "integration" / "f-ci" / "F-CI15_EXIT_GATES.json"
FCI17 = ROOT / "integration" / "f-ci" / "F-CI17_EXIT_GATES.json"
EXPECTED = [f"CI-G{i:02d}" for i in range(1, 11)]


def fail(msg: str) -> None:
    raise SystemExit(f"FCI18_GATE_FAIL: {msg}")


def main() -> None:
    data = json.loads(SCOPE.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    fci17 = json.loads(FCI17.read_text(encoding="utf-8"))
    if data.get("work_unit") != "F-CI18" or data.get("canonical_branch") != "integration/f-ci-canonical":
        fail("identity")
    if data.get("basis_head") != "e17b43e3dda7d178c4c81035308308448823e38d":
        fail("basis head")
    if data.get("production_source_changed") is not False or data.get("gate_contract_changed") is not False:
        fail("scope mutation")
    if data.get("downstream_holds_do_not_mean_admission") is not True:
        fail("hold semantics")
    non_del = set(data.get("non_delegable", []))
    if not any("mass" in x for x in non_del) or not any("transaction" in x for x in non_del) or not any("provenance" in x for x in non_del):
        fail("non-delegable invariants")

    decisions = data.get("decisions", {})
    if list(decisions.keys()) != EXPECTED:
        fail("exact gate set")
    for gate_id in EXPECTED:
        d = decisions[gate_id]
        c = contract["gates"][gate_id]
        if d.get("title") != c.get("title"):
            fail(f"{gate_id} title changed")
        if c.get("required") is not True:
            fail(f"{gate_id} contract required flag")
        if d.get("proposed_status") != "QUALIFIED":
            fail(f"{gate_id} proposed status")
        if not d.get("owner") or not d.get("basis"):
            fail(f"{gate_id} ownership/evidence")
        if d.get("fci17_status") != fci17["gates"][gate_id]["status"]:
            fail(f"{gate_id} stale F-CI17 status")

    if decisions["CI-G02"].get("scope_correction") is None:
        fail("G02 scope correction")
    if "F-VQ" not in decisions["CI-G05"].get("owner", ""):
        fail("G05 independent VQ ownership")
    g05_text = json.dumps(decisions["CI-G05"])
    if "fail-closed" not in g05_text.lower() or "mass-balance" not in g05_text.lower() or "solver-convergence" not in g05_text.lower():
        fail("G05 separation/fail-closed semantics")
    g09_text = json.dumps(decisions["CI-G09"])
    if "No fallback" not in g09_text or "hard mass" not in g09_text.lower():
        fail("G09 hard mass non-relaxation")
    if data.get("proposed_exit", {}).get("downstream_release_allowed") is not True:
        fail("candidate exit")

    changed = subprocess.check_output(["git", "diff", "--name-only", "HEAD^", "HEAD"], cwd=ROOT, text=True).splitlines()
    forbidden = [p for p in changed if p.startswith("src/") or p.startswith("reference/swap-4.3.1/")]
    if forbidden:
        fail(f"production/reference mutation: {forbidden}")

    print("FCI18_EXIT_SCOPE_OWNERSHIP PASS")


if __name__ == "__main__":
    main()
