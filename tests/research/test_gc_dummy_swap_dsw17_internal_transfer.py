from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


S_GW = 0.20
DT = 1.0
MASS_TOL = 1.0e-12
HEAD_TOL = 1.0e-10

CASES = (
    {
        "name": "MEMORY_TO_GROUNDWATER",
        "initial_head": 8.0,
        "initial_memory": 0.020,
        "transfer": 0.006,
        "expected_head": 8.03,
        "expected_memory": 0.014,
    },
    {
        "name": "GROUNDWATER_TO_MEMORY",
        "initial_head": 8.05,
        "initial_memory": 0.010,
        "transfer": -0.004,
        "expected_head": 8.03,
        "expected_memory": 0.014,
    },
)


def run_transfer_case(libmf6: Path, case: dict[str, object]) -> None:
    name = str(case["name"])
    h0 = float(case["initial_head"])
    w0 = float(case["initial_memory"])
    transfer = float(case["transfer"])
    expected_head = float(case["expected_head"])
    expected_memory = float(case["expected_memory"])

    # T > 0 is an internal transfer into groundwater. The opposite entry is
    # made explicitly in the independent memory ledger below.
    result = run_case(
        libmf6,
        f"dsw17_{name.lower()}",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-(transfer / DT),
        sy=S_GW,
        newton=False,
        initial_head_m=h0,
        dt_day=DT,
    )
    require(bool(result["converged"]), f"{name}: MODFLOW did not converge: {result}")

    head = float(result["head_m"])
    memory = w0 - transfer
    gw_storage_change = S_GW * (head - h0)
    memory_change = memory - w0
    combined_change = gw_storage_change + memory_change

    print(f"GC_DSW17_{name}_HEAD_M={head:.17g}")
    print(f"GC_DSW17_{name}_MEMORY_M={memory:.17g}")
    print(f"GC_DSW17_{name}_GW_STORAGE_CHANGE_M={gw_storage_change:.17g}")
    print(f"GC_DSW17_{name}_MEMORY_CHANGE_M={memory_change:.17g}")
    print(f"GC_DSW17_{name}_COMBINED_CHANGE_M={combined_change:.17g}")

    require(
        math.isclose(head, expected_head, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"{name}: head {head} != {expected_head}",
    )
    require(
        math.isclose(memory, expected_memory, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{name}: memory {memory} != {expected_memory}",
    )
    require(
        math.isclose(gw_storage_change, transfer, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{name}: groundwater storage change != transfer",
    )
    require(
        math.isclose(memory_change, -transfer, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{name}: memory change != opposite transfer",
    )
    require(
        math.isclose(combined_change, 0.0, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{name}: internal transfer changed complete water inventory",
    )


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    for case in CASES:
        run_transfer_case(libmf6, case)

    print("GC_DSW17_BIDIRECTIONAL_TRANSFER=PASS")
    print("GC_DSW17_EQUAL_OPPOSITE_LEDGER=PASS")
    print("GC_DSW17_COMPLETE_STORAGE_INVARIANCE=PASS")
    print("GC_DSW17_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
