# Bounded native FCT and restart

The explicit generated native caller now executes original SWP hydraulic and
chemistry import with the FCT successor. Both201-provider O0/O2 builds pass
the complete constructed0.4day, four-window active-crop test on41/60node grids,
with Freundlich0.5/1/2 and TSCF0/1.24 cases execute96 native processes,
including24 CRC-valid wrong-policy rejection processes. Every fresh-process
restart reproduces the full binary state, endpoint, profile and continued
water/solute budget rows exactly. Native O0/O2 numerical outputs are equal.
Maximum water residual1.996e-14cm; solute1.678e-13mg/cm2. Executed native
matrix time62.155s O0 and32.492s O2; these are test costs, not speed claims.

144 process cases independently check local finite-volume equations, nonlinear
storage, varying density/sorption and signed interior/bottom donor fluxes.
The metric reconstruction uses physical centre distances and donor half widths.
The final implicit physical solve retains real accepted water and original
surface/extraction/dispersion/decay laws. Positive surface storage is excluded
only from private predictor scratch; production-owned surface mass is retained
in final state. Uniform/no-surface compatible cases delegate the predecessor.

The first longer native trial exposed the same293rd-step failure in production
and FCT: a negative rounded solute remainder at exactly empty surface storage,
with zero water residual. Selecting the existing analytical empty-pool limit
consistently for both owners resolves this trial without tolerance changes.
Its earlier failed runs and the short4e-6day wet-pond prefixes are retained
separately in the indexed native capsule. Only the final0.4day matrix supports
the native transition/restart claim. The research configuration uses a distinct
1670001 water identity; valid-CRC670001 restart identities reject.

Eight native evidence controls and the current composed owner/source checks
pass. The current13 controls validate the separately admitted481day/NUT/disk
composition and retain its frozen316-control predecessor evidence. An archived
checkout-path replay failure was reproduced and retained; source providers now
bind to one archived source root and generated outputs to their actual build
root. No scientific assertion or numerical threshold is removed.

Scope remains a constructed short native forcing with authentic source import,
not the full original historical project, annual accuracy, or a production
default change. Upward top solute return, negative drainage, heat/age/macropore
composition and native spatial/temporal accuracy require further qualification.
The separate admission receipt owns any canonical admission after actual-merge
verification. Reproduction: build_native.py, run_native.py, verify_native.py.
