from __future__ import annotations

import math

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as gate


def safe_interpolate_reference(ref, candidate):
    """Reporting-only repair after first E3 run exposed an incomplete reference trajectory.

    Scientific forcing, timesteps, face policies and thresholds remain frozen. Missing
    reference timestamps now produce +inf comparison metrics so the existing
    solver_complete/hydrology gate reports a scientific or qualification-solver failure
    instead of raising KeyError before evidence is written.
    """
    ref_map = {round(float(t), 15): tuple(h) for t, h in ref["history"]}
    max_head = 0.0
    max_storage = 0.0
    max_cell_storage = 0.0
    missing = False
    for t, heads in candidate["history"]:
        key = round(float(t), 15)
        rh = ref_map.get(key)
        if rh is None:
            missing = True
            continue
        max_head = max(max_head, max(abs(float(a) - float(b)) for a, b in zip(heads, rh)))
        cs = gate.storage_cells(heads)
        rs = gate.storage_cells(rh)
        max_storage = max(max_storage, abs(math.fsum(cs) - math.fsum(rs)))
        max_cell_storage = max(max_cell_storage, max(abs(a - b) for a, b in zip(cs, rs)))
    if missing:
        return math.inf, math.inf, math.inf
    return max_head, max_storage, max_cell_storage


gate.interpolate_reference = safe_interpolate_reference

if __name__ == "__main__":
    gate.main()
