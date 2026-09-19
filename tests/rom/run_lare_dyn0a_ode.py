#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from dataclasses import dataclass

import numpy as np
from scipy.integrate import solve_ivp

THETA_R = 0.02
THETA_S = 0.427494
ALPHA = 0.021659
N_VG = 1.734737
M_VG = 1.0 - 1.0 / N_VG
KS = 31.225016
LAMBDA = 0.98087
OBS_DT = 0.0008
STEPS = 1024
HEUN_DT = (0.0008, 0.0004, 0.0002)
HEUN_CORRECTOR_TOL_THETA = 1.0e-13
HEUN_MAX_CORRECTOR = 50

PARTITIONS = {
    "D3": np.asarray([140.0, 10.0, 10.0], dtype=float),
    "D2": np.asarray([150.0, 10.0], dtype=float),
}
INITIAL_SE = (0.65, 0.85, 0.95)
TOP_SEQUENCES = {
    "EQ": ((1.0, 1024),),
    "WET": ((1.5, 256), (1.0, 768)),
    "DRY": ((0.5, 256), (1.0, 768)),
    "WET_DRY": ((1.5, 256), (0.5, 256), (1.0, 512)),
}
BOTTOM_VARIANTS = ("FIXED_FLUX", "FREE_DRAINAGE")


@dataclass(frozen=True)
class Case:
    partition: str
    se0: float
    forcing_id: str
    bottom: str

    @property
    def id(self) -> str:
        return f"{self.partition}_SE{int(round(100*self.se0)):03d}_{self.bottom}_{self.forcing_id}"


def theta_from_se(se: float) -> float:
    return THETA_R + se * (THETA_S - THETA_R)


def se_from_theta(theta: np.ndarray) -> np.ndarray:
    return (theta - THETA_R) / (THETA_S - THETA_R)


def psi_k(theta: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    se = se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se <= 0.0) or np.any(se >= 1.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN theta endpoint")
    psi = np.power(np.power(se, -1.0 / M_VG) - 1.0, 1.0 / N_VG) / ALPHA
    term = 1.0 - np.power(1.0 - np.power(se, 1.0 / M_VG), M_VG)
    k = KS * np.power(se, LAMBDA) * np.square(term)
    if np.any(~np.isfinite(psi)) or np.any(~np.isfinite(k)) or np.any(k < 0.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN constitutive")
    # SWAP's current B01 provider has a near-saturation smoothing branch for h > -0.01 cm.
    # DYN0A deliberately stays on the standard MvG branch.
    if np.any(psi <= 0.01):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN near-saturation smoothing")
    return psi, k


def interface_fluxes(theta: np.ndarray, dz: np.ndarray) -> np.ndarray:
    psi, k = psi_k(theta)
    if len(theta) <= 1:
        return np.empty(0, dtype=float)
    out = np.empty(len(theta) - 1, dtype=float)
    for i in range(len(out)):
        di = dz[i]
        dj = dz[i + 1]
        kij = (dj * k[i] + di * k[i + 1]) / (di + dj)
        out[i] = kij * (1.0 + 2.0 * (psi[i + 1] - psi[i]) / (di + dj))
    return out


def q_bottom(theta: np.ndarray, k0: float, bottom: str) -> float:
    if bottom == "FIXED_FLUX":
        return k0
    if bottom == "FREE_DRAINAGE":
        _, k = psi_k(theta)
        return float(k[-1])
    raise ValueError(bottom)


def rhs(y: np.ndarray, dz: np.ndarray, qtop: float, k0: float, bottom: str) -> np.ndarray:
    n = len(dz)
    w = y[:n]
    theta = w / dz
    qint = interface_fluxes(theta, dz)
    qb = q_bottom(theta, k0, bottom)
    dy = np.zeros_like(y)
    for i in range(n):
        qup = qtop if i == 0 else qint[i - 1]
        qdn = qb if i == n - 1 else qint[i]
        dy[i] = qup - qdn
    dy[n] = qtop
    dy[n + 1] = qb
    return dy


def forcing_segments(case: Case, k0: float) -> list[tuple[float, float, float]]:
    out = []
    start = 0.0
    for multiplier, steps in TOP_SEQUENCES[case.forcing_id]:
        end = start + steps * OBS_DT
        out.append((start, end, multiplier * k0))
        start = end
    if abs(start - STEPS * OBS_DT) > 1.0e-14:
        raise AssertionError("forcing horizon mismatch")
    return out


def qtop_at_time(case: Case, k0: float, t: float) -> float:
    # Right-continuous on observation boundaries; only used for diagnostics.
    for start, end, q in forcing_segments(case, k0):
        if t < end - 1.0e-15:
            return q
    return forcing_segments(case, k0)[-1][2]


def initial(case: Case) -> tuple[np.ndarray, np.ndarray, float]:
    dz = PARTITIONS[case.partition].copy()
    theta0 = theta_from_se(case.se0)
    theta = np.full(len(dz), theta0, dtype=float)
    _, k = psi_k(theta)
    k0 = float(k[0])
    y0 = np.concatenate([theta * dz, [0.0, 0.0]])
    return dz, y0, k0


def solve_high_accuracy(case: Case) -> dict[str, object]:
    dz, y, k0 = initial(case)
    times = [0.0]
    ys = [y.copy()]
    for start, end, qtop in forcing_segments(case, k0):
        eval_times = np.arange(
            math.floor((start + 1.0e-14) / OBS_DT) + 1,
            round(end / OBS_DT) + 1,
            dtype=int,
        ) * OBS_DT
        if len(eval_times) == 0 or abs(eval_times[-1] - end) > 1.0e-12:
            raise AssertionError("segment observation grid mismatch")
        sol = solve_ivp(
            lambda t, state: rhs(state, dz, qtop, k0, case.bottom),
            (start, end),
            y,
            method="DOP853",
            t_eval=eval_times,
            rtol=1.0e-11,
            atol=1.0e-13,
            max_step=OBS_DT / 4.0,
        )
        if not sol.success:
            raise RuntimeError(sol.message)
        for j in range(sol.y.shape[1]):
            times.append(float(sol.t[j]))
            ys.append(sol.y[:, j].copy())
        y = sol.y[:, -1].copy()

    arr = np.asarray(ys)
    tarr = np.asarray(times)
    if len(tarr) != STEPS + 1 or np.max(np.abs(tarr - np.arange(STEPS + 1) * OBS_DT)) > 1.0e-12:
        raise AssertionError("high-accuracy observation grid mismatch")
    return trajectory(case, dz, k0, tarr, arr, "DOP853_HIGH_ACCURACY")


def heun_step(y: np.ndarray, dt: float, dz: np.ndarray, qtop: float, k0: float, bottom: str) -> tuple[np.ndarray, int]:
    f0 = rhs(y, dz, qtop, k0, bottom)
    guess = y + dt * f0
    n = len(dz)
    for iteration in range(1, HEUN_MAX_CORRECTOR + 1):
        nxt = y + 0.5 * dt * (f0 + rhs(guess, dz, qtop, k0, bottom))
        if np.max(np.abs(nxt[:n] / dz - guess[:n] / dz)) <= HEUN_CORRECTOR_TOL_THETA:
            return nxt, iteration
        guess = nxt
    raise RuntimeError("iterative Heun corrector did not converge")


def solve_heun(case: Case, dt: float) -> dict[str, object]:
    ratio = OBS_DT / dt
    substeps = int(round(ratio))
    if abs(ratio - substeps) > 1.0e-12 or substeps <= 0:
        raise ValueError("Heun dt must divide observation dt")
    dz, y, k0 = initial(case)
    times = [0.0]
    ys = [y.copy()]
    max_iter = 0
    t = 0.0
    for obs_step in range(1, STEPS + 1):
        for _ in range(substeps):
            qtop = qtop_at_time(case, k0, t + 0.5 * dt)
            y, iterations = heun_step(y, dt, dz, qtop, k0, case.bottom)
            max_iter = max(max_iter, iterations)
            t += dt
        times.append(obs_step * OBS_DT)
        ys.append(y.copy())
    result = trajectory(
        case, dz, k0, np.asarray(times), np.asarray(ys),
        f"ITERATIVE_HEUN_DT_{dt:.7f}"
    )
    result["max_corrector_iterations"] = max_iter
    return result


def trajectory(
    case: Case,
    dz: np.ndarray,
    k0: float,
    times: np.ndarray,
    ys: np.ndarray,
    route: str,
) -> dict[str, object]:
    n = len(dz)
    storage = ys[:, :n]
    theta = storage / dz[None, :]
    qbot = np.asarray([q_bottom(row, k0, case.bottom) for row in theta])
    total = np.sum(storage, axis=1)
    qtop_cum = ys[:, n]
    qbot_cum = ys[:, n + 1]
    ledger = total - total[0] - (qtop_cum - qbot_cum)
    min_theta = float(np.min(theta))
    max_theta = float(np.max(theta))
    if min_theta <= THETA_R or max_theta >= THETA_S:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN trajectory endpoint")
    return {
        "route": route,
        "times_day": times.tolist(),
        "layer_storage_cm": storage.tolist(),
        "layer_theta": theta.tolist(),
        "total_storage_cm": total.tolist(),
        "cumulative_top_downward_cm": qtop_cum.tolist(),
        "cumulative_bottom_downward_cm": qbot_cum.tolist(),
        "bottom_downward_flux_cm_per_day": qbot.tolist(),
        "max_abs_water_ledger_cm": float(np.max(np.abs(ledger))),
        "theta_range": [min_theta, max_theta],
        "k0_cm_per_day": k0,
    }


def compare(a: dict[str, object], b: dict[str, object]) -> dict[str, float]:
    sa = np.asarray(a["layer_storage_cm"], dtype=float)
    sb = np.asarray(b["layer_storage_cm"], dtype=float)
    ta = np.asarray(a["total_storage_cm"], dtype=float)
    tb = np.asarray(b["total_storage_cm"], dtype=float)
    qa = np.asarray(a["bottom_downward_flux_cm_per_day"], dtype=float)
    qb = np.asarray(b["bottom_downward_flux_cm_per_day"], dtype=float)
    ca = np.asarray(a["cumulative_bottom_downward_cm"], dtype=float)
    cb = np.asarray(b["cumulative_bottom_downward_cm"], dtype=float)
    return {
        "max_abs_layer_storage_cm": float(np.max(np.abs(sa - sb))),
        "max_abs_total_storage_cm": float(np.max(np.abs(ta - tb))),
        "max_abs_bottom_flux_cm_per_day": float(np.max(np.abs(qa - qb))),
        "max_abs_cumulative_bottom_cm": float(np.max(np.abs(ca - cb))),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    cases = [
        Case(partition, se0, forcing_id, bottom)
        for partition in ("D3", "D2")
        for se0 in INITIAL_SE
        for forcing_id in TOP_SEQUENCES
        for bottom in BOTTOM_VARIANTS
    ]

    results = {}
    max_ledger = 0.0
    equilibrium_max_change = 0.0
    for case in cases:
        high = solve_high_accuracy(case)
        heun = {f"{dt:.7f}": solve_heun(case, dt) for dt in HEUN_DT}
        floor = {
            "heun_dt_vs_high_accuracy": {
                key: compare(value, high) for key, value in heun.items()
            },
            "heun_refinement": {
                "dt_0.0008_vs_0.0004": compare(heun["0.0008000"], heun["0.0004000"]),
                "dt_0.0004_vs_0.0002": compare(heun["0.0004000"], heun["0.0002000"]),
            },
        }
        max_ledger = max(
            max_ledger,
            float(high["max_abs_water_ledger_cm"]),
            *(float(value["max_abs_water_ledger_cm"]) for value in heun.values()),
        )
        if case.forcing_id == "EQ":
            total = np.asarray(high["total_storage_cm"], dtype=float)
            equilibrium_max_change = max(
                equilibrium_max_change, float(np.max(np.abs(total - total[0])))
            )

        results[case.id] = {
            "case": {
                "partition": case.partition,
                "layer_thickness_cm": PARTITIONS[case.partition].tolist(),
                "initial_effective_saturation": case.se0,
                "forcing_id": case.forcing_id,
                "bottom_boundary": case.bottom,
            },
            "high_accuracy": high,
            "heun_numerical_floor": floor,
            "heun_max_corrector_iterations": {
                key: value["max_corrector_iterations"] for key, value in heun.items()
            },
        }

    payload = {
        "schema": "swap5.lare.dyn0a.ode-reference.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-DYN0A-ODE",
        "decision": "LARE_DYN0A_ODE_REFERENCE_GENERATED",
        "model": {
            "interface_closure": "HE2021_EQ24_ADJACENT_FIXED_LAYER_EXTENSION",
            "bottom_variants": list(BOTTOM_VARIANTS),
            "observation_dt_day": OBS_DT,
            "steps": STEPS,
            "mvg": {
                "theta_r": THETA_R, "theta_s": THETA_S, "alpha_per_cm": ALPHA,
                "n": N_VG, "m": M_VG, "Ksat_cm_per_day": KS, "lambda": LAMBDA,
            },
        },
        "case_count": len(cases),
        "max_abs_water_ledger_cm": max_ledger,
        "max_abs_equilibrium_total_storage_change_cm": equilibrium_max_change,
        "cases": results,
        "fine_or_coarse_richards_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": payload["schema"],
        "decision": payload["decision"],
        "case_count": len(cases),
        "max_abs_water_ledger_cm": max_ledger,
        "max_abs_equilibrium_total_storage_change_cm": equilibrium_max_change,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
