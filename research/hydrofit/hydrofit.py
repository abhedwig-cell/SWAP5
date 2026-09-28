"""Research-only modern soil-hydraulic fitting utilities for F-HYDROFIT01.

No production SWAP code imports this module.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Literal, Sequence

import numpy as np

try:
    from scipy.optimize import least_squares
except ImportError:  # pragma: no cover
    least_squares = None

Semantics = Literal["textbook_mvg", "swap_default_mvg"]
Family = Literal["theta", "K"]


@dataclass(frozen=True)
class MvGParameters:
    theta_r: float
    theta_s: float
    alpha: float  # cm^-1
    n: float
    Ks: float     # cm d^-1 in SWAP-native use
    l: float = 0.5
    h_entry: float = 0.0

    @property
    def m(self) -> float:
        return 1.0 - 1.0 / self.n

    def validate(self) -> None:
        vals = (self.theta_r, self.theta_s, self.alpha, self.n, self.Ks, self.l, self.h_entry)
        if not all(np.isfinite(vals)):
            raise ValueError("parameters must be finite")
        if not (0.0 <= self.theta_r < self.theta_s <= 1.0):
            raise ValueError("require 0 <= theta_r < theta_s <= 1")
        if self.alpha <= 0.0 or self.n <= 1.0 or self.Ks <= 0.0:
            raise ValueError("require alpha>0, n>1 and Ks>0")


@dataclass(frozen=True)
class Observation:
    family: Family
    head_cm: float
    value: float
    sigma: float | None = None

    def validate(self, log_k: bool) -> None:
        if self.family not in ("theta", "K"):
            raise ValueError("family must be theta or K")
        if not np.isfinite(self.head_cm) or not np.isfinite(self.value):
            raise ValueError("observation must be finite")
        if self.sigma is not None and (not np.isfinite(self.sigma) or self.sigma <= 0.0):
            raise ValueError("sigma must be positive")
        if self.family == "K" and log_k and self.value <= 0.0:
            raise ValueError("log-K residual requires positive K")


@dataclass(frozen=True)
class FitConfig:
    semantics: Semantics = "swap_default_mvg"
    log_k: bool = True
    theta_scale: float = 1.0
    k_scale: float = 1.0
    fixed_l: float = 0.5
    fixed_h_entry: float = 0.0
    lower: tuple[float, ...] = (0.0, 0.05, 1e-8, 1.000001, 1e-12)
    upper: tuple[float, ...] = (0.8, 0.9, 10.0, 20.0, 1e8)

    def validate(self) -> None:
        if self.semantics not in ("textbook_mvg", "swap_default_mvg"):
            raise ValueError("unknown forward semantics")
        if self.theta_scale <= 0.0 or self.k_scale <= 0.0:
            raise ValueError("family scales must be positive")
        if len(self.lower) != 5 or len(self.upper) != 5:
            raise ValueError("five fitted bounds required")
        if np.any(np.asarray(self.lower) >= np.asarray(self.upper)):
            raise ValueError("invalid bounds")


@dataclass
class FitResult:
    parameters: MvGParameters
    objective: float
    residuals: np.ndarray
    jacobian: np.ndarray
    singular_values: np.ndarray
    condition_number: float
    active_mask: np.ndarray
    success: bool
    message: str
    nfev: int


def _derived(p: MvGParameters) -> tuple[float, float]:
    p.validate()
    return p.theta_s - p.theta_r, p.m


def textbook_theta(head_cm: np.ndarray | float, p: MvGParameters) -> np.ndarray:
    dtheta, m = _derived(p)
    h = np.asarray(head_cm, dtype=float)
    ahn = np.abs(p.alpha * h) ** p.n
    unsat = p.theta_r + dtheta / (1.0 + ahn) ** m
    return np.where(h >= 0.0, p.theta_s, unsat)


def textbook_k(head_cm: np.ndarray | float, p: MvGParameters) -> np.ndarray:
    dtheta, m = _derived(p)
    theta = textbook_theta(head_cm, p)
    se = np.clip((theta - p.theta_r) / dtheta, 0.0, 1.0)
    core = p.Ks * se**p.l * (1.0 - (1.0 - se ** (1.0 / m)) ** m) ** 2
    return np.where(np.asarray(head_cm, dtype=float) >= 0.0, p.Ks, core)


def swap_theta(head_cm: np.ndarray | float, p: MvGParameters) -> np.ndarray:
    """Exact scalar-equation translation of canonical B1.10 default-MvG theta route."""
    dtheta, m = _derived(p)
    h = np.asarray(head_cm, dtype=float)
    hc = -1.0e-2
    out = np.empty_like(h)
    sat = h >= 0.0
    out[sat] = p.theta_s
    u = ~sat
    if p.h_entry > hc:
        theta_hc = p.theta_r + dtheta / (1.0 + abs(p.alpha * hc) ** p.n) ** m
        slope = (p.theta_s - theta_hc) / (-hc)
        near = u & (h > hc)
        out[near] = np.minimum(theta_hc + slope * (h[near] - hc), p.theta_s)
        far = u & ~near
        out[far] = p.theta_r + dtheta / (1.0 + np.abs(p.alpha * h[far]) ** p.n) ** m
    else:
        h105 = 1.05 * p.h_entry
        scale = (1.0 + abs(p.alpha * p.h_entry) ** p.n) ** (-m)
        t105 = p.theta_r + dtheta * (1.0 + abs(p.alpha * p.h_entry) ** p.n) ** m / (
            1.0 + abs(p.alpha * h105) ** p.n
        ) ** m
        c105 = (
            dtheta * p.alpha * m * p.n * abs(p.alpha * h105) ** (p.n - 1.0)
            * (1.0 + abs(p.alpha * p.h_entry) ** p.n) ** m
            / (1.0 + abs(p.alpha * h105) ** p.n) ** (m + 1.0)
        )
        a = (t105 - p.theta_s - c105 * h105) / (c105 * h105**2)
        b = (t105 - p.theta_s) ** 2 / (t105 - p.theta_s - c105 * h105)
        c41, c42 = a, a * b
        near = u & (h >= h105)
        out[near] = p.theta_s + c42 * h[near] / (1.0 + c41 * h[near])
        far = u & ~near
        out[far] = p.theta_r + dtheta / (
            (1.0 + np.abs(p.alpha * h[far]) ** p.n) ** m * scale
        )
    return out


def swap_k(head_cm: np.ndarray | float, p: MvGParameters) -> np.ndarray:
    """Exact default route without the optional KSATEXM extension."""
    dtheta, m = _derived(p)
    h = np.asarray(head_cm, dtype=float)
    theta = swap_theta(h, p)
    relsat = (theta - p.theta_r) / dtheta
    out = np.empty_like(h)
    dry = h < -1.0e14
    out[dry] = 1.0e-10
    work = ~dry
    if p.h_entry > -1.0e-2:
        sat = work & (relsat > 1.0 - 1.0e-6)
        out[sat] = p.Ks
        q = work & ~sat
        term = (1.0 - relsat[q] ** (1.0 / m)) ** m
        out[q] = p.Ks * relsat[q] ** p.l * (1.0 - term) ** 2
    else:
        sat = work & (h >= p.h_entry)
        out[sat] = p.Ks
        q = work & ~sat
        c28 = (1.0 + abs(p.alpha * p.h_entry) ** p.n) ** (-m)
        se = (1.0 + np.abs(p.alpha * h[q]) ** p.n) ** (-m) / c28
        term1 = (1.0 - (se * c28) ** (1.0 / m)) ** m
        term2 = (1.0 - c28 ** (1.0 / m)) ** m
        out[q] = p.Ks * se**p.l * ((1.0 - term1) / (1.0 - term2)) ** 2
    return np.minimum(out, p.Ks)


def evaluate(head_cm: np.ndarray | float, p: MvGParameters, semantics: Semantics) -> tuple[np.ndarray, np.ndarray]:
    if semantics == "textbook_mvg":
        return textbook_theta(head_cm, p), textbook_k(head_cm, p)
    if semantics == "swap_default_mvg":
        return swap_theta(head_cm, p), swap_k(head_cm, p)
    raise ValueError("unknown semantics")


def _decode(x: Sequence[float], cfg: FitConfig) -> MvGParameters:
    return MvGParameters(float(x[0]), float(x[1]), float(x[2]), float(x[3]), float(x[4]), cfg.fixed_l, cfg.fixed_h_entry)


def residual_vector(x: Sequence[float], observations: Sequence[Observation], cfg: FitConfig) -> np.ndarray:
    p = _decode(x, cfg)
    heads = np.asarray([o.head_cm for o in observations], dtype=float)
    theta, kval = evaluate(heads, p, cfg.semantics)
    residuals = []
    for i, obs in enumerate(observations):
        obs.validate(cfg.log_k)
        sigma = obs.sigma if obs.sigma is not None else 1.0
        if obs.family == "theta":
            r = (theta[i] - obs.value) / sigma / cfg.theta_scale
        else:
            if cfg.log_k:
                if kval[i] <= 0.0:
                    return np.full(len(observations), 1e30)
                r = (np.log(kval[i]) - np.log(obs.value)) / sigma / cfg.k_scale
            else:
                r = (kval[i] - obs.value) / sigma / cfg.k_scale
        residuals.append(r)
    return np.asarray(residuals)


def multistart_fit(observations: Sequence[Observation], initials: Iterable[MvGParameters], cfg: FitConfig) -> tuple[FitResult, list[FitResult]]:
    results = [fit(observations, initial, cfg) for initial in initials]
    if not results:
        raise ValueError("at least one initial parameter set required")
    successful = [r for r in results if r.success and np.isfinite(r.objective)]
    pool = successful if successful else results
    best = min(pool, key=lambda r: r.objective)
    return best, results


def fit(observations: Sequence[Observation], initial: MvGParameters, cfg: FitConfig) -> FitResult:
    if least_squares is None:
        raise RuntimeError("scipy is required for fitting")
    cfg.validate()
    initial.validate()
    if not observations:
        raise ValueError("at least one observation required")
    x0 = np.asarray((initial.theta_r, initial.theta_s, initial.alpha, initial.n, initial.Ks))
    result = least_squares(
        residual_vector, x0, args=(observations, cfg), bounds=(cfg.lower, cfg.upper),
        method="trf", jac="3-point", x_scale="jac"
    )
    s = np.linalg.svd(result.jac, compute_uv=False)
    cond = np.inf if len(s) == 0 or s[-1] == 0.0 else float(s[0] / s[-1])
    return FitResult(
        parameters=_decode(result.x, cfg),
        objective=float(np.dot(result.fun, result.fun)),
        residuals=np.asarray(result.fun),
        jacobian=np.asarray(result.jac),
        singular_values=s,
        condition_number=cond,
        active_mask=np.asarray(result.active_mask),
        success=bool(result.success),
        message=str(result.message),
        nfev=int(result.nfev),
    )
