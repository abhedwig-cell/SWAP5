from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research" / "support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap


MASS_TOL_CM = 1.0e-10
CM_TO_M = 0.01
PRODUCTION_U = 0.0005760442426568357
PARENT_RESULT = ROOT / "integration" / "research" / "GC_REAL_SWAP_MAP09_RESULT.json"


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    lib = Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(lib.is_file(), "missing MAP09 SWAP bridge")

    parent = json.loads(PARENT_RESULT.read_text(encoding="utf-8"))
    require(
        parent.get("map09a_activation")
        == "PASS_SMALLEST_PREREGISTERED_SYMMETRIC_PAIR",
        "MAP09A parent activation missing",
    )
    delta = float(parent["map09a_selected_delta_m"])
    require(
        math.isclose(delta, 1.0e-8, rel_tol=0.0, abs_tol=0.0),
        f"unexpected MAP09A selected delta {delta}",
    )
    require(
        delta in [float(x) for x in parent["symmetric_valid_deltas_m"]],
        "selected delta not in parent symmetric authority",
    )

    swap = Map09ActiveDrainageSwap(lib)
    _, _, href = swap.initialize()
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), f"dirty MAP09A origin: {origin}")

    minus = swap.corrector_mass_diagnostics(href - delta)
    plus = swap.corrector_mass_diagnostics(href + delta)

    for label, row in (("MINUS", minus), ("PLUS", plus)):
        print(
            "GC_MAP09A_"
            + label
            + "="
            + json.dumps(row, sort_keys=True, separators=(",", ":"))
        )
        require(int(row["result_status"]) == 0, f"{label} raw result status {row}")
        require(bool(row["completed"]), f"{label} incomplete")
        require(bool(row["candidate_ready"]), f"{label} candidate not ready")
        require(bool(row["mass_complete"]), f"{label} mass incomplete")
        require(
            abs(float(row["mass_residual_native"])) <= MASS_TOL_CM,
            f"{label} mass residual {row['mass_residual_native']}",
        )
        storage = float(row["storage_change_native"])
        total_in = float(row["total_in_native"])
        total_out = float(row["total_out_native"])
        require(
            math.isclose(
                storage,
                total_in - total_out,
                rel_tol=0.0,
                abs_tol=MASS_TOL_CM,
            ),
            f"{label} storage ledger mismatch",
        )

    j_s = (
        (float(plus["storage_change_native"]) - float(minus["storage_change_native"]))
        * CM_TO_M
        / (2.0 * delta)
    )
    j_r = (
        (
            float(plus["bottom_outward_exchange_native"])
            - float(minus["bottom_outward_exchange_native"])
        )
        * CM_TO_M
        / (2.0 * delta)
    )
    j_nonbottom = j_s + j_r

    require(all(math.isfinite(x) for x in (j_s, j_r, j_nonbottom)), "nonfinite MAP09A derivative")

    print(f"GC_MAP09A_SELECTED_DELTA_M={delta:.17g}")
    print(f"GC_MAP09A_REFERENCE_HEAD_M={href:.17g}")
    print(f"GC_MAP09A_J_S={j_s:.17g}")
    print(f"GC_MAP09A_J_R={j_r:.17g}")
    print(f"GC_MAP09A_J_NONBOTTOM={j_nonbottom:.17g}")
    print(f"GC_MAP09A_J_S_OVER_U={j_s / PRODUCTION_U:.17g}")
    print(f"GC_MAP09A_MINUS_J_R_OVER_U={-j_r / PRODUCTION_U:.17g}")
    print(f"GC_MAP09A_J_NONBOTTOM_OVER_U={j_nonbottom / PRODUCTION_U:.17g}")
    print(f"GC_MAP09A_CLOSURE_J_S_PLUS_J_R={j_s + j_r:.17g}")

    final_state = swap.state()
    require(final_state == origin, f"MAP09A mutated committed authority: {origin} -> {final_state}")

    print("GC_MAP09A_PARENT_ACTIVATION=PASS")
    print("GC_MAP09A_SYMMETRIC_PAIR_FIXED=PASS")
    print("GC_MAP09A_BOTH_TRIALS_MASS_COMPLETE=PASS")
    print("GC_MAP09A_STORAGE_LEDGER_IDENTITY=PASS")
    print("GC_MAP09A_DERIVATIVES_FINITE=PASS")
    print("GC_MAP09A_ZERO_AUTHORITY_MUTATION=PASS")
    print("GC_MAP09A_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
