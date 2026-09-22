from __future__ import annotations

import math
import os
import sys
import tempfile
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))
sys.path.insert(0, str(ROOT / "tests" / "fgc"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc45_real_multiswap_ctypes import Fgc45RealMultiSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from test_fgc45_real_multiswap_modflow_end_to_end import (
    AREA_M2,
    DAY_TO_S,
    F1,
    F2,
    FLUX_TOL,
    WINDOW_DAY,
    Binding,
    CountingKernel,
    Term,
    build_model,
)

HREF_EXPECTED = -0.71499997061363074
CENTER_HEAD_M = -0.71499996773317653
LIVE_SHIFT_SCALE_M = CENTER_HEAD_M - HREF_EXPECTED
MULTIPLIERS = (-0.5, -0.25, 0.0, 0.25, 0.5)
HEADS_M = tuple(CENTER_HEAD_M + m * LIVE_SHIFT_SCALE_M for m in MULTIPLIERS)
LEDGER_TOL_M = 1.0e-12


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def close(a: float, b: float, atol: float, message: str) -> None:
    require(math.isclose(a, b, rel_tol=0.0, abs_tol=atol), f"{message}: {a:.17g} != {b:.17g}")


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge = Path(os.environ["FGC45_MULTISWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing MODFLOW6 library")
    require(bridge.is_file(), "missing F-GC45 bridge")

    duration_s = WINDOW_DAY * DAY_TO_S
    swap = Fgc45RealMultiSwap(bridge)
    hcof, rhs, href = swap.initialize()
    require(all(math.isfinite(v) for v in (hcof, rhs, href)), "nonfinite predictor term")
    close(href, HREF_EXPECTED, 1.0e-15, "predictor reference drift")

    affine_slope_per_s = hcof / (AREA_M2 * DAY_TO_S)
    affine_u = affine_slope_per_s * duration_s

    print(f"GC_MAP02_HREF_M={href:.17g}")
    print(f"GC_MAP02_CENTER_HEAD_M={CENTER_HEAD_M:.17g}")
    print(f"GC_MAP02_LIVE_SHIFT_SCALE_M={LIVE_SHIFT_SCALE_M:.17g}")
    print(f"GC_MAP02_HCOF_M2_PER_DAY={hcof:.17g}")
    print(f"GC_MAP02_RHS_M3_PER_DAY={rhs:.17g}")
    print(f"GC_MAP02_AFFINE_SLOPE_PER_S={affine_slope_per_s:.17g}")
    print(f"GC_MAP02_AFFINE_U_EQUIVALENT={affine_u:.17g}")

    initial_state = swap.state()
    require(initial_state[:2] == (0, 0), "fixture not at accepted origin")
    require(initial_state[4:6] == (0, 0), "fixture ledgers not empty")

    samples: dict[float, tuple[float, float, float]] = {}
    for multiplier, head in zip(MULTIPLIERS, HEADS_M, strict=True):
        q_weighted, q1, q2 = swap.trial(head)
        q_direct = F1 * q1 + F2 * q2
        close(
            q_weighted,
            q_direct,
            32.0 * np.finfo(float).eps * max(1.0, abs(q_direct)),
            f"area-weighted closure multiplier {multiplier}",
        )
        require(all(math.isfinite(v) for v in (q_weighted, q1, q2)), f"nonfinite probe multiplier {multiplier}")
        samples[multiplier] = (q_weighted, q1, q2)
        print(
            f"GC_MAP02_SAMPLE_MULT={multiplier:.17g} HEAD_M={head:.17g} "
            f"QW={q_weighted:.17g} Q1={q1:.17g} Q2={q2:.17g}"
        )
        swap.discard()

    q_center, q1_center, q2_center = samples[0.0]
    q_repeat, q1_repeat, q2_repeat = swap.trial(CENTER_HEAD_M)
    close(q_repeat, q_center, 1.0e-18, "repeat weighted corrector")
    close(q1_repeat, q1_center, 1.0e-18, "repeat tile1 corrector")
    close(q2_repeat, q2_center, 1.0e-18, "repeat tile2 corrector")
    swap.discard()

    print(f"GC_MAP02_CENTER_QW_M_PER_S={q_center:.17g}")
    print(f"GC_MAP02_REPEAT_QW_M_PER_S={q_repeat:.17g}")

    for radius in (0.25, 0.5):
        plus = samples[radius]
        minus = samples[-radius]
        delta = radius * LIVE_SHIFT_SCALE_M
        slope_w = (plus[0] - minus[0]) / (2.0 * delta)
        slope_1 = (plus[1] - minus[1]) / (2.0 * delta)
        slope_2 = (plus[2] - minus[2]) / (2.0 * delta)
        u_fd = slope_w * duration_s
        ratio = slope_w / affine_slope_per_s if affine_slope_per_s != 0.0 else float("nan")
        difference = slope_w - affine_slope_per_s
        require(all(math.isfinite(v) for v in (slope_w, slope_1, slope_2, u_fd, ratio, difference)), f"nonfinite FD radius {radius}")
        print(
            f"GC_MAP02_FD_RADIUS_MULT={radius:.17g} DELTA_M={delta:.17g} "
            f"SLOPE_W_PER_S={slope_w:.17g} SLOPE_1_PER_S={slope_1:.17g} "
            f"SLOPE_2_PER_S={slope_2:.17g} U_FD={u_fd:.17g} "
            f"SLOPE_RATIO_TO_PRODUCTION={ratio:.17g} SLOPE_DIFFERENCE_PER_S={difference:.17g}"
        )

    affine_q_center = (hcof * CENTER_HEAD_M - rhs) / (AREA_M2 * DAY_TO_S)
    print(f"GC_MAP02_AFFINE_Q_AT_CENTER_M_PER_S={affine_q_center:.17g}")
    print(f"GC_MAP02_CORRECTOR_MINUS_AFFINE_CENTER_M_PER_S={q_center-affine_q_center:.17g}")

    post_probe_state = swap.state()
    require(post_probe_state[:2] == (0, 0), "probes mutated committed SWAP revisions")
    require(post_probe_state[4:6] == (0, 0), "probes mutated ledgers")

    with tempfile.TemporaryDirectory(prefix="gc-map02-fgc45-") as tmp:
        workdir = Path(tmp)
        build_model(workdir, href)
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(bridge)
        initialized = False
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session = Modflow6PreparedSolveSession(
                kernel, "GWF_1", "API_SWAP", publisher, solution_id=1
            )
            require(session.acquire_after_prepare_time_step() == PreparedSolveStatus.OK, session.last_error)
            require(session.open_prepared_solve() == PreparedSolveStatus.OK, session.last_error)
            accepted_xold = session.accepted_xold.copy()
            binding = [Binding(7001, 1, 2)]
            current_hcof = hcof
            current_rhs = rhs
            converged = False
            final: tuple[float, float, float, float, float, float] | None = None

            for outer in range(1, min(40, session.max_solve_iterations) + 1):
                status, iterate = session.publish_and_solve_iteration(
                    binding, [Term(7001, current_hcof, current_rhs)]
                )
                require(status == PreparedSolveStatus.OK and iterate is not None, session.last_error)
                require(np.array_equal(iterate.accepted_head_old_m, accepted_xold), "MODFLOW XOLD drifted")
                head = float(iterate.head_m[1])
                q_gw = (current_hcof * head - current_rhs) / (AREA_M2 * DAY_TO_S)
                q_weighted, q1, q2 = swap.trial(head)
                q_direct = F1 * q1 + F2 * q2
                close(
                    q_weighted,
                    q_direct,
                    32.0 * np.finfo(float).eps * max(1.0, abs(q_direct)),
                    f"live area weighting iteration {outer}",
                )
                residual = q_weighted - q_gw
                require(all(math.isfinite(v) for v in (head, q_gw, q_weighted, q1, q2, residual)), "nonfinite live coupling iterate")
                print(
                    f"GC_MAP02_LIVE_ITER={outer} H_M={head:.17g} QGW={q_gw:.17g} "
                    f"QW={q_weighted:.17g} Q1={q1:.17g} Q2={q2:.17g} "
                    f"RES={residual:.17g} MF={int(iterate.modflow_converged)}"
                )

                if iterate.modflow_converged and abs(residual) <= FLUX_TOL:
                    converged = True
                    final = (head, q_weighted, q_gw, q1, q2, residual)
                    break

                swap.discard()
                current_rhs = current_hcof * head - q_weighted * AREA_M2 * DAY_TO_S

            require(converged and final is not None, "real F-GC45 live coupling did not converge")
            require(session.finalize_prepared_solve() == PreparedSolveStatus.OK, session.last_error)
            require(swap.swap_preflight(), "SWAP preflight")
            swap.prepare_ledgers()
            require(swap.ledgers_preflight(), "ledger preflight")
            require(session.timestep_ready_for_finalize(), "MODFLOW timestep readiness")
            require(session.finalize_time_step_once() == PreparedSolveStatus.OK, session.last_error)
            swap.commit_swaps()
            swap.commit_ledgers()
            state = swap.state()

            head, q_weighted, q_gw, q1, q2, residual = final
            ledger1 = float(state[6])
            ledger2 = float(state[7])
            expected_ledger1 = F1 * q1 * duration_s
            expected_ledger2 = F2 * q2 * duration_s
            expected_total = q_weighted * duration_s

            close(ledger1, expected_ledger1, LEDGER_TOL_M, "tile1 ledger")
            close(ledger2, expected_ledger2, LEDGER_TOL_M, "tile2 ledger")
            close(ledger1 + ledger2, expected_total, LEDGER_TOL_M, "aggregate ledger")

            print(f"GC_MAP02_FINAL_HEAD_M={head:.17g}")
            print(f"GC_MAP02_FINAL_QW_M_PER_S={q_weighted:.17g}")
            print(f"GC_MAP02_FINAL_QGW_M_PER_S={q_gw:.17g}")
            print(f"GC_MAP02_FINAL_RESIDUAL_M_PER_S={residual:.17g}")
            print(f"GC_MAP02_LEDGER1_M={ledger1:.17g}")
            print(f"GC_MAP02_LEDGER2_M={ledger2:.17g}")
            print(f"GC_MAP02_LEDGER_TOTAL_M={ledger1+ledger2:.17g}")
            print(f"GC_MAP02_EXPECTED_LEDGER_TOTAL_M={expected_total:.17g}")

            raw.finalize()
            initialized = False

            print("GC_MAP02_ADMITTED_BAND_PROBES=PASS")
            print("GC_MAP02_AREA_WEIGHTED_CORRECTOR_CLOSURE=PASS")
            print("GC_MAP02_CENTER_REPEAT_DETERMINISM=PASS")
            print("GC_MAP02_FD_RESPONSE_CHARACTERIZED=PASS")
            print("GC_MAP02_LIVE_COUPLED_WINDOW=PASS")
            print("GC_MAP02_LEDGER_FLUX_INTEGRAL_CLOSURE=PASS")
            print("GC_MAP02_LIVE_GATE=PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
