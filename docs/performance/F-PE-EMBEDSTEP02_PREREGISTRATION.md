# F-PE-EMBEDSTEP02 preregistration — Reference-owned envelope with selective large-interval splitting

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`.

Parent: F-PE-EMBEDSTEP01.

## Purpose

Test a hybrid controller that cannot perturb the existing adaptive policy while operating inside the current Reference timestep envelope.

This is the final controller architecture tested in the current line.

## Reference-owned normal operation

For every accepted interval with dt <= Reference DTMAX:

- commit the normal single-step result;
- compute the historical Reference next-dt decision from nonlinear iterations exactly as in the current controller;
- also compute the normalized state-aware proposal using:
  `r_h = max_i(|dh_i| / max(10 cm, |h_i(t0)|))`;
  target `R=0.40`.

If the normalized proposal is <= Reference DTMAX, ignore it and use the historical Reference next dt.

Only if the normalized proposal is > Reference DTMAX may the hybrid controller request a larger next interval.

Thus the new policy is incapable of changing the timestep trajectory while it stays inside the existing Reference envelope.

## Large-interval execution

A requested interval above Reference DTMAX is not executed as one speculative full step.

Instead execute exactly two sequential half intervals from the same accepted origin.

The half-step route is committed only when both solves converge and each substep satisfies the unchanged mass-ledger gate.

If either half fails:

- commit nothing;
- reduce the outer requested interval by the existing failure factor;
- retry from the accepted origin.

No full-step comparison solve is performed. This removes the EMBEDSTEP01 speculative overhead.

After a successful split interval:

- compute the normalized state movement from outer origin to final two-half endpoint;
- derive the next normalized proposal;
- if that proposal is <= Reference DTMAX, return ownership to historical Reference-TimeControl;
- otherwise another split large interval may be requested.

## Bounds

- DTMIN unchanged;
- Reference DTMAX = 0.02 d;
- maximum requested outer interval = 4 * Reference DTMAX = 0.08 d;
- first dt unchanged;
- NUMBIT_CRIT, MAXIT, backtracking, failure reduction, head tolerances and BALTOL02 unchanged;
- SWKIMPL=0.

## Calibration

Use the exposed 16 BOFEK01 screening cases.

P-C1 remains unchanged.

Advancement requires:

- >=15/16 P-C1 pass;
- all WET/POND cases pass;
- median total deterministic work reduction >=15%, counting both half solves;
- no retry pathology.

If this fails, close the dynamic-top adaptive-controller line. No further controller rescue is permitted in this workunit.

If it passes, freeze the policy before constructing a new validation bank.
