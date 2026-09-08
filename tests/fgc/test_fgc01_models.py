#!/usr/bin/env python3
from decimal import Decimal as D
from fgc01_models import CommittedColumn, DeterministicAquifer, DeterministicSwapColumn


def main() -> None:
    committed = CommittedColumn(7, 0, D("1000.125"), D("2.0"), D("1.0"))
    swap = DeterministicSwapColumn(D("0.000001"))
    aquifer = DeterministicAquifer(D("0.5"), D("500000"))
    checkpoint = swap.checkpoint(committed)
    trial = swap.trial(checkpoint, D("0.75"), D("1000.625"))
    response = aquifer.respond(trial.interface_flux_m_per_s)
    assert trial.mass_residual_m == 0
    assert trial.interface_flux_m_per_s + response.interface_flux_m_per_s == 0
    assert committed.revision == 0 and committed.time == D("1000.125")
    assert aquifer.analytic_equilibrium_head(committed.internal_head_m, swap.conductance_per_s) == D("0")
    print("F-GC01_DUMMY_MODELS PASS")


if __name__ == "__main__":
    main()
