#!/usr/bin/env python3
"""Check P4 history wiring and all-four gate using mocks, never model output.

Only the two imported policy modules are replaced. main() runs unchanged;
its mock results are software fixtures, not numerical Reference evidence.
"""
from __future__ import annotations

import argparse
import ast
import contextlib
import copy
import io
import itertools
import json
import pathlib
import sys
import tempfile
import types
from unittest.mock import patch


def check(analyzer: pathlib.Path, prereg: pathlib.Path) -> dict:
    pre = json.loads(prereg.read_text())
    tree = ast.parse(analyzer.read_text(), filename=str(analyzer))
    replaced = set()
    body = []
    for node in tree.body:
        if (isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id in {"p1", "p2"}
                and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Name)
                and node.value.func.id == "load_module"):
            replaced.add(node.targets[0].id)
        else:
            body.append(node)
    if replaced != {"p1", "p2"}:
        raise AssertionError("Analyzer import structure changed; review mock boundary")
    tree.body = body
    module_code = compile(tree, str(analyzer), "exec")
    expected_surface = tuple(pre["blind_validation_workload"]["SURF_P"]["ids"])
    expected_gw = tuple(pre["blind_validation_workload"]["GW_LB"]["ids"])
    phases = {h: tuple(pre["blind_validation_workload"]["SURF_P"]["histories"][h]["phases"])
              for h in expected_surface}
    gate_cases = 0
    negative_cases = 0
    with tempfile.TemporaryDirectory() as temp:
        root = pathlib.Path(temp)
        pre_path = root / "prereg.json"
        result_path = root / "mock-result.json"
        for mask in itertools.product((False, True), repeat=4):
            p1 = types.SimpleNamespace()
            p2 = types.SimpleNamespace()
            calls = []

            def surface(material, unused_root):
                # Exercise the same key lookup used by compare_surface.
                observed = {h: tuple(p2.PHASES[h]) for h in p2.HISTORIES}
                assert tuple(p2.HISTORIES) == expected_surface
                assert observed == phases
                index = 0 if material == "B01" else 1
                calls.append(("SURF_P", material))
                return {"qualified": mask[index], "mock_fixture": True}

            def groundwater(purpose, material, unused_root):
                assert purpose == "gw"
                assert tuple(p1.GW_H) == expected_gw
                index = 2 if material == "B01" else 3
                calls.append(("GW_LB", material))
                return {"qualified": mask[index], "mock_fixture": True}

            p2.qualify_surface = surface
            p1.qualify_purpose = groundwater
            namespace = {"__file__": str(analyzer.resolve()), "__name__": "wiring_test",
                         "p1": p1, "p2": p2}
            exec(module_code, namespace)
            pre_path.write_text(json.dumps(pre))
            argv = [str(analyzer), "--prereg", str(pre_path), "--root", str(root),
                    "--output", str(result_path)]
            with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
                rc = namespace["main"]()
            result = json.loads(result_path.read_text())
            assert len(calls) == 4 and len(set(calls)) == 4
            assert result["candidate_response_authorized"] is all(mask)
            assert rc == (0 if all(mask) else 3)
            expected_status = ("P4_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED" if all(mask)
                               else "P4_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES")
            assert result["status"] == expected_status
            assert "S17-S20" in result["reference_policy"]["SURF_P"]
            assert "G17-G20" in result["reference_policy"]["GW_LB"]
            gate_cases += 1
        for purpose in ("SURF_P", "GW_LB"):
            bad = copy.deepcopy(pre)
            bad["blind_validation_workload"][purpose]["ids"][0] = "STALE"
            pre_path.write_text(json.dumps(bad))
            calls.clear()
            with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
                try:
                    namespace["main"]()
                except AssertionError:
                    pass
                else:
                    raise AssertionError("History drift was not rejected")
            assert calls == []
            negative_cases += 1
    return {"status": "PASS", "gate_combinations": gate_cases,
            "history_drift_rejections": negative_cases,
            "policy_modules_mocked": True, "model_response_generated": False}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--analyzer", type=pathlib.Path,
                    default=pathlib.Path(__file__).with_name("analyze_rom_purpose_p4_reference.py"))
    ap.add_argument("--prereg", type=pathlib.Path,
                    default=pathlib.Path("integration/f-rom/ROM_PURPOSE_P4_PREREGISTRATION.json"))
    a = ap.parse_args()
    print(json.dumps(check(a.analyzer, a.prereg), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
