from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research" / "support"))

from gc_analytic_swap import (
    AffineStorage,
    AnalyticSwapColumn,
    AnalyticSwapForcing,
    AnalyticSwapState,
    LinearHeadSink,
    LinearMemory,
    shared_head_from_partition,
    solve_finite_resistance_pair,
)


def close(actual: float, expected: float, atol: float = 1.0e-12) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(f"{actual:.17g} != {expected:.17g}")


def test_original_bucket() -> None:
    model = AnalyticSwapColumn(storage=AffineStorage(0.20))
    result = model.solve_window(
        AnalyticSwapState(8.0),
        AnalyticSwapForcing(atmospheric_input_m=0.010),
        1.0,
    )
    close(result.state.head_m, 8.05)
    close(result.storage_change_m, 0.010)
    close(result.complete_mass_error_m, 0.0)


def test_storage_partition() -> None:
    for alpha in (0.0, 0.25, 0.5, 0.75, 1.0):
        head = shared_head_from_partition(
            initial_head_m=8.0,
            swap_storage=alpha * 0.20,
            groundwater_storage=(1.0 - alpha) * 0.20,
            total_external_input_m=0.010,
        )
        close(head, 8.05)


def test_depth_varying_storage() -> None:
    model = AnalyticSwapColumn(
        storage=AffineStorage(
            storage_at_reference=0.40,
            reference_head_m=0.0,
            storage_slope_per_m=-0.03,
        )
    )
    result = model.solve_window(
        AnalyticSwapState(8.0),
        AnalyticSwapForcing(atmospheric_input_m=0.010),
        1.0,
    )
    discriminant = 0.16 * 0.16 - 4.0 * 0.015 * 0.010
    expected = 8.0 + (
        0.16 - math.sqrt(discriminant)
    ) / (2.0 * 0.015)
    close(result.state.head_m, expected)
    close(result.storage_change_m, 0.010)
    close(result.complete_mass_error_m, 0.0)


def test_head_dependent_et() -> None:
    model = AnalyticSwapColumn(
        storage=AffineStorage(0.20),
        sinks=(LinearHeadSink("et", 8.02, 0.10),),
    )
    result = model.solve_window(
        AnalyticSwapState(8.0),
        AnalyticSwapForcing(atmospheric_input_m=0.020),
        1.0,
    )
    close(result.state.head_m, 8.073333333333332)
    close(result.sink_volume("et"), 0.005333333333333279)
    close(result.complete_mass_error_m, 0.0)


def test_drain() -> None:
    model = AnalyticSwapColumn(
        storage=AffineStorage(0.20),
        sinks=(LinearHeadSink("drain", 8.03, 0.20),),
    )
    result = model.solve_window(
        AnalyticSwapState(8.0),
        AnalyticSwapForcing(atmospheric_input_m=0.020),
        1.0,
    )
    close(result.state.head_m, 8.065)
    close(result.sink_volume("drain"), 0.007)
    close(result.complete_mass_error_m, 0.0)


def run_memory_history(inputs: tuple[float, float]) -> AnalyticSwapState:
    model = AnalyticSwapColumn(
        storage=AffineStorage(0.20),
        memory=LinearMemory(release_rate_per_day=1.0),
    )
    state = AnalyticSwapState(8.0, 0.0)
    for input_m in inputs:
        result = model.solve_window(
            state,
            AnalyticSwapForcing(memory_input_m=input_m),
            0.5,
        )
        close(result.complete_mass_error_m, 0.0)
        state = result.state
    return state


def test_memory_path_dependence() -> None:
    early = run_memory_history((0.020, 0.0))
    late = run_memory_history((0.0, 0.020))
    close(early.head_m, 8.055555555555555)
    close(early.memory_m, 0.008888888888888889)
    close(late.head_m, 8.033333333333333)
    close(late.memory_m, 0.013333333333333334)
    if not early.head_m > late.head_m:
        raise AssertionError("memory forcing order did not change final head")


def test_head_coupled_memory() -> None:
    model = AnalyticSwapColumn(
        storage=AffineStorage(0.20),
        memory=LinearMemory(
            release_rate_per_day=1.0,
            head_coupling_m_per_m=0.10,
            reference_head_m=8.0,
        ),
    )
    dry = model.solve_window(
        AnalyticSwapState(8.0, 0.0),
        AnalyticSwapForcing(),
        1.0,
    )
    wet = model.solve_window(
        AnalyticSwapState(8.0, 0.020),
        AnalyticSwapForcing(),
        1.0,
    )
    close(dry.state.head_m, 8.0)
    close(wet.state.head_m, 8.04)
    close(wet.state.memory_m, 0.012)
    close(wet.memory_transfer_to_groundwater_m, 0.008)
    close(wet.complete_mass_error_m, 0.0)


def test_manufactured_multiwindow_composition() -> None:
    model = AnalyticSwapColumn(
        storage=AffineStorage(0.20),
        memory=LinearMemory(release_rate_per_day=0.8),
        sinks=(
            LinearHeadSink("et", -1.0e30, 0.0),
            LinearHeadSink("drain", 8.0, 0.03),
        ),
    )
    # DSW20 uses a constant ET rate rather than a head-dependent ET law.
    # Represent it as an equivalent negative atmospheric contribution so
    # the same complete external ledger remains explicit.
    et_rate_m_per_day = 0.001
    windows = (
        (0.25, 0.004, 0.001),
        (0.50, 0.000, 0.002),
        (0.75, 0.006, 0.000),
        (0.40, 0.001, 0.0015),
        (0.60, 0.003, 0.000),
    )
    state = AnalyticSwapState(8.02, 0.005)
    initial_total = 0.20 * (state.head_m - 8.0) + state.memory_m
    cumulative_external = 0.0

    for dt, memory_input, lateral in windows:
        result = model.solve_window(
            state,
            AnalyticSwapForcing(
                atmospheric_input_m=-et_rate_m_per_day * dt,
                lateral_groundwater_input_m=lateral,
                memory_input_m=memory_input,
            ),
            dt,
        )
        drain = result.sink_volume("drain")
        external_net = memory_input + lateral - et_rate_m_per_day * dt - drain
        cumulative_external += external_net
        current_total = (
            0.20 * (result.state.head_m - 8.0) + result.state.memory_m
        )
        close(result.complete_mass_error_m, 0.0)
        close(current_total - initial_total, cumulative_external)
        state = result.state

    close(state.head_m, 8.072723405817783, 1.0e-12)
    close(state.memory_m, 0.00617230460980461, 1.0e-12)


def test_finite_resistance_q_link() -> None:
    result = solve_finite_resistance_pair(
        swap_head0_m=8.0,
        groundwater_head0_m=8.0,
        swap_storage=0.10,
        groundwater_storage=0.10,
        swap_external_input_m=0.010,
        groundwater_external_input_m=0.0,
        conductance_per_day=0.10,
        dt_day=1.0,
    )
    close(result.swap_head_m, 8.066666666666666)
    close(result.groundwater_head_m, 8.033333333333333)
    close(result.exchange_swap_to_groundwater_m, 0.003333333333333333)
    close(result.complete_mass_error_m, 0.0)


def main() -> None:
    test_original_bucket()
    test_storage_partition()
    test_depth_varying_storage()
    test_head_dependent_et()
    test_drain()
    test_memory_path_dependence()
    test_head_coupled_memory()
    test_manufactured_multiwindow_composition()
    test_finite_resistance_q_link()

    print("GC_ANALYTIC_SWAP_ORIGINAL_BUCKET=PASS")
    print("GC_ANALYTIC_SWAP_STORAGE_PARTITION=PASS")
    print("GC_ANALYTIC_SWAP_DEPTH_STORAGE=PASS")
    print("GC_ANALYTIC_SWAP_ET=PASS")
    print("GC_ANALYTIC_SWAP_DRAIN=PASS")
    print("GC_ANALYTIC_SWAP_MEMORY=PASS")
    print("GC_ANALYTIC_SWAP_HEAD_COUPLED_MEMORY=PASS")
    print("GC_ANALYTIC_SWAP_MULTWINDOW_COMPOSITION=PASS")
    print("GC_ANALYTIC_SWAP_QLINK=PASS")
    print("GC_ANALYTIC_SWAP_COMPONENT_GATE=PASS")


if __name__ == "__main__":
    main()
