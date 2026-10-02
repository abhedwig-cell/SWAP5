# TOP03 stationary-layer independent face audit

Date: 2026-10-02. Test-only observational extension before audit execution.
Initial source checkpoint: b51def6e552db4a129371c80359a7f723dfa4d89.
The initial 192-case O0/O2 matrix completed with exact optimization identity,
30 saturated controls and 54 exact inherited trajectories. The original fixed
budgets remain unchanged. The initial results are retained as primary raw
records, not substituted with a redesigned physical model.

The algebraic layer has different dry/prewetted nonlinear starting guesses.
To avoid treating solver-owned mass closure as proof of stationary physical
face consistency, independently reconstruct every accepted substep's layer
face fluxes from final candidate heads and unmodified physical K(h), or the
explicitly selected Ksat factor. Use the same distance-weighted harmonic
interior law and declared top face law. Check each layer compartment's
integrated continuity residual, and accumulate the matrix-side interface
input independently. Compare that integral to top input minus actual layer
storage change.

Apply the unchanged 1e-10 cm mass hard bound both to each local integrated
residual and cumulative interface ledger discrepancy. A failed audit blocks
physical interpretation rather than triggering a solver repair. Report rate
residuals too, without inventing a new rate tolerance. Instrumentation may
read only candidate data and diagnostic scratch; it must preserve primary
trajectories byte-for-byte after removal of AUDIT lines, at both optimizations.
Execute the same 192 cases/build, with no extra fitting or new physical axis.
Archive both phases and pinned source manifests. This audit is not transaction
receipt/commit, restart or BASE acceptance qualification.
