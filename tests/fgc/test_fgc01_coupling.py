#!/usr/bin/env python3
import json
from decimal import Decimal as D

from fgc01_coupler import aggregate_cell_flux, couple_window, diagnostics_dict, switch_transfer_mode
from fgc01_models import CommittedColumn, DeterministicAquifer, DeterministicSwapColumn


def fixture(t0: str = "1000.125"):
    return (
        CommittedColumn(101, 4, D(t0), D("3.0"), D("1.0")),
        DeterministicSwapColumn(D("0.000001")),
        DeterministicAquifer(D("0.5"), D("500000")),
    )


def expect_value_error(action) -> None:
    try:
        action()
    except ValueError:
        return
    raise AssertionError("expected fail-closed ValueError")


def main() -> None:
    gates = {}

    state, swap, groundwater = fixture()
    accepted = couple_window("GC01-G01", state, D("1000.625"), swap, groundwater, D("0.8"), D("1e-30"))
    assert accepted.diagnostics.accepted and accepted.committed.revision == 5
    gates["GC01-G01_single_column"] = "PASS"

    state, swap, groundwater = fixture()
    rejected = couple_window("GC01-G02", state, D("1000.625"), swap, groundwater, D("0.8"), D("0"), False)
    assert rejected.committed == state and rejected.diagnostics.rollback_count == 1
    gates["GC01-G02_rollback"] = "PASS"

    state, swap, groundwater = fixture()
    accepted = couple_window("GC01-G03", state, D("1000.625"), swap, groundwater, D("0.8"), D("1e-30"))
    assert len(swap.trial_origins) == 2 and swap.trial_origins[0] == swap.trial_origins[1]
    gates["GC01-G03_corrector_origin"] = "PASS"

    assert accepted.diagnostics.convergence_status == "CONVERGED" and D(accepted.diagnostics.head_residual_m) == 0
    gates["GC01-G04_head_residual"] = "PASS"

    assert D(accepted.diagnostics.flux_residual_m_per_s) == 0
    assert D(accepted.diagnostics.interface_mass_residual_m) == 0
    assert D(accepted.diagnostics.swap_mass_residual_m) == 0
    gates["GC01-G05_flux_conservation"] = "PASS_EXACT"

    intervals = [("1000.125", "1000.25"), ("1000.375", "1001.125"), ("1000.125", "1002.625")]
    for index, (t0, t1) in enumerate(intervals):
        state, swap, groundwater = fixture(t0)
        outcome = couple_window(f"GC01-G06-{index}", state, D(t1), swap, groundwater, D("0.8"), D("1e-30"))
        assert outcome.committed.time == D(t1)
    gates["GC01-G06_generic_window"] = "PASS_SUBDAILY_NON_MIDNIGHT_MULTIDAY"

    cell_flux = aggregate_cell_flux([("upland", D("0.25"), D("0.000004")), ("lowland", D("0.75"), D("-0.000002"))])
    assert cell_flux == D("-0.0000005")
    gates["GC01-G07_two_tiles"] = "PASS"

    expect_value_error(lambda: aggregate_cell_flux([("a", D("0.4"), D("1")), ("b", D("0.5"), D("2"))]))
    gates["GC01-G08_missing_fraction"] = "PASS_FAIL_CLOSED"

    assert switch_transfer_mode(D("0.125"), "TRANSFER_ZONE", "DIRECT", D("0.125")) == D("0.125")
    expect_value_error(lambda: switch_transfer_mode(D("0.125"), "TRANSFER_ZONE", "DIRECT", D("0.1")))
    gates["GC01-G09_deep_vadose_contract"] = "PASS_CONTINUITY_DOUBLE"

    print(json.dumps({"decision": "PASS", "gates": gates, "diagnostics": diagnostics_dict(accepted)}, sort_keys=True))


if __name__ == "__main__":
    main()
