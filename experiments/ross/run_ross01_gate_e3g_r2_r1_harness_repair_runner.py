from __future__ import annotations

import run_ross01_gate_e3g_r2_finite_time_ponding_event_localization as gate

# Harness-only repair for the first R2 execution. The frozen scientific script
# calls e3g.N_CELLS in its final whole-interval balance helper, while the
# already authoritative cell count lives in e3g.e3.N_CELLS. Expose only that
# existing constant through the missing namespace. No scientific function,
# fixture, threshold, solver policy, event equation or candidate/reference
# implementation is changed.
gate.e3g.N_CELLS = gate.e3g.e3.N_CELLS


if __name__ == "__main__":
    gate.main()
