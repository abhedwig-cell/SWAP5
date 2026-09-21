from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import tempfile
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))
sys.path.insert(0, str(ROOT / "tests" / "publication"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import PreparedSolveStatus
from test_pub_gc_e3_case import (
    AREA_M2,
    DAY_TO_S,
    FLUX_TOL,
    MAX_COUPLING_OUTER,
    Binding,
    Term,
    make_session,
)

WINDOW_DAY = 1.0e-3
PREDICTOR_QBOT_CM_PER_DAY = 1.0e-4
K_M_PER_DAY = 0.1
CHD_OFFSET_M = 0.0
EXPECTED_CURRENT_HCOF = 0.2665743709457589
E4_B3_CORRECTOR_HCOF = -0.28821767195098304
EXPECTED_CURRENT_OUTERS = 3

HEAD_SPREAD_TOL_M = 5.0e-10
Q_SPREAD_TOL_M_PER_S = 2.0e-15
LEDGER_INTERNAL_TOL_M = 1.0e-12
LEDGER_SPREAD_TOL_M = 2.0e-13

POLICIES = {
    "CURRENT_PLUS_U": None,
    "INTERCEPT_ONLY": 0.0,
    "E4_B3_CORRECTOR_JR": E4_B3_CORRECTOR_HCOF,
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
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing MODFLOW6 library")
    require(swaplib.is_file(), "missing F-GC44 bridge")
    require(policy in POLICIES, f"unknown policy {policy}")

    swap = Fgc44RealSwap(swaplib)
    production_hcof, production_rhs, href = swap.initialize_configured(
        WINDOW_DAY, PREDICTOR_QBOT_CM_PER_DAY
    )
    require(
        all(math.isfinite(v) for v in (production_hcof, production_rhs, href)),
        f"{policy}: invalid configured predictor",
    )
    close(
        production_hcof,
        EXPECTED_CURRENT_HCOF,
        1.0e-12,
        f"{policy}: E4 B3/current HCOF drift",
    )

    area_day = AREA_M2 * DAY_TO_S
    qref = (production_hcof * href - production_rhs) / area_day
    hcof = production_hcof if POLICIES[policy] is None else float(POLICIES[policy])
    rhs = hcof * href - qref * area_day
    close(
        (hcof * href - rhs) / area_day,
        qref,
        1.0e-24,
        f"{policy}: common initial affine point",
    )

    origin_state = swap.state()
    require(origin_state == (0, 0.0, 0, 0.0), f"{policy}: dirty origin {origin_state}")

    publisher = Fgc34CtypesPublisher(swaplib)
    tmp = raw = session = None
    history: list[dict[str, object]] = []
    try:
        tmp, raw, session = make_session(
            libmf6,
            publisher,
            href,
            WINDOW_DAY,
            K_M_PER_DAY,
            CHD_OFFSET_M,
        )
        accepted_xold = session.accepted_xold.copy()
        current_rhs = rhs
        final: dict[str, float] | None = None

        for outer in range(1, min(MAX_COUPLING_OUTER, session.max_solve_iterations) + 1):
            status, iterate = session.publish_and_solve_iteration(
                [Binding(7001, 1, 2)],
                [Term(7001, hcof, current_rhs)],
            )
            require(
                status == PreparedSolveStatus.OK and iterate is not None,
                f"{policy}: MODFLOW iteration {outer}: {session.last_error}",
            )
            require(
                np.array_equal(iterate.accepted_head_old_m, accepted_xold),
                f"{policy}: accepted XOLD drifted",
            )
            head = float(iterate.head_m[1])
            qgw = (hcof * head - current_rhs) / area_day

            try:
                qswap = swap.trial(head)
            except RuntimeError as exc:
                require(
                    swap.state() == origin_state,
                    f"{policy}: failed corrector changed authoritative state",
                )
                raise AssertionError(
                    f"{policy}: corrector failed at outer {outer}, head {head:.17g}: {exc}"
                ) from exc

            require(
                swap.state() == origin_state,
                f"{policy}: trial mutated authoritative state",
            )
            residual = qswap - qgw
            require(
                all(math.isfinite(v) for v in (head, qgw, qswap, residual)),
                f"{policy}: nonfinite iterate",
            )
            history.append(
                {
                    "iteration": outer,
                    "head_m": head,
                    "q_groundwater_m_per_s": qgw,
                    "q_swap_m_per_s": qswap,
                    "residual_m_per_s": residual,
                    "modflow_converged": bool(iterate.modflow_converged),
                }
            )
            print(
                f"GC_MAP05_{policy}_ITER={outer} H_M={head:.17g} "
                f"QGW={qgw:.17g} QSWAP={qswap:.17g} RES={residual:.17g} "
                f"MF={1 if iterate.modflow_converged else 0}"
            )

            if bool(iterate.modflow_converged) and abs(residual) <= FLUX_TOL:
                final = {
                    "head_m": head,
                    "q_groundwater_m_per_s": qgw,
                    "q_swap_m_per_s": qswap,
                    "residual_m_per_s": residual,
                }
                break

            swap.discard()
            require(
                swap.state() == origin_state,
                f"{policy}: discard changed authoritative state",
            )
            current_rhs = hcof * head - qswap * area_day

        require(final is not None, f"{policy}: did not converge within fixed outer budget")

        require(
            session.finalize_prepared_solve() == PreparedSolveStatus.OK,
            f"{policy}: finalize prepared solve: {session.last_error}",
        )
        require(swap.swap_preflight(), f"{policy}: SWAP preflight")
        swap.prepare_ledger()
        require(swap.ledger_preflight(), f"{policy}: ledger preflight")
        require(session.timestep_ready_for_finalize(), f"{policy}: MODFLOW timestep not ready")
        require(
            session.finalize_time_step_once() == PreparedSolveStatus.OK,
            f"{policy}: finalize timestep: {session.last_error}",
        )
        swap.commit_swap()
        swap.commit_ledger()
        state = swap.state()

        require(state[0] == 1, f"{policy}: SWAP revision not committed once")
        require(abs(state[1] - WINDOW_DAY) <= 1.0e-14, f"{policy}: committed time")
        require(state[2] == 1, f"{policy}: ledger count not one")

        duration_s = WINDOW_DAY * DAY_TO_S
        qswap = float(final["q_swap_m_per_s"])
        expected_ledger = qswap * duration_s
        close(
            float(state[3]),
            expected_ledger,
            LEDGER_INTERNAL_TOL_M,
            f"{policy}: ledger integral",
        )
        require(
            abs(float(final["residual_m_per_s"])) <= FLUX_TOL,
            f"{policy}: final residual gate",
        )

        print(f"GC_MAP05_{policy}_FINAL_HEAD_M={float(final['head_m']):.17g}")
        print(f"GC_MAP05_{policy}_FINAL_QSWAP_M_PER_S={qswap:.17g}")
        print(f"GC_MAP05_{policy}_FINAL_QGW_M_PER_S={float(final['q_groundwater_m_per_s']):.17g}")
        print(f"GC_MAP05_{policy}_FINAL_RESIDUAL_M_PER_S={float(final['residual_m_per_s']):.17g}")
        print(f"GC_MAP05_{policy}_LEDGER_M={float(state[3]):.17g}")
        print(f"GC_MAP05_{policy}_OUTER_ITERATIONS={len(history)}")

        return {
            "policy": policy,
            "hcof_m2_per_day": hcof,
            "href_m": href,
            "qref_m_per_s": qref,
            "initial_rhs_m3_per_day": rhs,
            "iterations": len(history),
            "history": history,
            "final": final,
            "ledger_m": float(state[3]),
            "state": list(state),
        }
    finally:
        if raw is not None:
            try:
                raw.finalize()
            except Exception:
                pass
        if tmp is not None:
            tmp.cleanup()


def child_main(policy: str, result_path: Path) -> None:
    result = run_variant(policy)
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"GC_MAP05_{policy}_CHILD_GATE=PASS")


def parent_main() -> None:
    results: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="gc-map05-parent-") as tmp:
        tmpdir = Path(tmp)
        for policy in POLICIES:
            result_path = tmpdir / f"{policy}.json"
            child = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).resolve()),
                    "--variant",
                    policy,
                    "--result",
                    str(result_path),
                ],
                check=False,
                text=True,
                capture_output=True,
                env=os.environ.copy(),
            )
            if child.stdout:
                print(child.stdout, end="")
            if child.stderr:
                print(child.stderr, end="", file=sys.stderr)
            require(child.returncode == 0, f"{policy} child failed with {child.returncode}")
            results.append(json.loads(result_path.read_text(encoding="utf-8")))

    by_policy = {str(r["policy"]): r for r in results}
    require(set(by_policy) == set(POLICIES), "missing MAP05 policy result")

    current = by_policy["CURRENT_PLUS_U"]
    require(
        int(current["iterations"]) == EXPECTED_CURRENT_OUTERS,
        f"CURRENT_PLUS_U no longer reproduces qualified E3-R three-outer path: {current['iterations']}",
    )

    hrefs = [float(r["href_m"]) for r in results]
    qrefs = [float(r["qref_m_per_s"]) for r in results]
    require(max(hrefs) - min(hrefs) <= 1.0e-15, f"H_ref mismatch: {hrefs}")
    require(max(qrefs) - min(qrefs) <= 1.0e-24, f"q_ref mismatch: {qrefs}")

    heads = [float(r["final"]["head_m"]) for r in results]
    qswaps = [float(r["final"]["q_swap_m_per_s"]) for r in results]
    ledgers = [float(r["ledger_m"]) for r in results]
    residuals = [abs(float(r["final"]["residual_m_per_s"])) for r in results]

    head_spread = max(heads) - min(heads)
    q_spread = max(qswaps) - min(qswaps)
    ledger_spread = max(ledgers) - min(ledgers)

    print(f"GC_MAP05_FINAL_HEAD_SPREAD_M={head_spread:.17g}")
    print(f"GC_MAP05_FINAL_QSWAP_SPREAD_M_PER_S={q_spread:.17g}")
    print(f"GC_MAP05_FINAL_LEDGER_SPREAD_M={ledger_spread:.17g}")

    require(head_spread <= HEAD_SPREAD_TOL_M, f"accepted head depends on policy: {heads}")
    require(q_spread <= Q_SPREAD_TOL_M_PER_S, f"accepted q_swap depends on policy: {qswaps}")
    require(ledger_spread <= LEDGER_SPREAD_TOL_M, f"accepted ledger depends on policy: {ledgers}")
    require(max(residuals) <= FLUX_TOL, f"residual gate failed: {residuals}")

    for result in results:
        policy = str(result["policy"])
        print(f"GC_MAP05_{policy}_ITERATIONS={int(result['iterations'])}")
        print(f"GC_MAP05_{policy}_FINAL_HEAD_M={float(result['final']['head_m']):.17g}")
        print(f"GC_MAP05_{policy}_FINAL_QSWAP_M_PER_S={float(result['final']['q_swap_m_per_s']):.17g}")
        print(f"GC_MAP05_{policy}_LEDGER_M={float(result['ledger_m']):.17g}")

    print("GC_MAP05_CURRENT_POLICY_E3R_PRESERVATION=PASS")
    print("GC_MAP05_ALL_POLICIES_CONVERGED=PASS")
    print("GC_MAP05_ACCEPTED_HEAD_INVARIANCE=PASS")
    print("GC_MAP05_ACCEPTED_CORRECTOR_FLUX_INVARIANCE=PASS")
    print("GC_MAP05_ACCEPTED_LEDGER_INVARIANCE=PASS")
    print("GC_MAP05_LIVE_GATE=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=tuple(POLICIES))
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()

    if args.variant is None:
        require(args.result is None, "--result requires --variant")
        parent_main()
    else:
        require(args.result is not None, "--variant requires --result")
        child_main(args.variant, args.result)


if __name__ == "__main__":
    main()
