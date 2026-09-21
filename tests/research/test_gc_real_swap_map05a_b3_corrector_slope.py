from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_real_swap_map05_b3_slope_policy import (
    FLUX_TOL,
    run_variant,
)

CURRENT_HEAD_M = -0.7149962561412444
CURRENT_QSWAP_M_PER_S = -1.2492277961483046e-11
CURRENT_LEDGER_M = -1.079332815872135e-9
HEAD_TOL_M = 5.0e-10
Q_TOL_M_PER_S = 2.0e-15
LEDGER_TOL_M = 2.0e-13


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    result = run_variant("E4_B3_CORRECTOR_JR")
    final = result["final"]

    iterations = int(result["iterations"])
    head = float(final["head_m"])
    qswap = float(final["q_swap_m_per_s"])
    residual = float(final["residual_m_per_s"])
    ledger = float(result["ledger_m"])

    head_delta = head - CURRENT_HEAD_M
    q_delta = qswap - CURRENT_QSWAP_M_PER_S
    ledger_delta = ledger - CURRENT_LEDGER_M

    print(f"GC_MAP05A_ITERATIONS={iterations}")
    print(f"GC_MAP05A_FINAL_HEAD_M={head:.17g}")
    print(f"GC_MAP05A_FINAL_QSWAP_M_PER_S={qswap:.17g}")
    print(f"GC_MAP05A_FINAL_RESIDUAL_M_PER_S={residual:.17g}")
    print(f"GC_MAP05A_LEDGER_M={ledger:.17g}")
    print(f"GC_MAP05A_HEAD_MINUS_CURRENT_M={head_delta:.17g}")
    print(f"GC_MAP05A_QSWAP_MINUS_CURRENT_M_PER_S={q_delta:.17g}")
    print(f"GC_MAP05A_LEDGER_MINUS_CURRENT_M={ledger_delta:.17g}")

    require(iterations <= 40, "MAP05A exceeded fixed coupling outer budget")
    require(abs(residual) <= FLUX_TOL, "MAP05A coupled residual gate")
    require(abs(head_delta) <= HEAD_TOL_M, "MAP05A accepted head differs from CURRENT_PLUS_U")
    require(abs(q_delta) <= Q_TOL_M_PER_S, "MAP05A accepted q_swap differs from CURRENT_PLUS_U")
    require(abs(ledger_delta) <= LEDGER_TOL_M, "MAP05A ledger differs from CURRENT_PLUS_U")

    state = result["state"]
    require(int(state[0]) == 1, "MAP05A SWAP revision not committed exactly once")
    require(int(state[2]) == 1, "MAP05A ledger count not committed exactly once")

    print("GC_MAP05A_CORRECTOR_SLOPE_CONVERGED=PASS")
    print("GC_MAP05A_ACCEPTED_HEAD_MATCHES_CURRENT=PASS")
    print("GC_MAP05A_ACCEPTED_QSWAP_MATCHES_CURRENT=PASS")
    print("GC_MAP05A_ACCEPTED_LEDGER_MATCHES_CURRENT=PASS")
    print("GC_MAP05A_EXACTLY_ONCE_PUBLICATION=PASS")
    print("GC_MAP05A_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
