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
from test_fgc44_real_swap_modflow_end_to_end import AREA_M2, DAY_TO_S, Binding, CountingKernel, Term

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"
CANDIDATE_BUSY_STATUS = 4
TRIAL_FAILED_STATUS = 6
MAX_OUTER = 12
MAX_BACKTRACK = 12
FLUX_TOL = 1.0e-15
HEAD_TOL_M = 5.0e-10
GW_FIT_TOL = 5.0e-12
MERIT_ABS_TOL = 1.0e-18
TANGENT_INITIAL_HALF_WIDTH_M = 2.5e-7
TANGENT_MAX_HALVINGS = 6
NONLINEARITY_THRESHOLD = 0.05

SWAP_CASES = (
    ("C0_CONTROL", 1.0e-4, 1.0e-6),
    ("C1_LOW_FORCING", 1.0e-4, 5.0e-7),
    ("C2_HIGH_FORCING", 1.0e-4, 2.0e-6),
    ("C3_LONG_HIGH", 2.0e-4, 2.0e-6),
)
HEAD_OFFSETS_M = (
    -2.0e-5, -1.0e-5, -5.0e-6, -2.0e-6, -1.0e-6, -5.0e-7, -2.5e-7,
    0.0,
    2.5e-7, 5.0e-7, 1.0e-6, 2.0e-6, 5.0e-6, 1.0e-5, 2.0e-5,
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_and_check_preregistration() -> dict[str, object]:
    data = json.loads(PREREG.read_text())
    require(data["work_unit"] == "GC-FIXED-INTERFACE-G08", "wrong G08 preregistration")
    require(data["status"] == "PREREGISTERED_BEFORE_EXECUTION_AMENDED", "G08 preregistration not frozen")
    frozen = tuple(
        (str(x["id"]), float(x["duration_day"]), float(x["predictor_qbot_cm_per_day"]))
        for x in data["frozen_swap_cases"]
    )
    require(frozen == SWAP_CASES, "G08 SWAP matrix drifted from preregistration")
    offsets = tuple(float(x) for x in data["fixed_head_offsets_m"])
    require(offsets == HEAD_OFFSETS_M, "G08 head scan drifted from preregistration")
    require(float(data["material_nonlinearity"]["threshold_fraction"]) == NONLINEARITY_THRESHOLD,
            "G08 nonlinearity threshold drifted")
    return data


def build_model(
    workdir: Path,
    duration_day: float,
    href: float,
    k_m_per_day: float,
    ss_per_m: float,
    sy: float,
    initial_head_bias_m: float,
) -> None:
    center = href + initial_head_bias_m
    sim = flopy.mf6.MFSimulation(sim_name="FGC44_G08", version="mf6", sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim, time_units="DAYS", nper=1, perioddata=[(duration_day, 1, 1.0)])
    flopy.mf6.ModflowIms(
        sim,
        complexity="MODERATE",
        outer_dvclose=1e-12,
        inner_dvclose=1e-13,
        outer_maximum=100,
        inner_maximum=100,
    )
    gwf = flopy.mf6.ModflowGwf(sim, modelname="GWF_1", save_flows=True, newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(
        gwf, nlay=1, nrow=1, ncol=3, delr=1.0, delc=1.0, top=0.0, botm=-2.0
    )
    flopy.mf6.ModflowGwfic(gwf, strt=np.asarray([[[center, center, center]]], dtype=float))
    flopy.mf6.ModflowGwfnpf(
        gwf, icelltype=1, k=k_m_per_day, save_flows=True
    )
    flopy.mf6.ModflowGwfsto(
        gwf, iconvert=1, ss=ss_per_m, sy=sy, transient={0: True}
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0: [
            ((0, 0, 0), center + 0.002),
            ((0, 0, 2), center - 0.002),
        ]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf, maxbound=1, pname="API_SWAP", filename="api_swap.api")
    sim.write_simulation(silent=True)


def solve_term(
    libmf6: Path,
    swaplib: Path,
    duration_day: float,
    href: float,
    k_m_per_day: float,
    ss_per_m: float,
    sy: float,
    initial_head_bias_m: float,
    hcof_m2_per_day: float,
    rhs_m3_per_day: float,
) -> tuple[float, float, int]:
    with tempfile.TemporaryDirectory(prefix="fgc44-g08-mf-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir, duration_day, href, k_m_per_day, ss_per_m, sy, initial_head_bias_m
        )
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
            require(
                session.acquire_after_prepare_time_step() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            xold = session.accepted_xold.copy()
            binding = [Binding(7001, 1, 2)]
            term = [Term(7001, hcof_m2_per_day, rhs_m3_per_day)]
            converged = None
            for _ in range(session.max_solve_iterations):
                status, iteration = session.publish_and_solve_iteration(binding, term)
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing MODFLOW iteration")
                require(
                    np.array_equal(iteration.accepted_head_old_m, xold),
                    "G08 MODFLOW XOLD drifted",
                )
                if iteration.modflow_converged:
                    converged = iteration
                    break
            require(converged is not None, "G08 MODFLOW solve did not converge")
            head = float(converged.head_m[1])
            qgw = (hcof_m2_per_day * head - rhs_m3_per_day) / (AREA_M2 * DAY_TO_S)
            iterations = int(converged.iteration)
            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            raw.finalize_time_step()
            raw.finalize()
            initialized = False
            return head, qgw, iterations
        finally:
            if initialized:
                raw.finalize()


def initialize_case(
    swap: Fgc44RealSwap, duration_day: float, qbot_cm_per_day: float
) -> tuple[float, float, float, tuple[int, float, int, float], dict[str, float | bool]]:
    hcof, rhs, href = swap.initialize_configured(duration_day, qbot_cm_per_day)
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), "G08 configured SWAP not at immutable origin")
    diag = swap.e1_diagnostics()
    require(bool(diag["mass_complete"]), "G08 configured predictor mass diagnostics incomplete")
    require(math.isfinite(float(diag["u"])) and float(diag["u"]) > 0.0, "invalid predictor u")
    return hcof, rhs, href, origin, diag


def trial_discard(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> tuple[int, float]:
    status, q = swap.try_trial(head)
    require(status != CANDIDATE_BUSY_STATUS, "G08 encountered CANDIDATE_BUSY lifecycle misuse")
    swap.discard()
    require(swap.state() == origin, "G08 diagnostic trial changed accepted SWAP/ledger authority")
    return int(status), float(q)


def scan_swap(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    href: float,
) -> list[dict[str, float | int | None]]:
    rows: list[dict[str, float | int | None]] = []
    for dh in HEAD_OFFSETS_M:
        status, q = trial_discard(swap, origin, href + dh)
        require(status in (0, TRIAL_FAILED_STATUS), f"unexpected G08 trial status {status} at dh={dh}")
        rows.append({
            "dh_m": dh,
            "head_m": href + dh,
            "status": status,
            "q_swap_m_per_s": q if status == 0 else None,
        })
    return rows


def estimate_tangent(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> tuple[float | None, float | None, int]:
    half = TANGENT_INITIAL_HALF_WIDTH_M
    for halving in range(TANGENT_MAX_HALVINGS + 1):
        sm, qm = trial_discard(swap, origin, head - half)
        sp, qp = trial_discard(swap, origin, head + half)
        if sm == 0 and sp == 0:
            slope = (qp - qm) / (2.0 * half)
            if math.isfinite(slope) and slope < 0.0:
                return slope, half, halving
        half *= 0.5
    return None, None, TANGENT_MAX_HALVINGS + 1


def nonlinearity_metric(
    scan: list[dict[str, float | int | None]], p_ref: float
) -> tuple[float, list[float]]:
    slopes: list[float] = []
    ordered = sorted(scan, key=lambda x: float(x["head_m"]))
    for left, right in zip(ordered[:-1], ordered[1:]):
        if int(left["status"]) != 0 or int(right["status"]) != 0:
            continue
        hl = float(left["head_m"])
        hr = float(right["head_m"])
        ql = float(left["q_swap_m_per_s"])
        qr = float(right["q_swap_m_per_s"])
        slope = (qr - ql) / (hr - hl)
        if math.isfinite(slope):
            slopes.append(slope)
    require(slopes, "G08 has no admissible secant slopes")
    rel = [abs(x - p_ref) / abs(p_ref) for x in slopes]
    return max(rel), slopes


def groundwater_response(
    libmf6: Path,
    swaplib: Path,
    duration_day: float,
    href: float,
    regime: dict[str, object],
    sy: float,
) -> tuple[float, float, float]:
    points: list[tuple[float, float]] = []
    for qprobe in [float(x) for x in regime["q_probes_m_per_s"]]:
        head, qgw, mf_iters = solve_term(
            libmf6,
            swaplib,
            duration_day,
            href,
            float(regime["k_m_per_day"]),
            float(regime["ss_per_m"]),
            sy,
            float(regime["initial_head_bias_m"]),
            0.0,
            -qprobe * AREA_M2 * DAY_TO_S,
        )
        require(
            abs(qgw - qprobe) <= 64 * np.finfo(float).eps * max(1.0, abs(qprobe)),
            "G08 constant-flux groundwater probe changed imposed flux",
        )
        points.append((head, qgw))
        print(
            f"FGC44_G08_GW_PROBE REGIME={regime['id']} Q={qprobe:.17g} "
            f"H={head:.17g} MF_ITERS={mf_iters}"
        )
    heads = np.asarray([x[0] for x in points], dtype=float)
    fluxes = np.asarray([x[1] for x in points], dtype=float)
    a, intercept = np.polyfit(heads, fluxes, 1)
    fit_error = float(np.max(np.abs(a * heads + intercept - fluxes)))
    require(math.isfinite(a) and a > 0.0, "G08 groundwater response is nonpositive/nonfinite")
    require(fit_error <= GW_FIT_TOL, f"G08 groundwater fit error too large: {fit_error}")
    return float(a), float(intercept), fit_error


def residual_at(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    a: float,
    intercept: float,
) -> tuple[int, float | None, float | None]:
    status, q = trial_discard(swap, origin, head)
    if status != 0:
        return status, None, None
    residual = q - (a * head + intercept)
    return 0, q, residual


def reference_root(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    scan: list[dict[str, float | int | None]],
    a: float,
    intercept: float,
) -> float | None:
    ordered = sorted(scan, key=lambda x: float(x["head_m"]))
    bracket: tuple[float, float, float, float] | None = None
    for row in ordered:
        if int(row["status"]) == 0:
            h = float(row["head_m"])
            r = float(row["q_swap_m_per_s"]) - (a * h + intercept)
            if abs(r) <= FLUX_TOL:
                return h
    for left, right in zip(ordered[:-1], ordered[1:]):
        if int(left["status"]) != 0 or int(right["status"]) != 0:
            continue
        hl = float(left["head_m"])
        hr = float(right["head_m"])
        rl = float(left["q_swap_m_per_s"]) - (a * hl + intercept)
        rr = float(right["q_swap_m_per_s"]) - (a * hr + intercept)
        if rl * rr < 0.0:
            bracket = (hl, hr, rl, rr)
            break
    if bracket is None:
        return None

    lo, hi, rlo, rhi = bracket
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        status, _, rm = residual_at(swap, origin, mid, a, intercept)
        if status != 0 or rm is None:
            return None
        if abs(rm) <= FLUX_TOL or abs(hi - lo) <= 1.0e-12:
            return mid
        if rlo * rm <= 0.0:
            hi, rhi = mid, rm
        else:
            lo, rlo = mid, rm
    return 0.5 * (lo + hi)


def select_starts(scan: list[dict[str, float | int | None]]) -> list[tuple[str, float]]:
    negative = [
        float(x["dh_m"]) for x in scan if int(x["status"]) == 0 and float(x["dh_m"]) < 0.0
    ]
    positive = [
        float(x["dh_m"]) for x in scan if int(x["status"]) == 0 and float(x["dh_m"]) > 0.0
    ]
    starts: list[tuple[str, float]] = []
    if negative:
        starts.append(("NEG", min(negative)))
    if positive:
        starts.append(("POS", max(positive)))
    return starts


def run_policy(
    policy: str,
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    duration_day: float,
    qbot_cm_per_day: float,
    regime: dict[str, object],
    sy: float,
    a: float,
    intercept: float,
    reference_root_m: float,
    start_dh_m: float,
) -> dict[str, object]:
    _, _, href, origin, _ = initialize_case(swap, duration_day, qbot_cm_per_day)
    head = href + start_dh_m
    contractions_total = 0
    merit_increases = 0
    inadmissible_raw = 0
    tangent_halvings_total = 0
    accepted_trace: list[dict[str, float | int]] = []

    for outer in range(1, MAX_OUTER + 1):
        status, q, residual = residual_at(swap, origin, head, a, intercept)
        if status != 0 or q is None or residual is None:
            return {
                "classification": "CURRENT_HEAD_INADMISSIBLE",
                "outer": outer,
                "status": status,
                "contractions": contractions_total,
                "merit_increases": merit_increases,
                "inadmissible_raw": inadmissible_raw,
            }
        if abs(residual) <= FLUX_TOL and abs(head - reference_root_m) <= HEAD_TOL_M:
            return {
                "classification": "CONVERGED",
                "outer": outer - 1,
                "final_head_m": head,
                "final_residual_m_per_s": residual,
                "head_error_m": head - reference_root_m,
                "contractions": contractions_total,
                "merit_increases": merit_increases,
                "inadmissible_raw": inadmissible_raw,
                "tangent_halvings": tangent_halvings_total,
                "trace": accepted_trace,
            }

        p, half_width, tangent_halvings = estimate_tangent(swap, origin, head)
        if p is None or half_width is None:
            return {
                "classification": "TANGENT_UNAVAILABLE",
                "outer": outer,
                "contractions": contractions_total,
                "merit_increases": merit_increases,
                "inadmissible_raw": inadmissible_raw,
            }
        tangent_halvings_total += tangent_halvings
        slope_day = p * AREA_M2 * DAY_TO_S
        rhs = slope_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, _, mf_iters = solve_term(
            libmf6,
            swaplib,
            duration_day,
            href,
            float(regime["k_m_per_day"]),
            float(regime["ss_per_m"]),
            sy,
            float(regime["initial_head_bias_m"]),
            slope_day,
            rhs,
        )

        raw_status, raw_q, raw_residual = residual_at(swap, origin, raw_head, a, intercept)
        if raw_status != 0:
            inadmissible_raw += 1

        if policy == "P1":
            if raw_status != 0 or raw_q is None or raw_residual is None:
                return {
                    "classification": "RAW_PROPOSAL_INADMISSIBLE",
                    "outer": outer,
                    "status": raw_status,
                    "raw_head_m": raw_head,
                    "contractions": contractions_total,
                    "merit_increases": merit_increases,
                    "inadmissible_raw": inadmissible_raw,
                    "tangent_halvings": tangent_halvings_total,
                }
            candidate = raw_head
            candidate_residual = raw_residual
            if abs(candidate_residual) > abs(residual) + MERIT_ABS_TOL:
                merit_increases += 1
        elif policy == "P4":
            candidate = raw_head
            candidate_residual = raw_residual
            accepted = (
                raw_status == 0
                and candidate_residual is not None
                and abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL
            )
            local_contractions = 0
            while not accepted and local_contractions < MAX_BACKTRACK:
                candidate = head + 0.5 * (candidate - head)
                local_contractions += 1
                cstatus, _, cresidual = residual_at(swap, origin, candidate, a, intercept)
                candidate_residual = cresidual
                accepted = (
                    cstatus == 0
                    and candidate_residual is not None
                    and abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL
                )
            contractions_total += local_contractions
            if not accepted or candidate_residual is None:
                return {
                    "classification": "SAFEGUARD_EXHAUSTED",
                    "outer": outer,
                    "raw_status": raw_status,
                    "raw_head_m": raw_head,
                    "contractions": contractions_total,
                    "merit_increases": merit_increases,
                    "inadmissible_raw": inadmissible_raw,
                    "tangent_halvings": tangent_halvings_total,
                }
            require(
                abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL,
                "G08 P4 accepted a merit-increasing step",
            )
        else:
            raise ValueError(policy)

        accepted_trace.append({
            "outer": outer,
            "head_m": candidate,
            "residual_m_per_s": float(candidate_residual),
            "raw_head_m": raw_head,
            "tangent_per_s": p,
            "tangent_half_width_m": half_width,
            "mf_iterations": mf_iters,
        })
        head = candidate

    status, _, final_residual = residual_at(swap, origin, head, a, intercept)
    return {
        "classification": "OUTER_BUDGET_EXHAUSTED",
        "outer": MAX_OUTER,
        "status": status,
        "final_head_m": head,
        "final_residual_m_per_s": final_residual,
        "head_error_m": head - reference_root_m,
        "contractions": contractions_total,
        "merit_increases": merit_increases,
        "inadmissible_raw": inadmissible_raw,
        "tangent_halvings": tangent_halvings_total,
        "trace": accepted_trace,
    }


def main() -> None:
    prereg = load_and_check_preregistration()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP bridge library")

    regimes = [dict(x) for x in prereg["groundwater_regimes"]]
    swap = Fgc44RealSwap(swaplib)
    case_rows: list[dict[str, object]] = []
    policy_rows: list[dict[str, object]] = []

    for case_id, duration_day, qbot_cm_per_day in SWAP_CASES:
        _, _, href, origin, diag = initialize_case(swap, duration_day, qbot_cm_per_day)
        scan = scan_swap(swap, origin, href)
        p_ref, p_half, p_halvings = estimate_tangent(swap, origin, href)
        require(p_ref is not None and p_half is not None, f"G08 href tangent unavailable for {case_id}")
        max_rel_change, secants = nonlinearity_metric(scan, p_ref)
        material_nonlinear = max_rel_change >= NONLINEARITY_THRESHOLD
        u = float(diag["u"])
        starts = select_starts(scan)
        require(starts, f"G08 has no nonzero admissible starts for {case_id}")

        case_row = {
            "case_id": case_id,
            "duration_day": duration_day,
            "qbot_cm_per_day": qbot_cm_per_day,
            "reference_head_m": href,
            "predictor_u": u,
            "p_ref_per_s": p_ref,
            "p_ref_half_width_m": p_half,
            "p_ref_halvings": p_halvings,
            "max_relative_slope_change": max_rel_change,
            "material_nonlinear": material_nonlinear,
            "admissible_offsets_m": [
                float(x["dh_m"]) for x in scan if int(x["status"]) == 0
            ],
            "failed_offsets_m": [
                float(x["dh_m"]) for x in scan if int(x["status"]) == TRIAL_FAILED_STATUS
            ],
            "secant_slopes_per_s": secants,
            "starts": [{"side": side, "dh_m": dh} for side, dh in starts],
        }
        case_rows.append(case_row)
        print("FGC44_G08_SWAP_CASE_JSON=" + json.dumps(case_row, sort_keys=True, separators=(",", ":")))

        for regime in regimes:
            formula = str(regime["sy_formula"])
            if formula == "0.75*u_predictor":
                sy = 0.75 * u
            elif formula == "2.0*u_predictor":
                sy = 2.0 * u
            elif formula == "0.15":
                sy = 0.15
            else:
                raise AssertionError(f"unknown G08 sy formula {formula}")

            a, intercept, fit_error = groundwater_response(
                libmf6, swaplib, duration_day, href, regime, sy
            )
            realized_r = a / abs(p_ref)
            root = reference_root(swap, origin, scan, a, intercept)
            regime_row = {
                "case_id": case_id,
                "regime_id": regime["id"],
                "sy": sy,
                "a_per_s": a,
                "gw_intercept": intercept,
                "gw_fit_error_m_per_s": fit_error,
                "realized_r": realized_r,
                "initial_head_bias_m": float(regime["initial_head_bias_m"]),
                "reference_root_m": root,
            }
            print("FGC44_G08_REGIME_JSON=" + json.dumps(regime_row, sort_keys=True, separators=(",", ":")))

            if root is None:
                policy_rows.append({
                    **regime_row,
                    "policy": "NONE",
                    "start_side": "NONE",
                    "start_dh_m": None,
                    "classification": "NO_ADMISSIBLE_SIGN_CHANGE_ROOT",
                })
                continue

            for side, start_dh in starts:
                pair: dict[str, dict[str, object]] = {}
                for policy in ("P1", "P4"):
                    result = run_policy(
                        policy,
                        libmf6,
                        swaplib,
                        swap,
                        duration_day,
                        qbot_cm_per_day,
                        regime,
                        sy,
                        a,
                        intercept,
                        root,
                        start_dh,
                    )
                    row = {
                        **regime_row,
                        "policy": policy,
                        "start_side": side,
                        "start_dh_m": start_dh,
                        **result,
                    }
                    policy_rows.append(row)
                    pair[policy] = result
                    print("FGC44_G08_POLICY_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
                print("FGC44_G08_PAIR_JSON=" + json.dumps({
                    "case_id": case_id,
                    "regime_id": regime["id"],
                    "start_side": side,
                    "start_dh_m": start_dh,
                    "p1_classification": pair["P1"]["classification"],
                    "p4_classification": pair["P4"]["classification"],
                    "p4_contractions": pair["P4"].get("contractions", 0),
                }, sort_keys=True, separators=(",", ":")))

        require(swap.state() == origin, f"G08 case {case_id} changed accepted authority")

    p1 = [x for x in policy_rows if x.get("policy") == "P1"]
    p4 = [x for x in policy_rows if x.get("policy") == "P4"]
    p1_converged = sum(x.get("classification") == "CONVERGED" for x in p1)
    p4_converged = sum(x.get("classification") == "CONVERGED" for x in p4)
    p4_safeguard_cases = sum(int(x.get("contractions", 0)) > 0 for x in p4)
    p4_total_contractions = sum(int(x.get("contractions", 0)) for x in p4)
    material_cases = sum(bool(x["material_nonlinear"]) for x in case_rows)

    pair_keys = {
        (x["case_id"], x["regime_id"], x["start_side"], x["start_dh_m"])
        for x in p1
    } & {
        (x["case_id"], x["regime_id"], x["start_side"], x["start_dh_m"])
        for x in p4
    }
    p1_fail_p4_success = 0
    for key in pair_keys:
        r1 = next(x for x in p1 if (x["case_id"],x["regime_id"],x["start_side"],x["start_dh_m"]) == key)
        r4 = next(x for x in p4 if (x["case_id"],x["regime_id"],x["start_side"],x["start_dh_m"]) == key)
        if r1["classification"] != "CONVERGED" and r4["classification"] == "CONVERGED":
            p1_fail_p4_success += 1

    summary = {
        "swap_case_count": len(case_rows),
        "material_nonlinear_case_count": material_cases,
        "policy_case_count": len(p1) + len(p4),
        "p1_case_count": len(p1),
        "p1_converged_count": p1_converged,
        "p4_case_count": len(p4),
        "p4_converged_count": p4_converged,
        "p4_safeguard_case_count": p4_safeguard_cases,
        "p4_total_contractions": p4_total_contractions,
        "p1_fail_p4_success_count": p1_fail_p4_success,
        "nonlinear_real_swap_qualification": (
            "EXERCISED" if material_cases > 0 else "NOT_ESTABLISHED"
        ),
        "real_swap_safeguard_qualification": (
            "EXERCISED" if p4_safeguard_cases > 0 else "NOT_EXERCISED"
        ),
    }
    print("FGC44_G08_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G08_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G08_GROUNDWATER_RESPONSE_ORACLE=PASS")
    print("GC_FIXED_INTERFACE_G08_EXECUTION=PASS")


if __name__ == "__main__":
    main()
