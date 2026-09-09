from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3a_encountered_transition_faces as e3a

CONTRACT = "F-ROSS01_GATE_E3A_R1_UNRESOLVED_NEAR_UNSAT_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13")
FACE_CLASS = "NEAR_UNSAT_NEAR_UNSAT"


def diagnose(material: str, row: dict) -> dict:
    r3 = e3a.r3
    r3.e2c.configure(row)
    core = r3.e2c.c1.core
    ksat = float(core.KSAT)
    unresolved = []
    resolved = 0
    nonfinite = 0
    for p in e3a.probes(material, FACE_CLASS):
        ha = float(p["h_above"])
        hb = float(p["h_below"])
        try:
            qref = float(core.steady_q(ha, hb))
        except Exception as exc:
            raise RuntimeError(("reference_failure", material, p["id"], ha, hb, repr(exc))) from exc
        try:
            qcand, _cost = r3.endpoint_limit_candidate(ha, hb)
            if not math.isfinite(float(qcand)):
                nonfinite += 1
            else:
                resolved += 1
            continue
        except RuntimeError as exc:
            exc_repr = repr(exc)
            exc_args = repr(exc.args)
        except (FloatingPointError, OverflowError, ValueError) as exc:
            nonfinite += 1
            unresolved.append({
                "probe_id": p["id"], "kind": p["kind"],
                "h_above": ha, "h_below": hb, "q_ref": qref,
                "K_above": float(core.k_of_h(ha)), "K_below": float(core.k_of_h(hb)), "KSATFIT": ksat,
                "exception_type": type(exc).__name__, "exception_repr": repr(exc), "exception_args_repr": repr(exc.args),
                "head_order": "ABOVE_GREATER" if ha > hb else "ABOVE_LESS" if ha < hb else "EQUAL",
                "delta_h_below_minus_above_cm": hb-ha,
                "hydrostatic_delta_minus_face_length_cm": (hb-ha)-float(r3.e2c.LENGTH),
                "qref_over_K_above": qref / max(float(core.k_of_h(ha)), 1.0e-300),
                "qref_gt_K_above": bool(qref > float(core.k_of_h(ha))),
                "failure_class": "NONFINITE_OR_VALUE"
            })
            continue
        kabove = float(core.k_of_h(ha))
        kbelow = float(core.k_of_h(hb))
        unresolved.append({
            "probe_id": p["id"], "kind": p["kind"],
            "h_above": ha, "h_below": hb, "q_ref": qref,
            "K_above": kabove, "K_below": kbelow, "KSATFIT": ksat,
            "exception_type": "RuntimeError", "exception_repr": exc_repr, "exception_args_repr": exc_args,
            "head_order": "ABOVE_GREATER" if ha > hb else "ABOVE_LESS" if ha < hb else "EQUAL",
            "delta_h_below_minus_above_cm": hb-ha,
            "hydrostatic_delta_minus_face_length_cm": (hb-ha)-float(r3.e2c.LENGTH),
            "qref_over_K_above": qref / max(kabove, 1.0e-300),
            "qref_gt_K_above": bool(qref > kabove),
            "failure_class": "RUNTIME_UNRESOLVED"
        })
    return {
        "material": material,
        "probe_count": len(e3a.probes(material, FACE_CLASS)),
        "resolved_count": resolved,
        "unresolved_count": len(unresolved),
        "nonfinite_count": nonfinite,
        "unresolved": unresolved,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3a_r1_unresolved_near_unsat_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    results = [diagnose(m, by[m]) for m in MATERIALS]
    total = sum(r["unresolved_count"] for r in results)
    signatures = sorted({u["exception_args_repr"] for r in results for u in r["unresolved"]})
    all_endpoint_applicable = all(u["qref_gt_K_above"] for r in results for u in r["unresolved"]) if total else False
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3A_R1_UNRESOLVED_NEAR_UNSAT_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "candidate_changed": False,
        "results": results,
        "total_unresolved_count": total,
        "distinct_exception_signatures": signatures,
        "all_unresolved_qref_gt_K_above": all_endpoint_applicable,
        "decision": "DIAGNOSTIC_COMPLETE_CLASS_SPECIFIC_CLOSURE_DESIGN_REQUIRED" if total else "DIAGNOSTIC_FOUND_NO_UNRESOLVED_POINTS_RECONCILIATION_REQUIRED",
        "hard_nonclaims": [
            "No face-class qualification.",
            "No E3 column requalification.",
            "No bracket, quadrature, root-policy or tolerance modification."
        ]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "decision": result["decision"],
        "total_unresolved_count": total,
        "counts": {r["material"]: r["unresolved_count"] for r in results},
        "all_unresolved_qref_gt_K_above": all_endpoint_applicable,
        "signature_count": len(signatures)
    }, sort_keys=True))


if __name__ == "__main__":
    main()
