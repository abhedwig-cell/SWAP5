from __future__ import annotations

from dataclasses import dataclass
import json
import math
import random

from run_lmfp02_testbench import MFPTable, make_fixture_material


class ExtendedMFPTable(MFPTable):
    """F-LMFP03 test-table wrapper.

    The inherited table remains shared and immutable. This wrapper only gives the
    scalar face prototype a defined extrapolation at h >= 0 and below the dry
    table edge. The eventual production table envelope is not selected here.
    """

    def value(self, h):
        if h >= 0.0:
            return self.phi0 + self.mat.conductivity(0.0) * h
        if h <= self.heads[0]:
            return self.phi[0] + self.mat.conductivity(self.heads[0]) * (h - self.heads[0])
        return super().value(h)


def secant_conductivity(tab, h1, h2):
    scale = max(1.0, abs(h1), abs(h2))
    if abs(h1 - h2) <= 1.0e-10 * scale:
        return tab.mat.conductivity(0.5 * (h1 + h2))
    return (tab.value(h1) - tab.value(h2)) / (h1 - h2)


def half_darcy_flux(tab, h_up, h_down, distance):
    """Downward-positive finite-volume Darcy flux over one material segment.

    q = K_sec + (Phi_up - Phi_down)/distance
      = K_sec * (1 - (h_down-h_up)/distance)

    This differs materially from the historical WOFOST max(dry, wet) rule.
    """
    ksec = secant_conductivity(tab, h_up, h_down)
    return ksec + (tab.value(h_up) - tab.value(h_down)) / distance


def homogeneous_face_flux(tab, h_upper, h_lower, distance):
    return half_darcy_flux(tab, h_upper, h_lower, distance)


def heterogeneous_face_flux(tab_u, tab_l, h_upper, h_lower, len_u, len_l,
                            tolerance=1.0e-10, max_iterations=60):
    """Solve a continuous interface head with equal full Darcy flux in both halves."""

    def residual(h_interface):
        q_u = half_darcy_flux(tab_u, h_upper, h_interface, len_u)
        q_l = half_darcy_flux(tab_l, h_interface, h_lower, len_l)
        return q_u - q_l, q_u, q_l

    span = max(len_u + len_l, abs(h_lower - h_upper), 1.0)
    lo = min(h_upper, h_lower) - span
    hi = max(h_upper, h_lower) + span
    f_lo, _, _ = residual(lo)
    f_hi, _, _ = residual(hi)

    expansions = 0
    while f_lo * f_hi > 0.0 and expansions < 20:
        span *= 2.0
        lo = min(h_upper, h_lower) - span
        hi = max(h_upper, h_lower) + span
        f_lo, _, _ = residual(lo)
        f_hi, _, _ = residual(hi)
        expansions += 1

    if f_lo * f_hi > 0.0:
        raise RuntimeError("heterogeneous full-flux interface could not be bracketed")

    for iteration in range(1, max_iterations + 1):
        mid = 0.5 * (lo + hi)
        f_mid, q_u, q_l = residual(mid)
        scale = max(1.0, abs(q_u), abs(q_l))
        if abs(f_mid) <= tolerance * scale:
            return 0.5 * (q_u + q_l), mid, iteration, q_u - q_l
        if f_lo * f_mid <= 0.0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid

    mid = 0.5 * (lo + hi)
    f_mid, q_u, q_l = residual(mid)
    return 0.5 * (q_u + q_l), mid, max_iterations, q_u - q_l


@dataclass
class TrialResult:
    accepted: bool
    candidate_storage: list
    pressure_head: list
    face_flux: list
    storage_rate: list
    mass_residual: float
    advised_step_duration: float | None
    max_face_iterations: int
    reason: str


def advance_trial(base_storage, materials, mfp_tables, thickness, step_duration,
                  top_flux, source=None, sink=None):
    """Standalone functional trial. The caller owns commit or retry."""
    n = len(base_storage)
    source = [0.0] * n if source is None else list(source)
    sink = [0.0] * n if sink is None else list(sink)

    if not (len(materials) == len(mfp_tables) == len(thickness) == len(source) == len(sink) == n):
        raise ValueError("column shape mismatch")
    if step_duration <= 0.0:
        raise ValueError("step_duration must be positive")

    heads = []
    for i in range(n):
        theta = base_storage[i] / thickness[i]
        if theta < materials[i].theta_r - 1.0e-10 or theta > materials[i].theta_s + 1.0e-10:
            return TrialResult(False, list(base_storage), [], [], [], 0.0, 0.0, 0,
                               "base_state_out_of_bounds")
        theta_eval = min(materials[i].theta_s, max(materials[i].theta_r + 1.0e-12, theta))
        heads.append(materials[i].head_from_theta(theta_eval))

    face = [0.0] * (n + 1)
    face[0] = top_flux
    max_face_iterations = 0

    for i in range(n - 1):
        len_u = 0.5 * thickness[i]
        len_l = 0.5 * thickness[i + 1]
        if materials[i] == materials[i + 1]:
            face[i + 1] = homogeneous_face_flux(mfp_tables[i], heads[i], heads[i + 1], len_u + len_l)
        else:
            q, _, iterations, _ = heterogeneous_face_flux(
                mfp_tables[i], mfp_tables[i + 1], heads[i], heads[i + 1], len_u, len_l)
            face[i + 1] = q
            max_face_iterations = max(max_face_iterations, iterations)

    # Unit-gradient free drainage. No field-capacity gate is imported from WOFOST.
    face[-1] = materials[-1].conductivity(heads[-1])

    rate = [face[i] - face[i + 1] + source[i] - sink[i] for i in range(n)]
    candidate = [base_storage[i] + step_duration * rate[i] for i in range(n)]

    expected_change = step_duration * (face[0] - face[-1] + sum(source) - sum(sink))
    actual_change = sum(candidate) - sum(base_storage)
    mass_residual = actual_change - expected_change

    admissible = math.inf
    violated = []
    for i in range(n):
        lower = (materials[i].theta_r + 1.0e-10) * thickness[i]
        upper = (materials[i].theta_s - 1.0e-10) * thickness[i]
        if rate[i] > 0.0:
            admissible = min(admissible, max(0.0, (upper - base_storage[i]) / rate[i]))
        elif rate[i] < 0.0:
            admissible = min(admissible, max(0.0, (base_storage[i] - lower) / (-rate[i])))
        if candidate[i] < lower - 1.0e-12 or candidate[i] > upper + 1.0e-12:
            violated.append(i)

    advised = 0.95 * admissible if math.isfinite(admissible) else None
    if violated:
        # Rejected trials return the unchanged base state. No post-update clipping.
        return TrialResult(False, list(base_storage), heads, face, rate, mass_residual, advised,
                           max_face_iterations, "storage_bounds:" + str(violated))

    return TrialResult(True, candidate, heads, face, rate, mass_residual, advised,
                       max_face_iterations, "accepted")


def integrate(base_storage, materials, tables, thickness, duration, steps,
              top_flux_function, source_function=None, sink_function=None):
    state = list(base_storage)
    dt = duration / steps
    max_mass = 0.0
    max_iterations = 0
    for k in range(steps):
        # Midpoint forcing isolates the first-order state-update behaviour better than
        # a left-end forcing sample. Forcing ownership remains outside the solver.
        t = (k + 0.5) * dt
        source = [0.0] * len(state) if source_function is None else source_function(t)
        sink = [0.0] * len(state) if sink_function is None else sink_function(t)
        trial = advance_trial(state, materials, tables, thickness, dt,
                              top_flux_function(t), source, sink)
        if not trial.accepted:
            raise RuntimeError((k, trial.reason, trial.advised_step_duration))
        state = trial.candidate_storage
        max_mass = max(max_mass, abs(trial.mass_residual))
        max_iterations = max(max_iterations, trial.max_face_iterations)
    return state, max_mass, max_iterations


def l1(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def run():
    m1 = make_fixture_material(1)
    m2 = make_fixture_material(2)
    t1 = ExtendedMFPTable(m1, n=1025, pf_max=8.0, pf_min=-4.0)
    t2 = ExtendedMFPTable(m2, n=1025, pf_max=8.0, pf_min=-4.0)
    evidence = {"tests": {}}

    q = homogeneous_face_flux(t1, -10.0, -10.0, 20.0)
    k = m1.conductivity(-10.0)
    evidence["tests"]["gravity_only_homogeneous"] = {
        "pass": abs(q - k) < 1.0e-12, "q": q, "K": k, "abs_error": abs(q - k)}

    hydro = []
    max_abs_q = 0.0
    for h_u, distance in [(-80.0, 20.0), (-50.0, 10.0), (-200.0, 75.0), (-5.0, 2.5)]:
        h_l = h_u + distance
        q = homogeneous_face_flux(t1, h_u, h_l, distance)
        hydro.append([h_u, h_l, distance, q])
        max_abs_q = max(max_abs_q, abs(q))
    evidence["tests"]["hydrostatic_homogeneous_zero_flux"] = {
        "pass": max_abs_q < 1.0e-10, "max_abs_q": max_abs_q, "cases": hydro}

    q, h_i, iterations, residual = heterogeneous_face_flux(t1, t2, -30.0, -5.0, 10.0, 15.0)
    evidence["tests"]["hydrostatic_heterogeneous_zero_flux"] = {
        "pass": abs(q) < 2.0e-10 and abs(h_i + 20.0) < 1.0e-6,
        "q": q, "interface_head": h_i, "expected_interface_head": -20.0,
        "iterations": iterations, "equal_flux_residual": residual}

    q, h_i, iterations, residual = heterogeneous_face_flux(t1, t2, -10.0, -10.0, 10.0, 15.0)
    evidence["tests"]["heterogeneous_gravity_equal_flux"] = {
        "pass": q > 0.0 and abs(residual) < 1.0e-8,
        "q": q, "interface_head": h_i, "iterations": iterations,
        "equal_flux_residual": residual}

    rng = random.Random(43103)
    face_iterations = []
    failures = 0
    max_residual = 0.0
    for _ in range(500):
        h_u = -10.0 ** rng.uniform(-1.0, 3.0)
        h_l = -10.0 ** rng.uniform(-1.0, 3.0)
        a, b = (t1, t2) if rng.random() < 0.5 else (t2, t1)
        try:
            _, _, iterations, residual = heterogeneous_face_flux(a, b, h_u, h_l, 10.0, 15.0)
            face_iterations.append(iterations)
            max_residual = max(max_residual, abs(residual))
        except RuntimeError:
            failures += 1
    evidence["tests"]["bounded_heterogeneous_face_matrix"] = {
        "pass": failures == 0 and max(face_iterations) <= 60,
        "cases": 500, "failures": failures, "max_iterations": max(face_iterations),
        "mean_iterations": sum(face_iterations) / len(face_iterations),
        "max_equal_flux_residual": max_residual}

    materials = [m1, m1, m2, m2]
    tables = [t1, t1, t2, t2]
    thickness = [15.0, 20.0, 25.0, 30.0]
    initial_heads = [-80.0, -50.0, -20.0, -10.0]
    storage = [m.theta(h) * dz for m, h, dz in zip(materials, initial_heads, thickness)]
    trial = advance_trial(storage, materials, tables, thickness, 0.05, 0.2,
                          [0.0] * 4, [0.01, 0.02, 0.01, 0.0])
    evidence["tests"]["accepted_column_mass_conservation"] = {
        "pass": trial.accepted and abs(trial.mass_residual) < 1.0e-12,
        "mass_residual": trial.mass_residual,
        "max_face_iterations": trial.max_face_iterations,
        "face_flux": trial.face_flux, "step_duration": 0.05}

    wet_heads = [-0.5, -5.0, -10.0, -10.0]
    wet_storage = [m.theta(h) * dz for m, h, dz in zip(materials, wet_heads, thickness)]
    rejected = advance_trial(wet_storage, materials, tables, thickness, 1.0, 50.0)
    retry = advance_trial(wet_storage, materials, tables, thickness,
                          rejected.advised_step_duration, 50.0)
    evidence["tests"]["reject_without_mutation_and_retry"] = {
        "pass": (not rejected.accepted) and rejected.candidate_storage == wet_storage and
                retry.accepted and abs(retry.mass_residual) < 1.0e-12,
        "rejected_reason": rejected.reason,
        "advised_step_duration": rejected.advised_step_duration,
        "retry_mass_residual": retry.mass_residual}

    rejected2 = advance_trial(wet_storage, materials, tables, thickness, 1.0, 50.0)
    evidence["tests"]["rejected_trial_repeatability"] = {
        "pass": rejected.reason == rejected2.reason and
                rejected.advised_step_duration == rejected2.advised_step_duration and
                rejected.face_flux == rejected2.face_flux,
        "same_reason": rejected.reason == rejected2.reason,
        "same_advised_step": rejected.advised_step_duration == rejected2.advised_step_duration,
        "same_faces": rejected.face_flux == rejected2.face_flux}

    top = lambda t: 0.3 + 0.05 * math.sin(2.0 * math.pi * t)
    sinks = lambda t: [0.01 + 0.003 * math.cos(2.0 * math.pi * t), 0.015, 0.01, 0.0]
    reference, _, _ = integrate(storage, materials, tables, thickness, 0.2, 2560, top,
                                sink_function=sinks)
    errors = {}
    max_mass = 0.0
    max_iterations = 0
    steps = [20, 40, 80, 160, 320]
    for count in steps:
        state, mass, iterations = integrate(storage, materials, tables, thickness, 0.2,
                                            count, top, sink_function=sinks)
        errors[count] = l1(state, reference)
        max_mass = max(max_mass, mass)
        max_iterations = max(max_iterations, iterations)
    ratios = {f"{n}_to_{2*n}": errors[n] / errors[2*n] for n in steps[:-1]}
    evidence["tests"]["generic_time_refinement"] = {
        "pass": all(ratio > 1.8 for ratio in ratios.values()),
        "l1_errors": errors, "reference_steps": 2560, "error_ratios": ratios,
        "max_mass_residual": max_mass, "max_face_iterations": max_iterations}

    evidence["interpretation"] = {
        "closure": "Candidate full Darcy MFP-secant closure; historical max(dry,wet) is not used.",
        "transaction": "advance_trial is functional. Rejected trials return the unchanged base storage.",
        "time": "No day unit occurs in the solver. step_duration is explicit and refinement shows first-order convergence in the smooth test.",
        "scope": "Standalone prototype only. This is not FullRichards physical qualification."
    }
    evidence["overall_pass"] = all(test["pass"] for test in evidence["tests"].values())
    return evidence


if __name__ == "__main__":
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["overall_pass"] else 1)
