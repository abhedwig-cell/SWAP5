#!/usr/bin/env python3
"""Mocked analyzer and synthetic closeout checks; no hydrological execution."""
from __future__ import annotations
import ast
import contextlib
import importlib.util
import io
import itertools
import json
import pathlib
import sys
import tempfile
import types
from unittest.mock import patch
from rom_purpose_p4_decision_policy import attribution, frontier

HERE = pathlib.Path(__file__).resolve().parent
RUNGS = {"SURF_P": ("S8", "S12", "S16"), "GW_LB": ("G8", "G12", "G16")}
STATES = ((False, False), (True, False), (True, True))
PHASE = "PREREGISTERED_BEFORE_ANY_P4_REFERENCE_LAYER_ROM_OR_MATCHED_RICHARDS_RESPONSE"


def module(path):
    spec = importlib.util.spec_from_file_location("p4_claim_fixture", str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def candidate_checks(root):
    path = HERE / "analyze_rom_purpose_p4_candidates.py"
    tree = ast.parse(path.read_text())
    old_count = len(tree.body)
    tree.body = [node for node in tree.body if not (
        isinstance(node, ast.Assign) and len(node.targets) == 1
        and isinstance(node.targets[0], ast.Name) and node.targets[0].id == "p3")]
    assert len(tree.body) == old_count - 1
    stub = types.SimpleNamespace(base=types.SimpleNamespace(
        p2ref=types.SimpleNamespace(), p1ref=types.SimpleNamespace()))
    ns = {"__name__": "p4_mock_candidate", "__file__": str(path), "p3": stub}
    exec(compile(tree, str(path), "exec"), ns)
    stub.reference_bundle = lambda _: (
        {p: {m: {} for m in ("B01", "B14")} for p in RUNGS},
        {p: {m: {} for m in ("B01", "B14")} for p in RUNGS})
    stub.candidate_metrics = lambda purpose, candidate, ref: candidate["fixture"]
    stub.classify_case = lambda metrics, status, ref: (
        "CANDIDATE_NOT_NUMERICALLY_QUALIFIED" if status != "QUALIFIED" else
        "REPRESENTATION_COMPARATOR_REACHED" if metrics else "BELOW_NUMERICAL_COMPARATOR", None)
    pre = root / "pre.json"
    rr = root / "rr.json"
    out = root / "candidate-mock.json"
    pre.write_text(json.dumps({"phase": PHASE}))
    rr.write_text(json.dumps({"status": "P4_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED",
                              "candidate_response_authorized": True}))
    count = 0
    for state in itertools.product(STATES, repeat=3):
        def candidate(unused_root, purpose, material, member):
            q, r = state[RUNGS[purpose].index(member)]
            return {"status": "QUALIFIED" if q else "NUMERICAL_BLOCKED",
                    "dimension": int(member[1:]), "boundaries_cm": [], "fixture": r,
                    "max_abs_water_ledger_cm": None, "failures": {}}
        ns["load_candidate"] = candidate
        argv = [str(path), "--prereg", str(pre), "--reference-result", str(rr),
                "--reference-root", str(root), "--candidate-root", str(root), "--output", str(out)]
        with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            ns["main"]()
        obj = json.loads(out.read_text())
        for purpose, names in RUNGS.items():
            expected = frontier([(name, q, r) for name, (q, r) in zip(names, state)])
            for material in ("B01", "B14"):
                assert obj["decisions"][purpose][material]["frontier_evidence"] == expected
        count += 1
    return count


def closeout_checks(root):
    path = HERE / "build_rom_purpose_p4_closeout.py"
    builder = module(path)
    pre = {"phase": PHASE, "central_question": "SOFTWARE FIXTURE ONLY",
           "frozen_representations": {p: {m: list(range(int(m[1:]) + 1)) for m in names}
                                      for p, names in RUNGS.items()}}
    # Arbitrary matching partition fixtures only, not P4 simulation inputs.
    prepath = root / "pre.json"
    lp = root / "layer.json"
    rp = root / "matched.json"
    mp = root / "map.json"
    cp = root / "close.json"
    prepath.write_text(json.dumps(pre))
    argv = [str(path), "--prereg", str(prepath), "--layer-result", str(lp),
            "--matched-result", str(rp), "--purpose-map-output", str(mp),
            "--closeout-output", str(cp), "--markdown-output", str(root / "close.md")]
    count = 0
    for ls, rs in itertools.product(itertools.product(STATES, repeat=3), repeat=2):
        layer = {"cases": {}, "decisions": {}}
        rich = {"cases": {}, "decisions": {}}
        for purpose, names in RUNGS.items():
            lf = frontier([(m, q, r) for m, (q, r) in zip(names, ls)])
            rf = frontier([(m, q, r) for m, (q, r) in zip(names, rs)])
            layer["cases"][purpose] = {}; rich["cases"][purpose] = {}
            layer["decisions"][purpose] = {}; rich["decisions"][purpose] = {}
            for material in ("B01", "B14"):
                layer["cases"][purpose][material] = {}; rich["cases"][purpose][material] = {}
                for member, (lq, lr), (rq, rr) in zip(names, ls, rs):
                    bounds = pre["frozen_representations"][purpose][member]
                    layer["cases"][purpose][material][member] = {
                        "status": "QUALIFIED" if lq else "NUMERICAL_BLOCKED", "boundaries_cm": bounds,
                        "representation_sufficiency": "REPRESENTATION_COMPARATOR_REACHED" if lr else
                        "BELOW_NUMERICAL_COMPARATOR" if lq else "CANDIDATE_NOT_NUMERICALLY_QUALIFIED"}
                    rich["cases"][purpose][material][member] = {
                        "numerical_qualification": {"qualified": rq}, "comparator_reached": rr,
                        "boundaries_cm": bounds}
                layer["decisions"][purpose][material] = {"minimum_tested_state_count": lf["minimum_tested_state_count"]}
                rich["decisions"][purpose][material] = {"minimum_tested_matched_richards_state_count": rf["minimum_tested_state_count"]}
        lp.write_text(json.dumps(layer)); rp.write_text(json.dumps(rich))
        with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            assert builder.main() == 0
        result = json.loads(mp.read_text())
        for purpose in RUNGS:
            for material in ("B01", "B14"):
                row = result["purposes"][purpose]["materials"][material]
                for got, (lq, lr), (rq, rr) in zip(row["rungs"], ls, rs):
                    assert got["attribution"] == attribution(lq, lr, rq, rr)
        count += 1
    # Reject a different partition rather than performing invalid attribution.
    rich["cases"]["SURF_P"]["B01"]["S8"]["boundaries_cm"] = [-1]
    rp.write_text(json.dumps(rich))
    with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
        try:
            builder.main()
        except ValueError as exc:
            assert "Same-partition contract drift" in str(exc)
        else:
            raise AssertionError("Mismatched partitions were admitted")
    return count


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as temp:
        root = pathlib.Path(temp)
        counts = {"candidate_mock_cases": candidate_checks(root),
                  "closeout_fixture_combinations": closeout_checks(root)}
    print(json.dumps({"status": "PASS", **counts, "partition_drift_rejections": 1,
                      "model_response_generated": False}, sort_keys=True))
