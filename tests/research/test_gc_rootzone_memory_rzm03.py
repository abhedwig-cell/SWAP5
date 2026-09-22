from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research" / "support"))

from gc_rootzone_memory import (
    LinearRootZoneMemoryOracle,
    RootZoneMemoryForcing,
    RootZoneMemoryParameters,
    RootZoneMemoryState,
)


MASS = 2.0e-12


def model() -> LinearRootZoneMemoryOracle:
    return LinearRootZoneMemoryOracle(
        RootZoneMemoryParameters(0.20, 0.10, 0.50, 0.25, 0.100, 8.0, 0.200)
    )


def close(x: float, y: float, tol: float = MASS) -> None:
    if not math.isclose(x, y, rel_tol=0.0, abs_tol=tol):
        raise AssertionError(f"{x:.17g} != {y:.17g}")


def assert_ledgers(r) -> None:
    close(r.root_mass_error_m, 0.0)
    close(r.lower_mass_error_m, 0.0)
    close(r.swap_mass_error_m, 0.0)
    close(r.interface_exchange_route_error_m, 0.0)


def test_downward_drainage_sign_and_mass() -> None:
    m = model()
    r = m.solve_prescribed_interface(
        RootZoneMemoryState(0.120, 8.0), RootZoneMemoryForcing(), 8.0, 0.5
    )
    if not (r.vertical_exchange_m > 0.0 and r.interface_exchange_m > 0.0):
        raise AssertionError("downward exchange sign contract failed")
    if not r.root_storage_change_m < 0.0:
        raise AssertionError("downward drainage did not deplete root storage")
    assert_ledgers(r)


def test_capillary_lower_to_root_sign_and_mass() -> None:
    m = model()
    r = m.solve_prescribed_interface(
        RootZoneMemoryState(0.080, 8.05), RootZoneMemoryForcing(), 8.05, 0.5
    )
    if not r.vertical_exchange_m < 0.0:
        raise AssertionError("capillary root supply did not use negative E_v")
    if not r.root_storage_change_m > 0.0:
        raise AssertionError("capillary supply did not increase root storage")
    assert_ledgers(r)


def test_modflow_to_swap_negative_interface_exchange() -> None:
    m = model()
    r = m.solve_prescribed_interface(
        RootZoneMemoryState(0.100, 8.0), RootZoneMemoryForcing(), 8.10, 0.5
    )
    if not r.interface_exchange_m < 0.0:
        raise AssertionError("MODFLOW-to-SWAP supply did not use negative E_c")
    if not r.swap_total_storage_change_m > 0.0:
        raise AssertionError("negative E_c did not increase SWAP inventory")
    close(r.swap_total_storage_change_m, -r.interface_exchange_m)
    assert_ledgers(r)


def test_zero_gradient_exact_stationary_control() -> None:
    m = model()
    r = m.solve_prescribed_interface(
        RootZoneMemoryState(0.100, 8.0), RootZoneMemoryForcing(), 8.0, 2.0
    )
    close(r.vertical_exchange_m, 0.0, 2.0e-15)
    close(r.interface_exchange_m, 0.0, 2.0e-15)
    close(r.root_storage_change_m, 0.0, 2.0e-15)
    close(r.lower_storage_change_m, 0.0, 2.0e-15)
    assert_ledgers(r)


def test_same_law_approaches_equilibrium_from_both_sides() -> None:
    m = model()
    down0 = RootZoneMemoryState(0.120, 8.0)
    up0 = RootZoneMemoryState(0.080, 8.0)
    down = m.solve_prescribed_interface(down0, RootZoneMemoryForcing(), 8.0, 5.0)
    up = m.solve_prescribed_interface(up0, RootZoneMemoryForcing(), 8.0, 5.0)
    down_gap0 = m.parameters.root_head_m(down0.root_storage_m) - down0.lower_head_m
    up_gap0 = m.parameters.root_head_m(up0.root_storage_m) - up0.lower_head_m
    down_gap1 = down.root_head_m - down.state.lower_head_m
    up_gap1 = up.root_head_m - up.state.lower_head_m
    if not (down_gap0 > 0.0 and down_gap1 > 0.0 and abs(down_gap1) < abs(down_gap0)):
        raise AssertionError("downward side did not approach equilibrium continuously")
    if not (up_gap0 < 0.0 and up_gap1 < 0.0 and abs(up_gap1) < abs(up_gap0)):
        raise AssertionError("upward side did not approach equilibrium continuously")
    if not (down.vertical_exchange_m > 0.0 and up.vertical_exchange_m < 0.0):
        raise AssertionError("same signed law did not preserve direction")
    assert_ledgers(down)
    assert_ledgers(up)


def test_coupled_groundwater_capillary_complete_ledger() -> None:
    m = model()
    c = m.solve_coupled_modflow_storage_window(
        RootZoneMemoryState(0.090, 7.95),
        RootZoneMemoryForcing(),
        dt_day=0.5,
        groundwater_head0_m=8.10,
        groundwater_storage_coefficient=0.20,
    )
    if not c.swap.interface_exchange_m < 0.0:
        raise AssertionError("coupled capillary exchange is not negative")
    if not c.swap.swap_total_storage_change_m > 0.0:
        raise AssertionError("coupled capillary supply did not wet SWAP")
    if not c.groundwater_storage_change_m < 0.0:
        raise AssertionError("coupled capillary supply did not deplete groundwater")
    close(c.swap.swap_total_storage_change_m + c.groundwater_storage_change_m, 0.0, 3e-12)
    close(c.groundwater_mass_error_m, 0.0, 3e-12)
    close(c.complete_mass_error_m, 0.0, 3e-12)


def test_sign_reversal_symmetry_about_equilibrium() -> None:
    m = model()
    plus = m.solve_prescribed_interface(
        RootZoneMemoryState(0.110, 8.0), RootZoneMemoryForcing(), 8.0, 0.25
    )
    minus = m.solve_prescribed_interface(
        RootZoneMemoryState(0.090, 8.0), RootZoneMemoryForcing(), 8.0, 0.25
    )
    close(plus.vertical_exchange_m, -minus.vertical_exchange_m, 3e-15)
    close(plus.interface_exchange_m, -minus.interface_exchange_m, 3e-15)
    close(plus.root_storage_change_m, -minus.root_storage_change_m, 3e-15)
    close(plus.lower_storage_change_m, -minus.lower_storage_change_m, 3e-15)


def main() -> None:
    tests = [
        test_downward_drainage_sign_and_mass,
        test_capillary_lower_to_root_sign_and_mass,
        test_modflow_to_swap_negative_interface_exchange,
        test_zero_gradient_exact_stationary_control,
        test_same_law_approaches_equilibrium_from_both_sides,
        test_coupled_groundwater_capillary_complete_ledger,
        test_sign_reversal_symmetry_about_equilibrium,
    ]
    for t in tests:
        t()
        print(f"{t.__name__}=PASS")
    print(f"GC_RZM03_TESTS={len(tests)}/{len(tests)}")
    print("GC_RZM03_GATE=PASS")


if __name__ == "__main__":
    main()
