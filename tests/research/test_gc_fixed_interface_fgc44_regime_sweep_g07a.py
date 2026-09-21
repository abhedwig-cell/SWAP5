from __future__ import annotations

import json
import math
import os
import sys
import tempfile
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))
sys.path.insert(0, str(ROOT / "tests" / "fgc"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_fgc44_real_swap_modflow_end_to_end import AREA_M2, DAY_TO_S, WINDOW_DAY, Binding, CountingKernel, Term

LOCAL_RESPONSE = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_FGC44_LOCAL_RESPONSE_RESULT.json"

TARGET_R = (0.5, 1.2, 2.0, 4.0)
Q_PROBES_M_PER_S = (-2.0e-10, -1.0e-10, 1.0e-10, 2.0e-10)
K_M_PER_DAY = 1.0e-10
SS_PER_M = 0.0
START_ERROR_M = 1.0e-7
RATIO_REL_TOL = 2.0e-3
RHO_ABS_TOL = 2.0e-3
ROOT_FLUX_TOL = 1.0e-15


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def build_regime_model(workdir: Path, href: float, sy: float) -> None:
    sim = flopy.mf6.MFSimulation(sim_name="FGC44_G07", version="mf6", sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim, time_units="DAYS", nper=1, perioddata=[(WINDOW_DAY, 1, 1.0)])
    flopy.mf6.ModflowIms(
        sim, complexity="MODERATE", outer_dvclose=1e-12, inner_dvclose=1e-13,
        outer_maximum=100, inner_maximum=100
    )
    gwf = flopy.mf6.ModflowGwf(sim, modelname="GWF_1", save_flows=True, newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=3, delr=1.0, delc=1.0, top=0.0, botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf, strt=href)
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=1, k=K_M_PER_DAY, save_flows=True)
    flopy.mf6.ModflowGwfsto(
        gwf, iconvert=1, ss=SS_PER_M, sy=sy, transient={0: True}
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0: [
            ((0, 0, 0), href + 0.002),
            ((0, 0, 2), href - 0.002),
        ]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf, maxbound=1, pname="API_SWAP", filename="api_swap.api")
    sim.write_simulation(silent=True)


def solve_term(
    libmf6: Path,
    swaplib: Path,
    href: float,
    sy: float,
    hcof_m2_per_day: float,
    rhs_m3_per_day: float,
) -> tuple[float, float, int]:
    with tempfile.TemporaryDirectory(prefix="fgc44-g07-mf-") as tmp:
        workdir = Path(tmp)
        build_regime_model(workdir, href, sy)
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(swaplib)
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
            xold = session.accepted_xold.copy()
            binding = [Binding(7001, 1, 2)]
            term = [Term(7001, hcof_m2_per_day, rhs_m3_per_day)]
            converged = None
            for _ in range(session.max_solve_iterations):
                status, iteration = session.publish_and_solve_iteration(binding, term)
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing MODFLOW iteration")
                require(np.array_equal(iteration.accepted_head_old_m, xold), "MODFLOW XOLD drifted")
                if iteration.modflow_converged:
                    converged = iteration
                    break
            require(converged is not None, "regime MODFLOW solve did not converge")
            head = float(converged.head_m[1])
            qgw = (hcof_m2_per_day * head - rhs_m3_per_day) / (AREA_M2 * DAY_TO_S)
            iterations = int(converged.iteration)
            require(session.finalize_prepared_solve() == PreparedSolveStatus.OK, session.last_error)
            raw.finalize_time_step()
            raw.finalize()
            initialized = False
            return head, qgw, iterations
        finally:
            if initialized:
                raw.finalize()


def trial_discard(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> tuple[int, float]:
    status, q = swap.try_trial(head)
    swap.discard()
    require(swap.state() == origin, "G07 SWAP trial mutated accepted authority")
    return status, q


def groundwater_response(
    libmf6: Path, swaplib: Path, href: float, sy: float
) -> tuple[float, float]:
    points: list[tuple[float, float]] = []
    for qprobe in Q_PROBES_M_PER_S:
        head, qgw, mf_iters = solve_term(
            libmf6, swaplib, href, sy, 0.0, -qprobe * AREA_M2 * DAY_TO_S
        )
        points.append((head, qgw))
        print(
            f"FGC44_G07_GW_PROBE SY={sy:.17g} Q={qprobe:.17g} "
            f"H={head:.17g} MF_ITERS={mf_iters}"
        )
    heads = np.asarray([x[0] for x in points], dtype=float)
    fluxes = np.asarray([x[1] for x in points], dtype=float)
    a, intercept = np.polyfit(heads, fluxes, 1)
    require(a > 0.0 and math.isfinite(a), "nonpositive G07 groundwater response")
    require(float(np.max(np.abs(a * heads + intercept - fluxes))) < 1.0e-14,
            "G07 groundwater response not affine enough")
    return float(a), float(intercept)


def reference_root(
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    href: float,
    sy: float,
    p_day: float,
) -> float:
    head = href + START_ERROR_M
    for _ in range(4):
        status, q = trial_discard(swap, origin, head)
        require(status == 0, f"G07 reference start rejected: {status}")
        rhs = p_day * head - q * AREA_M2 * DAY_TO_S
        candidate, qgw, _ = solve_term(libmf6, swaplib, href, sy, p_day, rhs)
        cstatus, qc = trial_discard(swap, origin, candidate)
        require(cstatus == 0, f"G07 physical-Newton proposal rejected: {cstatus}")
        if abs(qc - qgw) <= ROOT_FLUX_TOL:
            return candidate
        head = candidate
    raise AssertionError("G07 physical-Newton reference root did not close")


def classify(rho: float) -> str:
    if abs(rho) < 1.0 - 1.0e-8:
        return "CONTRACTIVE"
    if abs(abs(rho) - 1.0) <= 1.0e-8:
        return "NEUTRAL"
    return "DIVERGENT"


def one_step(
    policy: str,
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    href: float,
    sy: float,
    hstar: float,
    p: float,
    a: float,
    s0: float,
) -> dict[str, float | int | str | None]:
    head = hstar + START_ERROR_M
    status, q = trial_discard(swap, origin, head)
    require(status == 0, f"G07 {policy} start rejected")

    if policy == "P0":
        s = s0
        rho_expected = (p - s0) / (a - s0)
        alpha = 1.0
    elif policy == "P1":
        s = p
        rho_expected = 0.0
        alpha = 1.0
    elif policy == "P2":
        s = 0.0
        rho_expected = p / a
        alpha = 1.0
    elif policy == "P3":
        rho0 = (p - s0) / (a - s0)
        alpha = 1.0 / (1.0 - rho0)
        if not (0.0 < alpha <= 1.0):
            return {
                "policy": policy,
                "classification": "RELAXATION_NOT_ADMISSIBLE",
                "rho_expected": rho0,
                "alpha": alpha,
                "candidate_status": None,
                "rho_measured": None,
            }
        s = s0
        rho_expected = 1.0 - alpha + alpha * rho0
    else:
        raise ValueError(policy)

    s_day = s * AREA_M2 * DAY_TO_S
    rhs = s_day * head - q * AREA_M2 * DAY_TO_S
    raw, _, _ = solve_term(libmf6, swaplib, href, sy, s_day, rhs)
    candidate = head + alpha * (raw - head)
    cstatus, _ = trial_discard(swap, origin, candidate)
    rho_measured = (candidate - hstar) / (head - hstar)
    require(abs(rho_measured - rho_expected) <= RHO_ABS_TOL,
            f"G07 {policy} rho mismatch: {rho_measured} versus {rho_expected}")
    return {
        "policy": policy,
        "classification": classify(rho_expected),
        "rho_expected": rho_expected,
        "rho_measured": rho_measured,
        "alpha": alpha,
        "candidate_status": int(cstatus),
    }


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP library")

    frozen = json.loads(LOCAL_RESPONSE.read_text())
    p = float(frozen["central_real_swap_physical_slope_per_s"])
    s0 = float(frozen["positive_surrogate_slope_per_s"])
    u = s0 * WINDOW_DAY * DAY_TO_S
    require(u > 0.0, "invalid frozen u")

    swap = Fgc44RealSwap(swaplib)
    _, _, href = swap.initialize()
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), "G07 not at immutable accepted origin")
    p_day = p * AREA_M2 * DAY_TO_S

    rows = []
    for target_r in TARGET_R:
        sy = target_r * u
        a, intercept = groundwater_response(libmf6, swaplib, href, sy)
        r = a / abs(p)
        require(abs(r - target_r) / target_r <= RATIO_REL_TOL,
                f"G07 realized r missed target: {r} versus {target_r}")
        hstar = reference_root(libmf6, swaplib, swap, origin, href, sy, p_day)
        policies = [
            one_step(name, libmf6, swaplib, swap, origin, href, sy, hstar, p, a, s0)
            for name in ("P0", "P1", "P2", "P3")
        ]

        p0 = next(x for x in policies if x["policy"] == "P0")
        p1 = next(x for x in policies if x["policy"] == "P1")
        p2 = next(x for x in policies if x["policy"] == "P2")
        p3 = next(x for x in policies if x["policy"] == "P3")

        require(p1["classification"] == "CONTRACTIVE", "P1 must remain locally exact")
        if r < 1.0:
            require(p0["classification"] == "DIVERGENT", "P0 expected divergent for r<1")
            require(p2["classification"] == "DIVERGENT", "P2 expected divergent for r<1")
            require(p3["classification"] == "RELAXATION_NOT_ADMISSIBLE",
                    "P3 positive relaxation should be unavailable for r<1")
        elif r < 3.0:
            require(p0["classification"] == "DIVERGENT", "P0 expected divergent for 1<r<3")
            require(p2["classification"] == "CONTRACTIVE", "P2 expected contractive for r>1")
            require(p3["classification"] == "CONTRACTIVE", "P3 expected contractive for r>1")
        else:
            require(p0["classification"] == "CONTRACTIVE", "P0 expected contractive for r>3")
            require(p2["classification"] == "CONTRACTIVE", "P2 expected contractive for r>1")
            require(p3["classification"] == "CONTRACTIVE", "P3 expected contractive for r>1")

        row = {
            "target_r": target_r,
            "sy": sy,
            "a_per_s": a,
            "gw_intercept": intercept,
            "realized_r": r,
            "reference_root_m": hstar,
            "policies": policies,
        }
        rows.append(row)
        print("FGC44_G07_REGIME_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    require(swap.state() == origin, "G07 regime sweep mutated accepted SWAP authority")
    print("FGC44_G07_LIVE_PHASE_TRANSITIONS=PASS")
    print("GC_FIXED_INTERFACE_FGC44_G07A=PASS")


if __name__ == "__main__":
    main()
