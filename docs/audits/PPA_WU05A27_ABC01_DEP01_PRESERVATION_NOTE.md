# PPA-WU05-A27 ABC01 preservation-runner note

Date: 2026-10-02. Status: TEST_INFRASTRUCTURE_DIAGNOSTIC.

DEP01 qualification run 36990865588 stopped before ABC01 because the historical
`tests/fpm/run_ppa_wu05a8_real_richards.sh` source assembly failed while compiling
`mod_macropore_single_column_runtime.f90` with a missing
`mod_fmr_macropore_top_input.mod`, despite compiling that source earlier in the same runner.

This is not treated as a standard-macropore physics or runtime regression. The same
current branch had already executed standard production arm B through the serialized
backend in ABC01 run 36990063203, completing 29 of 32 prospective cases. The DEP01
source mutation is restricted to an exact `fmr_b110_rfm_state_t` branch in
`state_matches_numerical_continuation_layout` and cannot enter B's state type.

For DEP01 the stale A8 runner is therefore removed from the owner gate rather than
modified opportunistically. Current backend O0/O2 compile, A26 live-preparer
preservation, and direct re-execution of ABC01 arm B on the repaired postimage provide
the relevant preservation surface. Repair of the historical A8 source assembly is
separate test-infrastructure debt.
