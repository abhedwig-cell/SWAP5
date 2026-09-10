from __future__ import annotations

import run_ross01_gate_e3g_r2_finite_time_ponding_event_localization as gate

# Harness-only repair for the frozen R2 script. Its final whole-interval
# balance helper references N_CELLS, DZ and theta_of_h through the imported
# E3G module namespace, while those already authoritative definitions live in
# E3G's imported E3 module. Expose only those existing values/functions through
# the missing namespace. No scientific function, fixture, threshold, solver
# policy, event equation or candidate/reference implementation is changed.
gate.e3g.N_CELLS = gate.e3g.e3.N_CELLS
gate.e3g.DZ = gate.e3g.e3.DZ
gate.e3g.theta_of_h = gate.e3g.e3.theta_of_h


if __name__ == "__main__":
    gate.main()
