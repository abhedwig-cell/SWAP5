# ROM-0R R3Q2 F-KT trajectory authority

R3Q2 does not invent another solver or transaction path. It uses the existing F-ROM0TA3 Reference-floor sample/candidate/commit API.

Before each prescribed-head perturbation interval, the current committed physical state is snapshotted and the already-qualified R3Q1 representation-bounded total criterion is computed from that state. A local parameter copy receives only the resulting total-balance rate tolerance. The timestep, boundary forcing, local balance threshold, head thresholds, nonlinear iteration cap, backtracking cap and physics remain frozen.

For every interval an independent direct Reference solve is also executed from the same committed base state with the same policy parameter. That direct candidate has no commit authority. The F-KT sample candidate must be bit-identical to it, including the FMR sign convention for bottom-outward exchange, before the F-KT candidate is committed.

This workunit therefore tests policy transfer plus ownership, not new physics. A PASS establishes a lower-boundary prescribed-head Reference-floor trajectory inside the research ownership contract. It does not erase the original R3 no-go under the fixed 1e-12 cm/day total-balance control.

ROM-1A remains blocked until the required vertical-resolution Reference-floor diagnostic closes.
