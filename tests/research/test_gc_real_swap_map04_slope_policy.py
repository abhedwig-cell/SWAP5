from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
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
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
)
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

CURRENT_HCOF = 0.3402936037279093
CURRENT_HREF = -0.7149999706136307
CURRENT_QREF = -1.1179226975717078e-13
LOCAL_CORRECTOR_HCOF = -0.34029136831718865
ADMITTED_FINAL_HEAD = -0.7149999677331765

HEAD_TOL_M = 1.0e-10
FLUX_SPREAD_TOL_M_PER_S = 1.0e-15
LEDGER_INTERNAL_TOL_M = 1.0e-12
LEDGER_SPREAD_TOL_M = 1.0e-14

POLICY_HCOF = {
    "CURRENT_PLUS_U": CURRENT_HCOF,
    "INTERCEPT_ONLY": 0.0,
    "LOCAL_CORRECTOR_FD": LOCAL_CORRECTOR_HCOF,
}


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def close(a: float, b: float, atol: float, message: str) -> None:
    require(
        math.isclose(a, b, rel_tol=0.0, abs_tol=atol),
        f"{message}: {a:.17g} != {b:.17g}",
    )


def run_variant(policy: str) -> dict[str, object]:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge = Path(os.environ["FGC45_MULTISWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing MODFLOW6 library")
    require(bridge.is_file(), "missing F-GC45 bridge")
    require(policy in POLICY_HCOF, f"unknown policy {policy}")

    swap = Fgc45RealMultiSwap(bridge)
    production_hcof, production_rhs, href = swap.initialize()
    qref = (
        production_hcof * href - production_rhs
    ) / (AREA_M2 * DAY_TO_S)

    close(production_hcof, CURRENT_HCOF, 1.0e-14, "production HCOF drift")
    close(href, CURRENT_HREF, 1.0e-14, "production Href drift")
    close(qref, CURRENT_QREF, 1.0e-18, "production qref drift")

    hcof = POLICY_HCOF[policy]
    rhs = hcof * href - qref * AREA_M2 * DAY_TO_S
    duration_s = WINDOW_DAY * DAY_TO_S
    history: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix=f"gc-map04-{policy.lower()}-") as tmp:
        workdir = Path(tmp)
        build_model(workdir, href)
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(bridge)
        initialized = False
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")
            raw.prepare_time_step(0.0)

            session = Modflow6PreparedSolveSession(
                kernel,
                "GWF_1",
                "API_SWAP",
                publisher,
                solution_id=1,
            )
            require(
                session.acquire_after_prepare_time_step()
                == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            accepted_xold = session.accepted_xold.copy()

            final: dict[str, float] | None = None
            for outer in range(
                1,
                min(40, session.max_solve_iterations) + 1,
            ):
                status, iterate = session.publish_and_solve_iteration(
                    [Binding(7001, 1, 2)],
                    [Term(7001, hcof, rhs)],
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    session.last_error,
                )
                require(
                    np.array_equal(iterate.accepted_head_old_m, accepted_xold),
                    "MODFLOW accepted XOLD drifted within one window",
                )

                head = float(iterate.head_m[1])
                q_groundwater = (
                    hcof * head - rhs
                ) / (AREA_M2 * DAY_TO_S)
                q_weighted, q1, q2 = swap.trial(head)
                q_direct = F1 * q1 + F2 * q2
                close(
                    q_weighted,
                    q_direct,
                    32.0
                    * np.finfo(float).eps
                    * max(1.0, abs(q_direct)),
                    f"{policy} area-weighted corrector closure",
                )
                residual = q_weighted - q_groundwater
                values = (
                    head,
                    q_groundwater,
                    q_weighted,
                    q1,
                    q2,
                    residual,
                )
                require(
                    all(math.isfinite(value) for value in values),
                    f"{policy} nonfinite coupling iterate",
                )

                record = {
                    "iteration": outer,
                    "head_m": head,
                    "q_groundwater_m_per_s": q_groundwater,
                    "q_swap_m_per_s": q_weighted,
                    "q1_m_per_s": q1,
                    "q2_m_per_s": q2,
                    "residual_m_per_s": residual,
                    "modflow_converged": bool(iterate.modflow_converged),
                }
                history.append(record)
                print(
                    f"GC_MAP04_{policy}_ITER={outer} "
                    f"H_M={head:.17g} "
                    f"QGW={q_groundwater:.17g} "
                    f"QSWAP={q_weighted:.17g} "
                    f"RES={residual:.17g} "
                    f"MF={1 if iterate.modflow_converged else 0}"
                )

                if (
                    bool(iterate.modflow_converged)
                    and abs(residual) <= FLUX_TOL
                ):
                    final = {
                        "head_m": head,
                        "q_groundwater_m_per_s": q_groundwater,
                        "q_swap_m_per_s": q_weighted,
                        "q1_m_per_s": q1,
                        "q2_m_per_s": q2,
                        "residual_m_per_s": residual,
                    }
                    break

                swap.discard()
                rhs = (
                    hcof * head
                    - q_weighted * AREA_M2 * DAY_TO_S
                )

            require(final is not None, f"{policy} did not converge")
            require(
                session.finalize_prepared_solve()
                == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(swap.swap_preflight(), f"{policy} SWAP preflight")
            swap.prepare_ledgers()
            require(swap.ledgers_preflight(), f"{policy} ledger preflight")
            require(
                session.timestep_ready_for_finalize(),
                f"{policy} MODFLOW timestep not ready",
            )
            require(
                session.finalize_time_step_once()
                == PreparedSolveStatus.OK,
                session.last_error,
            )
            swap.commit_swaps()
            swap.commit_ledgers()
            state = swap.state()

            q1 = float(final["q1_m_per_s"])
            q2 = float(final["q2_m_per_s"])
            q_weighted = float(final["q_swap_m_per_s"])
            ledger1 = float(state[6])
            ledger2 = float(state[7])
            expected_ledger1 = F1 * q1 * duration_s
            expected_ledger2 = F2 * q2 * duration_s
            expected_total = q_weighted * duration_s

            close(
                ledger1,
                expected_ledger1,
                LEDGER_INTERNAL_TOL_M,
                f"{policy} tile1 ledger",
            )
            close(
                ledger2,
                expected_ledger2,
                LEDGER_INTERNAL_TOL_M,
                f"{policy} tile2 ledger",
            )
            close(
                ledger1 + ledger2,
                expected_total,
                LEDGER_INTERNAL_TOL_M,
                f"{policy} total ledger",
            )
            require(
                state[:2] == (1, 1),
                f"{policy} did not commit exactly one SWAP candidate per tile",
            )
            require(
                state[4:6] == (1, 1),
                f"{policy} did not commit exactly one ledger entry per tile",
            )
            require(
                kernel.prepare_solve_calls == 1,
                f"{policy} prepare_solve count",
            )
            require(
                kernel.finalize_solve_calls == 1,
                f"{policy} finalize_solve count",
            )
            require(
                kernel.finalize_time_step_calls == 1,
                f"{policy} finalize_time_step count",
            )

            raw.finalize()
            initialized = False

            result: dict[str, object] = {
                "policy": policy,
                "hcof_m2_per_day": hcof,
                "initial_rhs_m3_per_day": (
                    POLICY_HCOF[policy] * href
                    - qref * AREA_M2 * DAY_TO_S
                ),
                "href_m": href,
                "qref_m_per_s": qref,
                "iterations": len(history),
                "history": history,
                "final": final,
                "ledger1_m": ledger1,
                "ledger2_m": ledger2,
                "ledger_total_m": ledger1 + ledger2,
                "solve_calls": kernel.solve_calls,
                "state": list(state),
            }
            return result
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def child_main(policy: str, result_path: Path) -> None:
    result = run_variant(policy)
    result_path.write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"GC_MAP04_{policy}_CHILD_GATE=PASS")


def parent_main() -> None:
    results: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="gc-map04-parent-") as tmp:
        tmpdir = Path(tmp)
        for policy in POLICY_HCOF:
            result_path = tmpdir / f"{policy}.json"
            command = [
                sys.executable,
                str(Path(__file__).resolve()),
                "--variant",
                policy,
                "--result",
                str(result_path),
            ]
            child = subprocess.run(
                command,
                check=False,
                text=True,
                capture_output=True,
                env=os.environ.copy(),
            )
            if child.stdout:
                print(child.stdout, end="")
            if child.stderr:
                print(child.stderr, end="", file=sys.stderr)
            require(
                child.returncode == 0,
                f"{policy} child failed with {child.returncode}",
            )
            results.append(
                json.loads(result_path.read_text(encoding="utf-8"))
            )

    by_policy = {
        str(result["policy"]): result for result in results
    }
    require(set(by_policy) == set(POLICY_HCOF), "missing policy result")

    current = by_policy["CURRENT_PLUS_U"]
    current_head = float(current["final"]["head_m"])
    close(
        current_head,
        ADMITTED_FINAL_HEAD,
        HEAD_TOL_M,
        "CURRENT_PLUS_U admitted F-GC45 final head",
    )

    heads = [
        float(result["final"]["head_m"]) for result in results
    ]
    fluxes = [
        float(result["final"]["q_swap_m_per_s"])
        for result in results
    ]
    ledgers = [
        float(result["ledger_total_m"]) for result in results
    ]
    residuals = [
        abs(float(result["final"]["residual_m_per_s"]))
        for result in results
    ]

    head_spread = max(heads) - min(heads)
    flux_spread = max(fluxes) - min(fluxes)
    ledger_spread = max(ledgers) - min(ledgers)

    print(f"GC_MAP04_FINAL_HEAD_SPREAD_M={head_spread:.17g}")
    print(
        "GC_MAP04_FINAL_CORRECTOR_FLUX_SPREAD_M_PER_S="
        f"{flux_spread:.17g}"
    )
    print(f"GC_MAP04_FINAL_LEDGER_SPREAD_M={ledger_spread:.17g}")

    require(
        head_spread <= HEAD_TOL_M,
        f"slope policy changed accepted head: {heads}",
    )
    require(
        flux_spread <= FLUX_SPREAD_TOL_M_PER_S,
        f"slope policy changed accepted corrector flux: {fluxes}",
    )
    require(
        max(residuals) <= FLUX_TOL,
        f"coupled residual gate failed: {residuals}",
    )
    require(
        ledger_spread <= LEDGER_SPREAD_TOL_M,
        f"slope policy changed accepted ledger: {ledgers}",
    )

    for result in results:
        policy = str(result["policy"])
        print(
            f"GC_MAP04_{policy}_ITERATIONS="
            f"{int(result['iterations'])}"
        )
        print(
            f"GC_MAP04_{policy}_FINAL_HEAD_M="
            f"{float(result['final']['head_m']):.17g}"
        )
        print(
            f"GC_MAP04_{policy}_FINAL_QSWAP_M_PER_S="
            f"{float(result['final']['q_swap_m_per_s']):.17g}"
        )
        print(
            f"GC_MAP04_{policy}_LEDGER_TOTAL_M="
            f"{float(result['ledger_total_m']):.17g}"
        )

    print("GC_MAP04_ALL_POLICIES_CONVERGED=PASS")
    print("GC_MAP04_ACCEPTED_HEAD_INVARIANCE=PASS")
    print("GC_MAP04_ACCEPTED_CORRECTOR_FLUX_INVARIANCE=PASS")
    print("GC_MAP04_ACCEPTED_LEDGER_INVARIANCE=PASS")
    print("GC_MAP04_EXACTLY_ONCE_PUBLICATION=PASS")
    print("GC_MAP04_LIVE_GATE=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=tuple(POLICY_HCOF))
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()

    if args.variant is None:
        require(args.result is None, "--result requires --variant")
        parent_main()
        return

    require(args.result is not None, "--variant requires --result")
    child_main(args.variant, args.result)


if __name__ == "__main__":
    main()
