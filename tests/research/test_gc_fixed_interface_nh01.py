from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class FixedInterfaceResult:
    phreatic_head_m: float
    interface_head_m: float
    interface_transfer_to_groundwater_m: float
    top_storage_change_m: float
    groundwater_storage_change_m: float
    complete_mass_error_m: float


def solve_fixed_interface(
    *,
    phreatic_head0_m: float,
    interface_head0_m: float,
    top_storage: float,
    groundwater_storage: float,
    top_external_input_m: float,
    groundwater_external_input_m: float,
    vertical_conductance_per_day: float,
    dt_day: float,
) -> FixedInterfaceResult:
    """Exact two-inventory reduction with one fixed geometric interface head.

    The vertical conductance is internal to the top-system representation:
    it relates its phreatic state to hydraulic head at the lower coupling
    plane. The interface head itself is a single state shared with the
    groundwater equation. Positive transfer is from top system to groundwater.
    """
    cdt = vertical_conductance_per_day * dt_day
    a11 = top_storage + cdt
    a12 = -cdt
    a21 = -cdt
    a22 = groundwater_storage + cdt
    b1 = top_storage * phreatic_head0_m + top_external_input_m
    b2 = groundwater_storage * interface_head0_m + groundwater_external_input_m
    det = a11 * a22 - a12 * a21
    if det <= 0.0:
        raise ValueError("singular fixed-interface balance")

    zp = (b1 * a22 - a12 * b2) / det
    hc = (a11 * b2 - b1 * a21) / det
    transfer = cdt * (zp - hc)
    ds = top_storage * (zp - phreatic_head0_m)
    dm = groundwater_storage * (hc - interface_head0_m)
    error = ds + dm - top_external_input_m - groundwater_external_input_m
    return FixedInterfaceResult(zp, hc, transfer, ds, dm, error)


def close(a: float, b: float, tol: float = 1e-12) -> None:
    assert math.isclose(a, b, rel_tol=0.0, abs_tol=tol), (a, b)


def test_nh01_preregistered_nonhydrostatic_oracle() -> None:
    r = solve_fixed_interface(
        phreatic_head0_m=8.0,
        interface_head0_m=8.0,
        top_storage=0.10,
        groundwater_storage=0.10,
        top_external_input_m=0.010,
        groundwater_external_input_m=0.0,
        vertical_conductance_per_day=0.20,
        dt_day=1.0,
    )
    close(r.phreatic_head_m, 8.06)
    close(r.interface_head_m, 8.04)
    close(r.phreatic_head_m-r.interface_head_m, 0.02)
    close(r.interface_transfer_to_groundwater_m, 0.004)
    close(r.top_storage_change_m, 0.006)
    close(r.groundwater_storage_change_m, 0.004)
    close(r.complete_mass_error_m, 0.0)


def test_nh01_component_interface_ledgers_cancel() -> None:
    r = solve_fixed_interface(
        phreatic_head0_m=8.0, interface_head0_m=8.0,
        top_storage=0.10, groundwater_storage=0.10,
        top_external_input_m=0.010, groundwater_external_input_m=0.0,
        vertical_conductance_per_day=0.20, dt_day=1.0,
    )
    close(r.top_storage_change_m, 0.010-r.interface_transfer_to_groundwater_m)
    close(r.groundwater_storage_change_m, r.interface_transfer_to_groundwater_m)


def test_nh01_hydrostatic_limit_preserves_total_storage() -> None:
    for c in (2.0, 20.0, 200.0, 2000.0):
        r = solve_fixed_interface(
            phreatic_head0_m=8.0, interface_head0_m=8.0,
            top_storage=0.10, groundwater_storage=0.10,
            top_external_input_m=0.010, groundwater_external_input_m=0.0,
            vertical_conductance_per_day=c, dt_day=1.0,
        )
        close(r.top_storage_change_m+r.groundwater_storage_change_m, 0.010)
    r = solve_fixed_interface(
        phreatic_head0_m=8.0, interface_head0_m=8.0,
        top_storage=0.10, groundwater_storage=0.10,
        top_external_input_m=0.010, groundwater_external_input_m=0.0,
        vertical_conductance_per_day=2000.0, dt_day=1.0,
    )
    assert abs(r.phreatic_head_m-r.interface_head_m) < 3e-6
    close((r.phreatic_head_m+r.interface_head_m)/2.0, 8.05, 3e-6)


if __name__ == "__main__":
    test_nh01_preregistered_nonhydrostatic_oracle()
    test_nh01_component_interface_ledgers_cancel()
    test_nh01_hydrostatic_limit_preserves_total_storage()
    print("GC_FIXED_INTERFACE_NH01_ANALYTIC_ORACLE=PASS")
