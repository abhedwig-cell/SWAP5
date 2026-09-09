from __future__ import annotations

import copy
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

EPS = 2.220446049250313e-16
SLOT_CAPACITY = 8
COLUMN_LENGTH_CM = 100.0
BIN_COUNTS = (16, 64, 200)
DT_DAYS = (1.0e-6, 1.0e-5, 1.0e-4, 1.0e-3)
MATERIALS = ("B01", "B12", "O13", "O14")
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
CONTRACT = "F-FWC01_GATE_B2A_PHYSICAL_ADVECTIVE_FALLING_SLUG_MASS_PRECOMMIT.json"


@dataclass(frozen=True)
class Slug:
    bin_j: int
    z_top_cm: float
    z_bottom_cm: float


@dataclass
class State:
    slugs: list[Slug]
    bottom_outflow_cm: float = 0.0


class OverflowRequired(RuntimeError):
    pass


def mvg_k_of_theta(theta: float, row: dict) -> float:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    ks = float(row["ksatfit_cm_per_day"])
    n = float(row["n"])
    lam = float(row["lambda"])
    m = 1.0 - 1.0 / n
    if theta <= tr:
        return 0.0
    if theta >= ts:
        return ks
    s = (theta - tr) / (ts - tr)
    term = (1.0 - s ** (1.0 / m)) ** m
    return ks * s**lam * (1.0 - term) ** 2


def bin_properties(nbins: int, j: int, row: dict) -> tuple[float, float, float, float, float]:
    if not (1 <= j <= nbins):
        raise ValueError("invalid bin")
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    dtheta = (ts - tr) / nbins
    theta_prev = tr + (j - 1) * dtheta
    theta_j = tr + j * dtheta
    k_prev = mvg_k_of_theta(theta_prev, row)
    k_j = mvg_k_of_theta(theta_j, row)
    velocity = (k_j - k_prev) / dtheta
    return dtheta, theta_prev, theta_j, k_prev, k_j if math.isfinite(velocity) else math.nan


def velocity(nbins: int, j: int, row: dict) -> tuple[float, dict]:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    dtheta = (ts - tr) / nbins
    theta_prev = tr + (j - 1) * dtheta
    theta_j = tr + j * dtheta
    k_prev = mvg_k_of_theta(theta_prev, row)
    k_j = mvg_k_of_theta(theta_j, row)
    v = (k_j - k_prev) / dtheta
    if not (math.isfinite(v) and v >= 0.0):
        raise RuntimeError(("invalid_incremental_conductivity_velocity", nbins, j, v))
    return v, {
        "dtheta": dtheta,
        "theta_prev": theta_prev,
        "theta_j": theta_j,
        "k_prev": k_prev,
        "k_j": k_j,
        "incremental_identity_residual": v * dtheta - (k_j - k_prev),
    }


def in_domain_length(slug: Slug) -> float:
    lo = max(0.0, slug.z_top_cm)
    hi = min(COLUMN_LENGTH_CM, slug.z_bottom_cm)
    return max(0.0, hi - lo)


def storage_cm(state: State, nbins: int, row: dict) -> float:
    dtheta = (float(row["theta_s"]) - float(row["theta_r"])) / nbins
    return math.fsum(dtheta * in_domain_length(s) for s in state.slugs)


def pack_state(state: State) -> bytes:
    out = bytearray(struct.pack("<dI", state.bottom_outflow_cm, len(state.slugs)))
    for s in sorted(state.slugs, key=lambda x: (x.bin_j, x.z_top_cm, x.z_bottom_cm)):
        out.extend(struct.pack("<Idd", s.bin_j, s.z_top_cm, s.z_bottom_cm))
    return bytes(out)


def advance_trial(state: State, nbins: int, row: dict, dt_day: float) -> State:
    trial = copy.deepcopy(state)
    dtheta = (float(row["theta_s"]) - float(row["theta_r"])) / nbins
    advanced: list[Slug] = []
    for s in trial.slugs:
        v, _ = velocity(nbins, s.bin_j, row)
        before_len = in_domain_length(s)
        moved = Slug(s.bin_j, s.z_top_cm + v * dt_day, s.z_bottom_cm + v * dt_day)
        after_len = in_domain_length(moved)
        if after_len > before_len + 1.0e-12:
            raise RuntimeError("downward falling slug gained in-domain length")
        trial.bottom_outflow_cm += dtheta * (before_len - after_len)
        if after_len > 0.0:
            advanced.append(moved)
    trial.slugs = advanced
    return trial


def add_slug_trial(state: State, slug: Slug) -> State:
    trial = copy.deepcopy(state)
    count = sum(1 for s in trial.slugs if s.bin_j == slug.bin_j)
    if count >= SLOT_CAPACITY:
        raise OverflowRequired("FALLBACK_REQUIRED")
    trial.slugs.append(slug)
    return trial


def mass_residual(initial_storage: float, state: State, nbins: int, row: dict) -> float:
    return initial_storage - state.bottom_outflow_cm - storage_cm(state, nbins, row)


def mass_tol(initial_storage: float, state: State, nbins: int, row: dict) -> float:
    final = storage_cm(state, nbins, row)
    scale = max(1.0, abs(initial_storage) + abs(state.bottom_outflow_cm) + abs(final))
    return 64.0 * EPS * scale


def run_case(material: str, row: dict, nbins: int, dt_day: float) -> dict:
    selected = sorted(set((max(2, nbins // 2), max(2, 3 * nbins // 4), nbins)))
    velocity_rows = []
    identity_max = 0.0
    for j in selected:
        v, meta = velocity(nbins, j, row)
        identity_max = max(identity_max, abs(meta["incremental_identity_residual"]))
        velocity_rows.append({"bin_j": j, "velocity_cm_per_day": v, **meta})

    # Internal translation: all selected bins are kept well inside the column.
    internal = State([Slug(j, 10.0 + 3.0 * i, 12.0 + 3.0 * i) for i, j in enumerate(selected)])
    initial_internal = storage_cm(internal, nbins, row)
    before_lengths = [s.z_bottom_cm - s.z_top_cm for s in internal.slugs]
    internal_next = advance_trial(internal, nbins, row, dt_day)
    after_lengths = [s.z_bottom_cm - s.z_top_cm for s in internal_next.slugs]
    internal_length_error = max(abs(a - b) for a, b in zip(before_lengths, after_lengths)) if after_lengths else math.inf
    internal_residual = mass_residual(initial_internal, internal_next, nbins, row)

    # Boundary cases use the fastest selected bin so that the geometry is well resolved.
    j_fast = max(selected, key=lambda j: velocity(nbins, j, row)[0])
    v_fast, _ = velocity(nbins, j_fast, row)
    displacement = v_fast * dt_day
    if displacement <= 1.0e-12:
        raise RuntimeError(("boundary_displacement_too_small", material, nbins, dt_day, displacement))

    # Leading edge crosses bottom while trailing edge remains in domain.
    partial_len = max(4.0 * displacement, 1.0e-8)
    bottom0 = COLUMN_LENGTH_CM - 0.5 * displacement
    partial = State([Slug(j_fast, bottom0 - partial_len, bottom0)])
    partial_initial = storage_cm(partial, nbins, row)
    partial_next = advance_trial(partial, nbins, row, dt_day)
    partial_residual = mass_residual(partial_initial, partial_next, nbins, row)

    # Three-step physical exit geometry: internal -> partial -> fully outside.
    span = max(displacement, 1.0e-8)
    top0 = COLUMN_LENGTH_CM - 2.5 * displacement
    exit_state = State([Slug(j_fast, top0, top0 + span)])
    exit_initial = storage_cm(exit_state, nbins, row)
    exit_residuals = []
    for _ in range(4):
        exit_state = advance_trial(exit_state, nbins, row, dt_day)
        exit_residuals.append(mass_residual(exit_initial, exit_state, nbins, row))
    complete_exit = len(exit_state.slugs) == 0 and storage_cm(exit_state, nbins, row) == 0.0

    # A2 transaction semantics: the ninth slot is rejected before commit.
    overflow_state = State([Slug(j_fast, 20.0 + i, 20.25 + i) for i in range(SLOT_CAPACITY)])
    before_bytes = pack_state(overflow_state)
    before_ledger = overflow_state.bottom_outflow_cm
    overflow_triggered = False
    try:
        _ = add_slug_trial(overflow_state, Slug(j_fast, 40.0, 40.25))
    except OverflowRequired:
        overflow_triggered = True
    rejected_state_unchanged = pack_state(overflow_state) == before_bytes
    rejected_ledger_unchanged = overflow_state.bottom_outflow_cm == before_ledger

    max_abs_mass = max(
        abs(internal_residual), abs(partial_residual), *(abs(x) for x in exit_residuals)
    )
    tol = max(
        mass_tol(initial_internal, internal_next, nbins, row),
        mass_tol(partial_initial, partial_next, nbins, row),
        mass_tol(exit_initial, exit_state, nbins, row),
    )
    tests = {
        "incremental_velocity_identity": identity_max <= 1.0e-14 * max(1.0, float(row["ksatfit_cm_per_day"])),
        "internal_slug_length_preserved": internal_length_error <= 1.0e-12,
        "mass_roundoff": max_abs_mass <= tol,
        "partial_bottom_outflow_positive": partial_next.bottom_outflow_cm > 0.0,
        "complete_slug_exit": complete_exit,
        "overflow_triggered": overflow_triggered,
        "overflow_state_bitwise_unchanged": rejected_state_unchanged,
        "overflow_ledger_exactly_unchanged": rejected_ledger_unchanged,
    }
    return {
        "material": material,
        "theta_bins": nbins,
        "dt_day": dt_day,
        "selected_bins": selected,
        "velocities": velocity_rows,
        "incremental_velocity_identity_max_abs": identity_max,
        "internal_slug_length_error_cm": internal_length_error,
        "partial_bottom_outflow_cm": partial_next.bottom_outflow_cm,
        "exit_bottom_outflow_cm": exit_state.bottom_outflow_cm,
        "exit_initial_storage_cm": exit_initial,
        "complete_exit": complete_exit,
        "max_abs_mass_residual_cm": max_abs_mass,
        "mass_tolerance_cm": tol,
        "overflow_triggered": overflow_triggered,
        "overflow_diagnostic": "FALLBACK_REQUIRED" if overflow_triggered else "MISSING",
        "rejected_overflow_state_bitwise_unchanged": rejected_state_unchanged,
        "rejected_overflow_ledger_exactly_unchanged": rejected_ledger_unchanged,
        "tests": tests,
        "failed_metrics": [k for k, ok in tests.items() if not ok],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2a_physical_falling_slug_mass.py OUTPUT.json")
    output = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {row["sfu"]: row for row in catalog["rows"]}
    cases = []
    for material in MATERIALS:
        for nbins in BIN_COUNTS:
            for dt in DT_DAYS:
                case = run_case(material, by[material], nbins, dt)
                cases.append(case)
                print(json.dumps({
                    "material": material,
                    "theta_bins": nbins,
                    "dt_day": dt,
                    "pass": case["pass"],
                    "max_abs_mass_residual_cm": case["max_abs_mass_residual_cm"],
                    "failed_metrics": case["failed_metrics"],
                }, sort_keys=True), flush=True)

    passed = all(c["pass"] for c in cases)
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2A_PHYSICAL_ADVECTIVE_FALLING_SLUG_MASS",
        "contract": CONTRACT,
        "production_implementation": False,
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION_SOURCE_BOUND_EQ19",
        "case_count": len(cases),
        "case_pass_count": sum(c["pass"] for c in cases),
        "maximum_abs_mass_residual_cm": max(c["max_abs_mass_residual_cm"] for c in cases),
        "maximum_mass_tolerance_cm": max(c["mass_tolerance_cm"] for c in cases),
        "maximum_internal_slug_length_error_cm": max(c["internal_slug_length_error_cm"] for c in cases),
        "all_overflow_state_bitwise_unchanged": all(c["rejected_overflow_state_bitwise_unchanged"] for c in cases),
        "all_overflow_ledgers_exactly_unchanged": all(c["rejected_overflow_ledger_exactly_unchanged"] for c in cases),
        "mass_repair_applied": False,
        "numerical_clipping_repair_applied": False,
        "physical_boundary_truncation_ledgered_as_outflow": True,
        "pass": passed,
        "decision": (
            "QUALIFIED_PHYSICAL_ADVECTIVE_FALLING_SLUG_MASS_SUBGATE_READY_FOR_CAPILLARY_RELAXATION_AND_INFILTRATION_MASS_GATES"
            if passed else
            "ADVECTIVE_FALLING_SLUG_PHYSICAL_MASS_SUBGATE_FAILED"
        ),
        "hard_nonclaims": [
            "No full FWC physical-column qualification.",
            "No infiltration-front, groundwater-front or capillary-relaxation trajectory qualification.",
            "No explicit-diffusion equation reconstruction.",
            "No FullRichards hydraulic accuracy or MultiSWAP production admission."
        ],
        "cases": cases,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": result["pass"],
        "decision": result["decision"],
        "case_count": result["case_count"],
        "case_pass_count": result["case_pass_count"],
        "maximum_abs_mass_residual_cm": result["maximum_abs_mass_residual_cm"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
