# ROM-1A-R1-D2 local integrated-invariant diagnostic

D1 established that D08 step 34 is a one-compartment local-balance retry with no
pressure-head convergence failure. That means the previously qualified total-only
fallback is correctly inapplicable.

D2 does not change the solver.

It compares the failed compartment residual, integrated over the frozen 0.0008-day
step, against the independently frozen 1.6e-15 cm per-compartment integrated
allowance used in the earlier PUB-P2E19/P2E20/P2E21 Reference research. This value
predates ROM-1 and is not fitted to the D08 result.

The original strict step is replayed unchanged. The allowance is used only as a
diagnostic comparator. A positive result may justify preregistering a separate
strict-first candidate-policy qualification. It does not itself authorize a local
balance tolerance change.
