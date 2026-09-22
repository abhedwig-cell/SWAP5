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


ATOL = 2.0e-12


def close(actual: float, expected: float, atol: float = ATOL) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(
            f"{actual:.17g} != {expected:.17g} (atol={atol:.3g})"
        )


def oracle(scale: float = 1.0, vertical_only: float | None = None):
    cv = 0.50 * scale if vertical_only is None else vertical_only
    cc = 0.25 * scale if vertical_only is None else 0.25
    return LinearRootZoneMemoryOracle(
        RootZoneMemoryParameters(
            root_storage_coefficient=0.20,
            lower_storage_coefficient=0.10,
            vertical_conductance_per_day=cv,
            interface_conductance_per_day=cc,
            root_reference_storage_m=0.100,
            root_reference_head_m=8.0,
            root_capacity_m=0.200,
        )
    )


def start() -> RootZoneMemoryState:
    return RootZoneMemoryState(root_storage_m=0.100, lower_head_m=8.0)


def run_two_blocks(
    model: LinearRootZoneMemoryOracle,
    first_forcing: RootZoneMemoryForcing,
    second_forcing: RootZoneMemoryForcing,
    first_head: float = 8.0,
    second_head: float = 8.0,
):
    r1 = model.solve_prescribed_interface(
        start(), first_forcing, first_head, 0.5
    )
    r2 = model.solve_prescribed_interface(
        r1.state, second_forcing, second_head, 0.5
    )
    return r1, r2


def test_forcing_order_frozen_targets_and_mass() -> None:
    model = oracle()
    wet = RootZoneMemoryForcing(root_input_rate_m_per_day=0.020)
    dry = RootZoneMemoryForcing()

    e1, e2 = run_two_blocks(model, wet, dry)
    l1, l2 = run_two_blocks(model, dry, wet)

    close(e2.root_head_m - 8.0, 0.023993153821211696)
    close(e2.state.lower_head_m - 8.0, 0.017491004024908014)
    close(e2.state.root_storage_m, 0.10479863076424234)
    close(e1.interface_exchange_m + e2.interface_exchange_m,
          0.003452268833266857)

    close(l2.root_head_m - 8.0, 0.03575296919951998)
    close(l2.state.lower_head_m - 8.0, 0.018400792708117814)
    close(l2.state.root_storage_m, 0.107150593839904)
    close(l1.interface_exchange_m + l2.interface_exchange_m,
          0.0010093268892842205)

    for part in (e1, e2, l1, l2):
        close(part.root_mass_error_m, 0.0)
        close(part.lower_mass_error_m, 0.0)
        close(part.swap_mass_error_m, 0.0)
        close(part.interface_exchange_route_error_m, 0.0)

    early_ec = e1.interface_exchange_m + e2.interface_exchange_m
    late_ec = l1.interface_exchange_m + l2.interface_exchange_m
    early_change = (
        e2.state.root_storage_m - start().root_storage_m
        + 0.10 * (e2.state.lower_head_m - start().lower_head_m)
    )
    late_change = (
        l2.state.root_storage_m - start().root_storage_m
        + 0.10 * (l2.state.lower_head_m - start().lower_head_m)
    )
    close(early_change, 0.010 - early_ec)
    close(late_change, 0.010 - late_ec)

    if abs(early_ec - late_ec) <= 1.0e-3:
        raise AssertionError("forcing-order memory was not resolved")


def _order_gap(scale: float) -> float:
    model = oracle(scale=scale)
    wet = RootZoneMemoryForcing(root_input_rate_m_per_day=0.020)
    dry = RootZoneMemoryForcing()
    e1, e2 = run_two_blocks(model, wet, dry)
    l1, l2 = run_two_blocks(model, dry, wet)
    return (
        e1.interface_exchange_m
        + e2.interface_exchange_m
        - l1.interface_exchange_m
        - l2.interface_exchange_m
    )


def test_order_sensitivity_intermediate_regime_signature() -> None:
    slow = _order_gap(0.01)
    middle = _order_gap(1.0)
    fast = _order_gap(100.0)

    close(slow, 1.5178280914223874e-6)
    close(middle, 0.0024429419439826365)
    close(fast, 0.00031999999999999737)

    if not (middle > slow and middle > fast):
        raise AssertionError("intermediate-timescale order signature absent")


def test_finite_window_response_sweep() -> None:
    model = oracle()
    targets = (
        (0.01, 0.0024695136748933825),
        (0.10, 0.022506009924084573),
        (0.25, 0.050498725157227996),
        (0.50, 0.0893824229988),
        (1.00, 0.14936530755182925),
        (2.00, 0.2229094014159862),
        (5.00, 0.289666796085119),
        (10.0, 0.29963723589847224),
    )
    previous = -1.0
    for dt, expected_u in targets:
        u = -model.response_tangent_m_per_m(dt)
        close(u, expected_u)
        if not (u > previous):
            raise AssertionError("selected u(T) sweep is not increasing")
        previous = u

    if not targets[0][1] < 0.003:
        raise AssertionError("short-window response gate not met")
    if not abs(targets[-1][1] - 0.30) < 0.001:
        raise AssertionError("long-window storage limit gate not met")


def test_boundary_head_order_and_mean_head_non_equivalence() -> None:
    model = oracle()
    zero = RootZoneMemoryForcing()

    low_high_1, low_high_2 = run_two_blocks(
        model, zero, zero, first_head=7.95, second_head=8.05
    )
    high_low_1, high_low_2 = run_two_blocks(
        model, zero, zero, first_head=8.05, second_head=7.95
    )
    whole = model.solve_prescribed_interface(start(), zero, 8.0, 1.0)

    low_high_ec = (
        low_high_1.interface_exchange_m + low_high_2.interface_exchange_m
    )
    high_low_ec = (
        high_low_1.interface_exchange_m + high_low_2.interface_exchange_m
    )

    close(low_high_2.root_head_m, 8.000568617927007)
    close(low_high_2.state.lower_head_m, 8.013562533368873)
    close(low_high_ec, -0.0014699769222886244)

    close(high_low_2.root_head_m, 7.999431382072994)
    close(high_low_2.state.lower_head_m, 7.986437466631127)
    close(high_low_ec, 0.0014699769222885038)

    close(whole.root_head_m, 8.0)
    close(whole.state.lower_head_m, 8.0)
    close(whole.interface_exchange_m, 0.0)

    if abs(low_high_ec - whole.interface_exchange_m) <= 1.0e-4:
        raise AssertionError("mean-head whole window falsely matched path")
    if abs(high_low_ec - whole.interface_exchange_m) <= 1.0e-4:
        raise AssertionError("mean-head whole window falsely matched path")


def test_path_preserving_partition_remains_exact() -> None:
    model = oracle()
    forcing = RootZoneMemoryForcing(root_input_rate_m_per_day=0.010)
    whole = model.solve_prescribed_interface(start(), forcing, 8.0, 1.0)

    state = start()
    exchange = 0.0
    for _ in range(10):
        result = model.solve_prescribed_interface(state, forcing, 8.0, 0.1)
        state = result.state
        exchange += result.interface_exchange_m

    close(state.root_storage_m, whole.state.root_storage_m, 4.0e-15)
    close(state.lower_head_m, whole.state.lower_head_m, 4.0e-15)
    close(exchange, whole.interface_exchange_m, 5.0e-15)


def test_fast_vertical_one_state_limit_and_discretization_distinction() -> None:
    model = oracle(vertical_only=500.0)
    finite_u = -model.response_tangent_m_per_m(1.0)
    continuous_u = 0.30 * (1.0 - math.exp(-0.25 / 0.30))
    implicit_euler_u = 0.30 * 0.25 / (0.30 + 0.25)

    close(finite_u, 0.16959639676987978)
    close(continuous_u, 0.16962053744787653)
    close(implicit_euler_u, 0.13636363636363635)

    if abs(finite_u - continuous_u) >= 3.0e-5:
        raise AssertionError("fast-vertical probe missed continuous one-state limit")
    if abs(continuous_u - implicit_euler_u) <= 0.03:
        raise AssertionError("continuous and implicit-Euler condensations conflated")


def test_equal_integrated_forcing_not_equal_state_but_equal_total_input() -> None:
    model = oracle()
    wet = RootZoneMemoryForcing(root_input_rate_m_per_day=0.020)
    dry = RootZoneMemoryForcing()
    e1, e2 = run_two_blocks(model, wet, dry)
    l1, l2 = run_two_blocks(model, dry, wet)

    close(
        sum(
            r.swap_external_input_m
            for r in (e1, e2)
        ),
        0.010,
    )
    close(
        sum(
            r.swap_external_input_m
            for r in (l1, l2)
        ),
        0.010,
    )
    if math.isclose(
        e2.state.root_storage_m,
        l2.state.root_storage_m,
        rel_tol=0.0,
        abs_tol=1.0e-5,
    ):
        raise AssertionError("equal integrated forcing erased root memory")
    if math.isclose(
        e2.state.lower_head_m,
        l2.state.lower_head_m,
        rel_tol=0.0,
        abs_tol=1.0e-5,
    ):
        raise AssertionError("equal integrated forcing erased lower-state memory")


def main() -> None:
    tests = [
        test_forcing_order_frozen_targets_and_mass,
        test_order_sensitivity_intermediate_regime_signature,
        test_finite_window_response_sweep,
        test_boundary_head_order_and_mean_head_non_equivalence,
        test_path_preserving_partition_remains_exact,
        test_fast_vertical_one_state_limit_and_discretization_distinction,
        test_equal_integrated_forcing_not_equal_state_but_equal_total_input,
    ]
    for test in tests:
        test()
        print(f"{test.__name__}=PASS")
    print(f"GC_RZM02_TESTS={len(tests)}/{len(tests)}")
    print("GC_RZM02_GATE=PASS")


if __name__ == "__main__":
    main()
