# TAB-HYD KSATEXM candidate B result

Date: 2026-09-23

Status: **FALSIFIED — branch-aware 400-row spline still exceeds conductivity gate**

Predecessor:
- candidate A falsified an unsplit spline across the KSATEXM branch transition.

Candidate B:
- exact KSATEXM transition pressure head inserted as a table knot;
- dry/default and wet/KSATEXM ln(K) branches preprocessed independently;
- independent one-sided endpoint slopes using TSPACK IENDC=0;
- unchanged 400-row count and global log-head placement.

## Technical qualification of the implementation

The first B implementation incorrectly inherited the global K endpoint condition and forced an internal segment endpoint slope. That run is not scientific evidence for B.

Commit `995a6027aeca03095634a92f0e3e93cae71d033b` repaired this by using TSPACK IENDC=0 for both internal K segments, so left and right endpoint slopes are computed independently from their local branch data as preregistered.

The controlling rerun is workflow `35854917929`.

## Result

Exact Hupsel lower layer:

- theta max abs = `2.0753513608404162e-6` — PASS;
- C max abs = `6.3570482923912552e-6` — PASS;
- log10(K) max abs = `1.9382357654015525e-2` — **FAIL** versus limit `5e-4`.

Worst point:

- h = `-1.9386526359522058 cm`;
- analytical K = `25.604962690374933 cm/d`;
- candidate-B K = `24.48735005661418 cm/d`.

The first wet branch interval is bounded by the exact threshold knot at h=-2 cm and the next globally log-spaced knot near h=-1.85665 cm. The remaining error is therefore not caused by a spline crossing the derivative kink.

## Interpretation

Candidate B demonstrates that merely segmenting the spline is insufficient under the frozen 400-row/global-log-head representation and existing conductivity tolerance.

No knot-density or tolerance tuning is permitted under B.

## Next candidate class

A later candidate may preserve the generated table for the default-MvG branch while representing the already admitted F-SI39 near-saturated extension explicitly, rather than approximating that steep branch with the global table.

Such a candidate is a hybrid constitutive representation and requires a new preregistration.
