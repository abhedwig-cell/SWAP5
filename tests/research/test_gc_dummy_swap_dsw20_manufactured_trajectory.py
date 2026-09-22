from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require

S = 0.20
K_MEMORY = 0.8
DRAIN_SLOPE = 0.03
DRAIN_REF = 8.0
ET_RATE = 0.001
H_INITIAL = 8.02
W_INITIAL = 0.005
HEAD_TOL = 1.0e-10
MASS_TOL = 1.0e-12
RCLOSE = 1.0e-13

WINDOWS = (
    (0.25, 0.004, 0.001),
    (0.50, 0.000, 0.002),
    (0.75, 0.006, 0.000),
    (0.40, 0.001, 0.0015),
    (0.60, 0.003, 0.000),
)


def expected_step(head0: float, memory0: float, dt: float, memory_input: float, lateral: float) -> tuple[float, float, float]:
    memory1 = (memory0 + memory_input) / (1.0 + K_MEMORY * dt)
    transfer = K_MEMORY * dt * memory1
    head1 = (
        S * head0
        + transfer
        + lateral
        - ET_RATE * dt
        + DRAIN_SLOPE * dt * DRAIN_REF
    ) / (S + DRAIN_SLOPE * dt)
    return head1, memory1, transfer


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    head = H_INITIAL
    memory = W_INITIAL
    initial_total = S * (head - DRAIN_REF) + memory
    cumulative_external = 0.0

    for step, (dt, memory_input, lateral) in enumerate(WINDOWS, start=1):
        expected_head, memory1, transfer = expected_step(head, memory, dt, memory_input, lateral)
        transfer_rate = transfer / dt
        lateral_rate = lateral / dt
        hcof = -DRAIN_SLOPE
        rhs = -DRAIN_SLOPE * DRAIN_REF - transfer_rate - lateral_rate + ET_RATE

        result = run_case(
            libmf6,
            f"dsw20_step_{step}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S,
            newton=False,
            initial_head_m=head,
            dt_day=dt,
            ims_rclose=RCLOSE,
        )
        require(bool(result["converged"]), f"step {step} did not converge: {result}")
        live_head = float(result["head_m"])

        storage_change = S * (live_head - head)
        memory_change = memory1 - memory
        et = ET_RATE * dt
        drain = DRAIN_SLOPE * (live_head - DRAIN_REF) * dt
        external_net = memory_input + lateral - et - drain
        window_mass_error = storage_change + memory_change - external_net

        cumulative_external += external_net
        current_total = S * (live_head - DRAIN_REF) + memory1
        cumulative_error = current_total - initial_total - cumulative_external

        print(f"GC_DSW20_STEP_{step}_DT_DAY={dt:.17g}")
        print(f"GC_DSW20_STEP_{step}_HEAD0_M={head:.17g}")
        print(f"GC_DSW20_STEP_{step}_EXPECTED_HEAD_M={expected_head:.17g}")
        print(f"GC_DSW20_STEP_{step}_LIVE_HEAD_M={live_head:.17g}")
        print(f"GC_DSW20_STEP_{step}_MEMORY0_M={memory:.17g}")
        print(f"GC_DSW20_STEP_{step}_MEMORY1_M={memory1:.17g}")
        print(f"GC_DSW20_STEP_{step}_TRANSFER_M={transfer:.17g}")
        print(f"GC_DSW20_STEP_{step}_DRAIN_M={drain:.17g}")
        print(f"GC_DSW20_STEP_{step}_WINDOW_MASS_ERROR_M={window_mass_error:.17g}")
        print(f"GC_DSW20_STEP_{step}_CUMULATIVE_MASS_ERROR_M={cumulative_error:.17g}")

        require(math.isclose(live_head, expected_head, rel_tol=0.0, abs_tol=HEAD_TOL), f"step {step} head oracle")
        require(abs(window_mass_error) <= MASS_TOL, f"step {step} window mass")
        require(abs(cumulative_error) <= MASS_TOL, f"step {step} cumulative mass")

        head = live_head
        memory = memory1

    require(math.isclose(head, 8.072723405817783, rel_tol=0.0, abs_tol=HEAD_TOL), "final manufactured head")
    require(math.isclose(memory, 0.00617230460980461, rel_tol=0.0, abs_tol=MASS_TOL), "final manufactured memory")

    print(f"GC_DSW20_FINAL_HEAD_M={head:.17g}")
    print(f"GC_DSW20_FINAL_MEMORY_M={memory:.17g}")
    print("GC_DSW20_ALL_WINDOWS_CONVERGED=PASS")
    print("GC_DSW20_WINDOW_MASS_LEDGER=PASS")
    print("GC_DSW20_CUMULATIVE_MASS_LEDGER=PASS")
    print("GC_DSW20_MANUFACTURED_TRAJECTORY=PASS")
    print("GC_DSW20_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
