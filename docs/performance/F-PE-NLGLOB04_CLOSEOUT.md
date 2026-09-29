# F-PE-NLGLOB04 closeout — storage representation floor attribution

Date: 2026-09-29

Final status:

`NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@a409df7572018969f0e73a05696c402edd2363c2`

Qualification authority:

- run `36539684028`;
- job `109311861278`;
- SUCCESS.

## Closure

NLGLOB04 identifies the dominant arithmetic floor behind the late-iteration TIMEINT17 endpoint stagnation.

The signal is not caused by:

- large Newton steps;
- final total-residual summation;
- local summation of already formed residual terms.

It is consistent with finite representation of the storage increment `theta - thetam1`.

Evidence:

- 333/333 primary poor-model near-floor records have `r_storage_ulp <= 10`;
- median primary `r_storage_ulp ≈ 0.48`;
- all 6 route-mode families satisfy the frozen storage-floor direction;
- adequate-model near-storage-floor fraction is only about 0.358;
- local compensated summation changes 0% of primary residuals materially;
- median local cancellation condition number is about `3.8e11`.

## Relation to BALTOL02

This strengthens rather than replaces BALTOL02.

BALTOL02 already admitted a timestep-scaled balance-rate floor corresponding to a fixed integrated water-depth representation scale.

NLGLOB04 independently finds that the remaining endpoint failures occur at the same type of theta/storage representation limit.

The BALTOL02 coefficient is not reopened.

## Direct successor

Open:

`F-PE-NLGLOB05 — floor-aware nonlinear convergence certificate`.

The certificate is a research acceptance discriminator, not a tolerance relaxation.

It must require all of the following classes of evidence:

1. current compartment and total balance are within the already qualified BALTOL02 numerical-resolution neighborhood;
2. the dominant residual is demonstrably at the storage representation floor;
3. Newton correction has collapsed and further accepted backtracking candidates do not materially reduce the relevant convergence measures;
4. head and ponding updates are within their existing convergence contract or otherwise independently certified as numerically exhausted;
5. physical accepted-interval mass remains unchanged and closed;
6. state is finite and route-consistent;
7. negative-control unresolved iterations are rejected.

No production convergence rule is authorized before that discriminator is qualified against both positive and negative controls.

## Research order

1. NLGLOB05 observational/replay certificate discrimination;
2. if positive, apply the certificate test-only to the frozen TIMEINT17 endpoint bank;
3. require recovered endpoint completion without new physical/mass failures;
4. only then return to TIMEINT17 same-route dynamic-top qualification;
5. event localization remains downstream;
6. TIMEINT18 variable-step/LTE remains blocked until dynamic-top endpoint robustness is restored.

## Production boundary

No production source change.

No BALTOL02 change.

No tolerance or mass-gate change.

No MAXIT/backtracking/dt/K-staging change.

`LEGACY_NUMERICS` remains production default.
