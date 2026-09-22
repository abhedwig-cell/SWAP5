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


ATOL = 1.0e-12


def close(actual: float, expected: float, atol: float = ATOL) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(f"{actual:.17g} != {expected:.17g} (atol={atol})")


def canonical_oracle() -> LinearRootZoneMemoryOracle:
    return LinearRootZoneMemoryOracle(
        RootZoneMemoryParameters(
            root_storage_coefficient=0.20,
            lower_storage_coefficient=0.10,
            vertical_conductance_per_day=0.50,
            interface_conductance_per_day=0.25,
            root_reference_storage_m=0.100,
            root_reference_head_m=8.00,
            root_capacity_m=0.200,
        )
    )


def canonical_state() -> RootZoneMemoryState:
    return RootZoneMemoryState(root_storage_m=0.100, lower_head_m=8.0)


def canonical_forcing() -> RootZoneMemoryForcing:
    return RootZoneMemoryForcing(root_input_rate_m_per_day=0.010)


def test_eigenvalues_and_timescales() -> None:
    oracle = canonical_oracle()
    slow, fast = oracle.eigenvalues_per_day()
    tau_slow, tau_fast = oracle.time_constants_day()
    close(slow, -0.6698729810778064)
    close(fast, -9.330127018922193)
    close(tau_slow, 1.492820323027551, 2.0e-15)
    close(tau_fast, 0.1071796769724491, 2.0e-15)


def test_canonical_transient_and_ledgers() -> None:
    oracle = canonical_oracle()
    state0 = canonical_state()
    result = oracle.solve_prescribed_interface(
        state0, canonical_forcing(), interface_head_m=8.0, dt_day=1.0
    )
    close(result.root_head_m, 8.029873061510365)
    close(result.state.lower_head_m, 8.017945898366513)
    close(result.state.root_storage_m, 0.10597461230207317)
    close(result.vertical_exchange_m, 0.0040253876979268275)
    close(result.interface_exchange_m, 0.002230797861275541)
    close(result.root_storage_change_m, 0.005974612302073167)
    close(result.lower_storage_change_m, 0.0017945898366512909)
    close(result.swap_total_storage_change_m, 0.007769202138724458)
    close(result.interface_exchange_from_ledger_m, result.interface_exchange_m)
    close(result.root_mass_error_m, 0.0, 2.0e-15)
    close(result.lower_mass_error_m, 0.0, 2.0e-15)
    close(result.swap_mass_error_m, 0.0, 2.0e-15)
    close(result.interface_exchange_route_error_m, 0.0, 2.0e-15)
    if state0 != canonical_state():
        raise AssertionError("committed state mutated during trial")


def test_steady_state_and_zero_flux_limit() -> None:
    oracle = canonical_oracle()
    forcing = canonical_forcing()
    yr, yl = oracle.steady_offsets_m(forcing)
    close(yr, 0.06)
    close(yl, 0.04)
    steady = RootZoneMemoryState(
        root_storage_m=oracle.parameters.root_storage_m(8.06),
        lower_head_m=8.04,
    )
    result = oracle.solve_prescribed_interface(steady, forcing, 8.0, 1.0)
    close(result.root_head_m, 8.06)
    close(result.state.lower_head_m, 8.04)
    close(result.interface_exchange_m, 0.010)
    close(result.vertical_exchange_m, 0.010)
    close(result.swap_mass_error_m, 0.0, 2.0e-15)

    zero = oracle.solve_prescribed_interface(
        canonical_state(), RootZoneMemoryForcing(), 8.0, 3.0
    )
    close(zero.root_head_m, 8.0)
    close(zero.state.lower_head_m, 8.0)
    close(zero.interface_exchange_m, 0.0)
    close(zero.vertical_exchange_m, 0.0)


def test_exact_affine_interface_response() -> None:
    oracle = canonical_oracle()
    state0 = canonical_state()
    forcing = canonical_forcing()
    dt = 1.0
    tangent = oracle.response_tangent_m_per_m(dt)
    close(tangent, -0.14936530755182922)
    origin = oracle.solve_prescribed_interface(state0, forcing, 8.0, dt)
    for head in (7.90, 7.95, 8.05, 8.10):
        trial = oracle.solve_prescribed_interface(state0, forcing, head, dt)
        expected = origin.interface_exchange_m + tangent * (head - 8.0)
        close(trial.interface_exchange_m, expected, 2.0e-15)
    if state0 != canonical_state():
        raise AssertionError("response probing mutated committed state")


def test_exact_subpartition_and_restart_invariance() -> None:
    oracle = canonical_oracle()
    forcing = canonical_forcing()
    whole = oracle.solve_prescribed_interface(
        canonical_state(), forcing, 8.0, 1.0
    )

    state = canonical_state()
    ec = 0.0
    ev = 0.0
    for _ in range(4):
        part = oracle.solve_prescribed_interface(state, forcing, 8.0, 0.25)
        state = part.state
        ec += part.interface_exchange_m
        ev += part.vertical_exchange_m
    close(state.root_storage_m, whole.state.root_storage_m, 2.0e-15)
    close(state.lower_head_m, whole.state.lower_head_m, 2.0e-15)
    close(ec, whole.interface_exchange_m, 3.0e-15)
    close(ev, whole.vertical_exchange_m, 3.0e-15)

    first = oracle.solve_prescribed_interface(
        canonical_state(), forcing, 8.0, 0.4
    )
    restarted = oracle.solve_prescribed_interface(first.state, forcing, 8.0, 0.6)
    close(restarted.state.root_storage_m, whole.state.root_storage_m, 3.0e-15)
    close(restarted.state.lower_head_m, whole.state.lower_head_m, 3.0e-15)
    close(
        first.interface_exchange_m + restarted.interface_exchange_m,
        whole.interface_exchange_m,
        3.0e-15,
    )


def test_same_interface_head_different_root_memory() -> None:
    oracle = canonical_oracle()
    dry = oracle.solve_prescribed_interface(
        RootZoneMemoryState(0.090, 8.0),
        RootZoneMemoryForcing(),
        8.0,
        0.5,
    )
    wet = oracle.solve_prescribed_interface(
        RootZoneMemoryState(0.120, 8.0),
        RootZoneMemoryForcing(),
        8.0,
        0.5,
    )
    if math.isclose(
        dry.interface_exchange_m,
        wet.interface_exchange_m,
        rel_tol=0.0,
        abs_tol=1.0e-8,
    ):
        raise AssertionError("different root memory was invisible at same H_c")


def test_same_total_water_different_vertical_distribution() -> None:
    oracle = canonical_oracle()
    # +0.010 m root water and -0.010 m lower water keep total SWAP inventory
    # identical because S_l*(7.9-8.0) = -0.010 m.
    state_a = RootZoneMemoryState(0.100, 8.0)
    state_b = RootZoneMemoryState(0.110, 7.9)
    total_a = state_a.root_storage_m + 0.10 * state_a.lower_head_m
    total_b = state_b.root_storage_m + 0.10 * state_b.lower_head_m
    close(total_a, total_b)
    a = oracle.solve_prescribed_interface(
        state_a, RootZoneMemoryForcing(), 8.0, 0.5
    )
    b = oracle.solve_prescribed_interface(
        state_b, RootZoneMemoryForcing(), 8.0, 0.5
    )
    if math.isclose(
        a.interface_exchange_m,
        b.interface_exchange_m,
        rel_tol=0.0,
        abs_tol=1.0e-8,
    ):
        raise AssertionError("vertical distribution memory was invisible")


def test_delayed_upper_forcing_and_delayed_bottom_signal() -> None:
    oracle = canonical_oracle()
    state0 = canonical_state()

    early = oracle.solve_prescribed_interface(
        state0,
        RootZoneMemoryForcing(root_input_rate_m_per_day=0.020),
        8.0,
        0.1,
    )
    # Only part of 0.002 m root input can reach the lower interface immediately.
    if not (0.0 < early.interface_exchange_m < 0.002):
        raise AssertionError("upper forcing did not show delayed interface response")

    raised_bottom = oracle.solve_prescribed_interface(
        state0, RootZoneMemoryForcing(), 8.10, 0.1
    )
    lower_rise = raised_bottom.state.lower_head_m - state0.lower_head_m
    root_rise = raised_bottom.root_head_m - oracle.parameters.root_head_m(
        state0.root_storage_m
    )
    if not (lower_rise > root_rise > 0.0):
        raise AssertionError("bottom-head signal did not propagate lower-to-root")


def test_timescale_separation_limits() -> None:
    slow = LinearRootZoneMemoryOracle(
        RootZoneMemoryParameters(
            0.20, 0.10, 0.005, 0.0025, 0.100, 8.0, 0.200
        )
    )
    fast = LinearRootZoneMemoryOracle(
        RootZoneMemoryParameters(
            0.20, 0.10, 5.0, 2.5, 0.100, 8.0, 0.200
        )
    )
    state = RootZoneMemoryState(0.120, 8.0)
    forcing = RootZoneMemoryForcing()
    rs = slow.solve_prescribed_interface(state, forcing, 8.0, 1.0)
    rf = fast.solve_prescribed_interface(state, forcing, 8.0, 1.0)
    initial_root_excess = 0.020
    retained_slow = rs.state.root_storage_m - 0.100
    retained_fast = rf.state.root_storage_m - 0.100
    if not (retained_slow > 0.95 * initial_root_excess):
        raise AssertionError("slow system released too much root memory")
    if not (retained_fast < 0.25 * initial_root_excess):
        raise AssertionError("fast system did not equilibrate root memory")
    if not (rf.interface_exchange_m > rs.interface_exchange_m):
        raise AssertionError("timescale separation did not affect interface visibility")


def test_coupled_modflow_scalar_response_and_complete_mass() -> None:
    oracle = canonical_oracle()
    coupled = oracle.solve_coupled_modflow_storage_window(
        canonical_state(),
        canonical_forcing(),
        dt_day=1.0,
        groundwater_head0_m=8.0,
        groundwater_storage_coefficient=0.20,
        groundwater_external_input_m=0.0,
        response_origin_head_m=8.0,
    )
    close(coupled.groundwater_mass_error_m, 0.0, 3.0e-15)
    close(coupled.complete_mass_error_m, 0.0, 3.0e-15)
    # Reanchoring the exact affine response must give the identical physical root.
    shifted = oracle.solve_coupled_modflow_storage_window(
        canonical_state(),
        canonical_forcing(),
        dt_day=1.0,
        groundwater_head0_m=8.0,
        groundwater_storage_coefficient=0.20,
        groundwater_external_input_m=0.0,
        response_origin_head_m=8.07,
    )
    close(shifted.interface_head_m, coupled.interface_head_m, 3.0e-15)
    close(
        shifted.swap.interface_exchange_m,
        coupled.swap.interface_exchange_m,
        3.0e-15,
    )


def test_negative_controls_are_detected() -> None:
    oracle = canonical_oracle()
    result = oracle.solve_prescribed_interface(
        canonical_state(), canonical_forcing(), 8.0, 1.0
    )
    # Negative control 1: book lower storage twice in the SWAP inventory.
    duplicate_storage_error = (
        result.swap_total_storage_change_m
        + result.lower_storage_change_m
        - (result.swap_external_input_m - result.interface_exchange_m)
    )
    if abs(duplicate_storage_error) <= 1.0e-6:
        raise AssertionError("duplicate-storage negative control escaped mass gate")

    # Negative control 2: use the same sign for interface exchange on MODFLOW.
    sm = 0.20
    h0 = 8.0
    correct = oracle.solve_coupled_modflow_storage_window(
        canonical_state(),
        canonical_forcing(),
        1.0,
        groundwater_head0_m=h0,
        groundwater_storage_coefficient=sm,
    )
    wrong_groundwater_ledger_error = correct.groundwater_storage_change_m - (
        -correct.swap.interface_exchange_m
    )
    if abs(wrong_groundwater_ledger_error) <= 1.0e-6:
        raise AssertionError("reversed-interface-sign control escaped physical gate")


def test_capacity_fail_closed() -> None:
    oracle = canonical_oracle()
    try:
        oracle.solve_prescribed_interface(
            RootZoneMemoryState(0.199, 8.0),
            RootZoneMemoryForcing(root_input_rate_m_per_day=0.20),
            8.0,
            1.0,
        )
    except ValueError as exc:
        if "capacity" not in str(exc):
            raise
    else:
        raise AssertionError("capacity-crossing trial did not fail closed")


def main() -> None:
    tests = [
        test_eigenvalues_and_timescales,
        test_canonical_transient_and_ledgers,
        test_steady_state_and_zero_flux_limit,
        test_exact_affine_interface_response,
        test_exact_subpartition_and_restart_invariance,
        test_same_interface_head_different_root_memory,
        test_same_total_water_different_vertical_distribution,
        test_delayed_upper_forcing_and_delayed_bottom_signal,
        test_timescale_separation_limits,
        test_coupled_modflow_scalar_response_and_complete_mass,
        test_negative_controls_are_detected,
        test_capacity_fail_closed,
    ]
    for test in tests:
        test()
        print(f"{test.__name__}=PASS")
    print(f"GC_RZM01_TESTS={len(tests)}/{len(tests)}")
    print("GC_RZM01_GATE=PASS")


if __name__ == "__main__":
    main()
