from __future__ import annotations

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

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_fgc44_real_swap_modflow_end_to_end import (
    AREA_M2,
    DAY_TO_S,
    Binding,
    CountingKernel,
    Term,
    build_model,
)

QUALIFIED_RESPONSE = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_FGC44_LOCAL_RESPONSE_RESULT.json"
GW_Q_PROBES_M_PER_S = (-4.0e-8, -2.0e-8, -1.0e-8, 1.0e-8, 2.0e-8, 4.0e-8)
FINITE_START_DH_M = (-1.0e-6, -5.0e-7, 5.0e-7, 1.0e-6, 2.0e-6)
CANDIDATE_BUSY_STATUS = 4
TRIAL_FAILED_STATUS = 6
ARTIFACT_DH_M = -2.0e-6
ADMISSIBILITY_SCAN_DH_M = (
    -1.0e-4, -5.0e-5, -2.0e-5, -1.0e-5, -5.0e-6, -2.0e-6, -1.0e-6,
     1.0e-6,  2.0e-6,  5.0e-6,  1.0e-5,  2.0e-5,  5.0e-5,  1.0e-4,
)
MAX_OUTER = 8
HEAD_ROOT_TOL_M = 5.0e-11
RHO_ABS_TOL = 5.0e-4


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def solve_groundwater_term(
    libmf6: Path,
    swaplib: Path,
    href: float,
    hcof_m2_per_day: float,
    rhs_m3_per_day: float,
) -> tuple[float, float, int]:
    """Solve one fixed API affine term to MODFLOW convergence from fresh XOLD."""
    with tempfile.TemporaryDirectory(prefix="fgc44-g03-mf-") as tmp:
        workdir = Path(tmp)
        build_model(workdir, href)
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
            accepted_xold = session.accepted_xold.copy()
            binding = [Binding(7001, 1, 2)]
            term = [Term(7001, hcof_m2_per_day, rhs_m3_per_day)]
            converged = None
            for _ in range(session.max_solve_iterations):
                status, iteration = session.publish_and_solve_iteration(binding, term)
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing MODFLOW iteration")
                require(np.array_equal(iteration.accepted_head_old_m, accepted_xold), "MODFLOW XOLD drifted")
                if iteration.modflow_converged:
                    converged = iteration
                    break
            require(converged is not None, "MODFLOW groundwater oracle did not converge")
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


def trial_and_discard(
    swap: Fgc44RealSwap,
    origin_state: tuple[int, float, int, float],
    head: float,
) -> tuple[int, float]:
    status, q = swap.try_trial(head)
    swap.discard()
    require(swap.state() == origin_state, "diagnostic SWAP trial changed accepted origin")
    return status, q


def run_reference_root(
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    origin_state: tuple[int, float, int, float],
    href: float,
    p_day: float,
) -> float:
    head = href + 1.0e-6
    for outer in range(1, MAX_OUTER + 1):
        status, q = trial_and_discard(swap, origin_state, head)
        require(status == 0, f"reference-root corrector rejected: {status}")
        rhs = p_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, qgw, mf_iters = solve_groundwater_term(libmf6, swaplib, href, p_day, rhs)
        status_raw, qraw = trial_and_discard(swap, origin_state, raw_head)
        require(status_raw == 0, f"reference-root proposal rejected: {status_raw}")
        residual = qraw - qgw
        print(
            f"FGC44_G03_ROOT_ITER={outer} H={raw_head:.17g} QSWAP={qraw:.17g} "
            f"QGW={qgw:.17g} RES={residual:.17g} MF_ITERS={mf_iters}"
        )
        if abs(residual) <= 1.0e-15:
            return raw_head
        head = raw_head
    raise AssertionError("physical-tangent reference root did not close")


def policy_prediction(policy: str, p: float, a: float, s0: float, alpha: float) -> float:
    if policy == "P0":
        return (p - s0) / (a - s0)
    if policy in ("P1", "P4"):
        return 0.0
    if policy == "P2":
        return p / a
    if policy == "P3":
        rho0 = (p - s0) / (a - s0)
        return 1.0 - alpha + alpha * rho0
    raise ValueError(policy)


def run_policy(
    policy: str,
    start_dh: float,
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    origin_state: tuple[int, float, int, float],
    href: float,
    hstar: float,
    s0_day: float,
    p_day: float,
    a: float,
    gw_intercept: float,
    alpha: float,
) -> dict[str, float | int | str]:
    head = href + start_dh
    h0 = head
    first_candidate = math.nan
    contractions_total = 0

    for outer in range(1, MAX_OUTER + 1):
        status, q = trial_and_discard(swap, origin_state, head)
        if status != 0:
            return {"classification":"CORRECTOR_INADMISSIBLE","status":status,"outer":outer,"start_dh":start_dh}

        slope_day = p_day if policy in ("P1", "P4") else (0.0 if policy == "P2" else s0_day)
        rhs = slope_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, _, mf_iters = solve_groundwater_term(libmf6, swaplib, href, slope_day, rhs)
        candidate = head + alpha * (raw_head - head) if policy == "P3" else raw_head
        status_candidate, q_candidate = trial_and_discard(swap, origin_state, candidate)

        if policy == "P4":
            contractions = 0
            while status_candidate != 0 and contractions < 8:
                candidate = head + 0.5 * (candidate - head)
                contractions += 1
                status_candidate, q_candidate = trial_and_discard(swap, origin_state, candidate)
            contractions_total += contractions

        if status_candidate != 0:
            return {"classification":"CORRECTOR_INADMISSIBLE","status":status_candidate,"outer":outer,"start_dh":start_dh}

        if math.isnan(first_candidate):
            first_candidate = candidate

        qgw_est = a * candidate + gw_intercept
        residual_est = q_candidate - qgw_est
        error = candidate - hstar
        print(
            f"FGC44_G03_POLICY={policy} START_DH_M={start_dh:.17g} OUTER={outer} "
            f"H={candidate:.17g} HRAW={raw_head:.17g} ERR={error:.17g} "
            f"RES_EST={residual_est:.17g} MF_ITERS={mf_iters} CONTRACTIONS={contractions_total}"
        )

        if abs(error) <= HEAD_ROOT_TOL_M:
            rho_measured = (first_candidate - hstar) / (h0 - hstar)
            return {
                "classification":"CONVERGED","outer":outer,"start_dh":start_dh,
                "final_head":candidate,"rho_measured":rho_measured,
                "contractions":contractions_total,
            }
        head = candidate

    return {
        "classification":"COUPLING_DIVERGENCE","outer":MAX_OUTER,"start_dh":start_dh,
        "final_head":head,"contractions":contractions_total,
    }


def run_cold_g06_probe(dh: float) -> None:
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(swaplib.is_file(), "missing real SWAP bridge library")
    swap = Fgc44RealSwap(swaplib)
    _, _, href = swap.initialize()
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), "cold G06 probe not at accepted origin")
    status, q = swap.try_trial(href + dh)
    swap.discard()
    require(swap.state() == origin, "cold G06 probe mutated accepted authority")
    print("FGC44_G06_COLD_PROBE_JSON=" + json.dumps(
        {"dh_m": dh, "status": int(status), "q_swap_m_per_s": float(q)},
        sort_keys=True, separators=(",", ":")
    ))


def cold_probe_status(swaplib: Path, dh: float) -> tuple[int, float]:
    child = subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), "--g06-probe", repr(float(dh))],
        check=True,
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    marker = "FGC44_G06_COLD_PROBE_JSON="
    lines = [line for line in child.stdout.splitlines() if line.startswith(marker)]
    require(len(lines) == 1, f"cold G06 probe marker missing for dh={dh}: {child.stdout}")
    payload = json.loads(lines[0][len(marker):])
    return int(payload["status"]), float(payload["q_swap_m_per_s"])


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP bridge library")

    qualified = json.loads(QUALIFIED_RESPONSE.read_text())
    p = float(qualified["central_real_swap_physical_slope_per_s"])
    s0_expected = float(qualified["positive_surrogate_slope_per_s"])

    swap = Fgc44RealSwap(swaplib)
    hcof, _, href = swap.initialize()
    origin_state = swap.state()
    require(origin_state == (0, 0.0, 0, 0.0), "SWAP not at immutable accepted origin")
    s0 = hcof / (AREA_M2 * DAY_TO_S)
    require(abs(s0 - s0_expected) <= 1.0e-12 * max(1.0, abs(s0_expected)),
            "live positive surrogate no longer matches frozen response evidence")

    gw_points: list[tuple[float, float]] = []
    for qprobe in GW_Q_PROBES_M_PER_S:
        rhs = -qprobe * AREA_M2 * DAY_TO_S
        head, qgw, mf_iters = solve_groundwater_term(libmf6, swaplib, href, 0.0, rhs)
        require(abs(qgw - qprobe) <= 64*np.finfo(float).eps*max(1.0, abs(qprobe)),
                "constant-flux groundwater probe was not preserved")
        gw_points.append((head, qgw))
        print(f"FGC44_GW_SCAN_QPROBE={qprobe:.17g} H={head:.17g} QGW={qgw:.17g} MF_ITERS={mf_iters}")

    heads = np.asarray([x[0] for x in gw_points], dtype=float)
    fluxes = np.asarray([x[1] for x in gw_points], dtype=float)
    a, gw_intercept = np.polyfit(heads, fluxes, 1)
    fit_error = float(np.max(np.abs(a*heads + gw_intercept - fluxes)))
    require(a > 0.0 and math.isfinite(a), "invalid groundwater response slope")
    require(fit_error <= 5.0e-12, "groundwater response is not locally affine enough")

    r = a / abs(p)
    rho_p0 = (p - s0) / (a - s0)
    rho_p1 = 0.0
    rho_p2 = p / a
    require(r > 3.0, "F-GC44 did not land in preregistered P0-contractive region")
    alpha_star = 1.0 / (1.0 - rho_p0)
    require(0.0 < alpha_star <= 1.0, "principled P3 alpha is outside admissible range")
    rho_p3 = 1.0 - alpha_star + alpha_star*rho_p0

    print(f"FGC44_G03_A_PER_S={a:.17g}")
    print(f"FGC44_G03_GW_INTERCEPT={gw_intercept:.17g}")
    print(f"FGC44_G03_GW_FIT_MAX_ERROR={fit_error:.17g}")
    print(f"FGC44_G03_P_PER_S={p:.17g}")
    print(f"FGC44_G03_S0_PER_S={s0:.17g}")
    print(f"FGC44_G03_R={r:.17g}")
    print(f"FGC44_G03_RHO_P0={rho_p0:.17g}")
    print(f"FGC44_G03_RHO_P1={rho_p1:.17g}")
    print(f"FGC44_G03_RHO_P2={rho_p2:.17g}")
    print(f"FGC44_G03_ALPHA_STAR={alpha_star:.17g}")
    print(f"FGC44_G03_RHO_P3={rho_p3:.17g}")

    p_day = p * AREA_M2 * DAY_TO_S
    hstar = run_reference_root(libmf6, swaplib, swap, origin_state, href, p_day)
    print(f"FGC44_G03_REFERENCE_ROOT_M={hstar:.17g}")

    for policy in ("P0", "P1", "P2", "P3", "P4"):
        rho_expected = policy_prediction(policy, p, a, s0, alpha_star)
        for start_dh in FINITE_START_DH_M:
            result = run_policy(
                policy,start_dh,libmf6,swaplib,swap,origin_state,href,hstar,
                hcof,p_day,a,gw_intercept,alpha_star
            )
            print("FGC44_G03_RESULT="+json.dumps(
                {"policy":policy,"rho_expected":rho_expected,**result},
                sort_keys=True,separators=(",",":")
            ))
            require(result["classification"] == "CONVERGED",
                    f"{policy} failed finite-start qualification at {start_dh}: {result}")
            rho_measured = float(result["rho_measured"])
            require(abs(rho_measured-rho_expected) <= RHO_ABS_TOL,
                    f"{policy} measured rho disagrees with theory at {start_dh}: "
                    f"{rho_measured} versus {rho_expected}")

    # G06-A: explicitly reproduce the historical status-4 artifact.  Status 4
    # is CANDIDATE_BUSY, not a corrector failure, and therefore has no head-
    # admissibility meaning.
    artifact_swap = Fgc44RealSwap(swaplib)
    _, _, artifact_href = artifact_swap.initialize()
    artifact_origin = artifact_swap.state()
    _ = artifact_swap.trial(artifact_href)
    busy_status, _ = artifact_swap.try_trial(artifact_href + ARTIFACT_DH_M)
    require(busy_status == CANDIDATE_BUSY_STATUS,
            f"historical candidate-busy artifact did not reproduce: {busy_status}")
    artifact_swap.discard()
    require(artifact_swap.state() == artifact_origin,
            "candidate-busy regression probe mutated accepted authority")
    print(
        f"FGC44_G06_STATUS4_ARTIFACT_DH_M={ARTIFACT_DH_M:.17g} "
        f"STATUS={busy_status} CLASS=CANDIDATE_BUSY"
    )

    # G06-B: true head-admissibility characterization.  Every point runs in a
    # fresh Python process, so no live candidate or worker-local numerical warm
    # start can leak from one head to another.
    cold_scan: list[tuple[float, int, float]] = []
    for dh in ADMISSIBILITY_SCAN_DH_M:
        status, q = cold_probe_status(swaplib, dh)
        require(status != CANDIDATE_BUSY_STATUS,
                f"fresh-process head probe unexpectedly candidate-busy at dh={dh}")
        cold_scan.append((dh, status, q))
        print(
            f"FGC44_G06_COLD_SCAN_DH_M={dh:.17g} STATUS={status} "
            f"QSWAP={q:.17g}"
        )

    trial_failures = [(dh, status) for dh, status, _ in cold_scan
                      if status == TRIAL_FAILED_STATUS]
    unexpected = [(dh, status) for dh, status, _ in cold_scan
                  if status not in (0, TRIAL_FAILED_STATUS)]
    require(not unexpected, f"unexpected G06 participant statuses: {unexpected}")

    # G06-C: if the preregistered grid exposes a true trial failure, choose the
    # nearest-to-zero failure by the frozen rule and halve the head step toward
    # href until a fresh-process corrector accepts it.  If the grid contains no
    # true failure, record that the safeguard trigger is not qualified here.
    if trial_failures:
        selected_dh, _ = min(trial_failures, key=lambda item: (abs(item[0]), item[0]))
        contracted_dh = selected_dh
        recovered = False
        contractions = 0
        recovered_status = TRIAL_FAILED_STATUS
        for contractions in range(1, 13):
            contracted_dh *= 0.5
            recovered_status, _ = cold_probe_status(swaplib, contracted_dh)
            require(recovered_status != CANDIDATE_BUSY_STATUS,
                    "fresh-process safeguard probe became candidate-busy")
            if recovered_status == 0:
                recovered = True
                break
        require(recovered,
                f"factor-1/2 safeguard did not recover from dh={selected_dh}")
        print(
            f"FGC44_G06_SAFEGUARD_TRIGGER=TRIAL_FAILED "
            f"START_DH_M={selected_dh:.17g} CONTRACTED_DH_M={contracted_dh:.17g} "
            f"CONTRACTIONS={contractions} FINAL_STATUS={recovered_status}"
        )
    else:
        print("FGC44_G06_SAFEGUARD_TRIGGER=NO_TRIAL_FAILURE_IN_PREREGISTERED_GRID")

    require(swap.state() == origin_state, "G06 diagnostics mutated SWAP authority")
    print("FGC44_G03_GROUNDWATER_RESPONSE=PASS")
    print("FGC44_G05_FINITE_PERTURBATION=PASS")
    print("FGC44_G06_CLEAN_ADMISSIBILITY=PASS")
    print("GC_FIXED_INTERFACE_FGC44_GLOBALIZATION_GATE=PASS")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--g06-probe":
        run_cold_g06_probe(float(sys.argv[2]))
    else:
        main()
