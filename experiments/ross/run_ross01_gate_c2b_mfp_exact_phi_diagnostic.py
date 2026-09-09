from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from scipy.integrate import quad

import run_ross01_gate_c2b_face_table_mfp_residual_r2 as r2

MATERIALS = ("B05", "B10", "O13", "O14")

face = r2.face
base = r2.base


def exact_mfp_reference_mobility(
    ua: float,
    h_above: float,
    ub: float,
    h_below: float,
) -> float:
    del ua, ub
    dh = h_below - h_above
    close = abs(dh) <= 2.0e-10 * max(1.0, abs(h_above), abs(h_below))
    if close:
        value = face.c2b_k_of_h(0.5 * (h_above + h_below)) / r2.LENGTH_CM
    else:
        cuts = [h_above]
        low = min(h_above, h_below)
        high = max(h_above, h_below)
        for seam in face.SEAMS:
            if low < seam < high:
                cuts.append(seam)
        cuts.append(h_below)
        cuts = sorted(cuts) if h_below > h_above else sorted(cuts, reverse=True)
        integral = 0.0
        for left, right in zip(cuts[:-1], cuts[1:]):
            part, _ = quad(
                face.c2b_k_of_h,
                left,
                right,
                epsabs=1.0e-11,
                epsrel=1.0e-12,
                limit=120,
            )
            integral += part
        value = integral / (r2.LENGTH_CM * dh)
    if not (value > 0.0 and math.isfinite(value)):
        raise RuntimeError(("invalid_exact_mfp_reference", h_above, h_below, value))
    return value


# Diagnostic-only replacement. Table generation remains the frozen R2
# residual construction. Only the lookup reference mobility changes from the
# stored/interpolated cumulative Phi approximation to direct K(h) quadrature.
r2.mfp_reference_mobility_runtime = exact_mfp_reference_mobility


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2b_mfp_exact_phi_diagnostic.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")

    catalog = json.loads(face.CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    result = base.run_material(by_name[material], r2.N)

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_MFP_NORMALIZATION_EXACT_PHI_DIAGNOSTIC",
        "contract": "F-ROSS01_GATE_C2B_MFP_NORMALIZATION_EXACT_PHI_DIAGNOSTIC_CONTRACT.json",
        "material": material,
        "not_a_production_candidate": True,
        "runtime_quadrature": True,
        "two_dimensional_representation": "same N241 float32 MFP-residual table as failed R2",
        "only_change": "exact direct split integral of K(h) for M_phi during probe lookup",
        "result": result,
        "face_metrics_pass": bool(result["pass"]),
        "diagnostic_decision": (
            "EXACT_PHI_DIAGNOSTIC_FACE_METRICS_PASS_MFP_NORMALIZATION_PRINCIPLE_REMAINS_OPEN"
            if result["pass"] else
            "EXACT_PHI_DIAGNOSTIC_FACE_METRICS_FAIL_MFP_NORMALIZATION_NOT_SUFFICIENT"
        ),
        "scope_guard": "Diagnostic only; runtime quadrature is explicitly disqualifying for production."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "face_metrics_pass": result["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "worst_hybrid_probe": result.get("worst_hybrid_probe"),
        "worst_abs_probe": result.get("worst_abs_probe"),
        "failed_metrics": result.get("failed_metrics", [])
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
