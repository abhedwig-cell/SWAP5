# F-PE-NLGLOB14T result — transactional split-domain shadow interval

Date: 2026-09-29

Status:

`QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`

Qualification authority:

- workflow run: `36602968350`;
- job: `109524717907`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

The intervening canonical delta is outside the TIMEINT17/NLGLOB temporal-provider, saturation-entry, constitutive, physical-mass and transaction dependency surface.

## Frozen question

Can one finite research shadow interval be advanced from the qualified first-retreat accepted state with:

- TG temporal treatment on upper nodes 1:3;
- saturated/full-Richards temporal treatment on lower nodes 4:16;
- one shared 3/4 interface exchange authority;
- one recombined physical mass ledger;
- complete control-state immutability;
- no fitted interface head, independent interface flux or residual redistribution?

## Coverage

PASS.

All 12 HEAD/RUNOFF x six-dt fixtures complete the preregistered coupled split shadow.

Per-fixture classification:

`TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`

Aggregate classification:

`QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`

No process failures occur.

## Coupled solve

The shadow endpoint is solved as one coupled 16-head nonlinear system.

The spatial split appears in the temporal residual rather than as two independently fitted subproblems.

The 3/4 Darcy flux is computed once from the shared trial head/conductivity state. Its time-integrated exchange is used with opposite sign in the two domain balances.

Observed:

- nonlinear iterations: 2 or 3 in every fixture;
- maximum node-equation residual: about `1.47e-11`;
- preregistered residual gate: `1e-10`;
- interface-not-closed cases: 0.

Thus the finite-interval interface coupling closes without an independent interface-head degree of freedom.

## Physical mass and transaction result

All 12 cases retain a single conservative water balance.

Observed:

- exact algebraic interface cancellation: 0;
- maximum absolute physical mass ledger: about `1.47e-10 cm`;
- preregistered mass gate: `5e-8 cm`;
- pressure-head rollback difference: 0;
- water-content rollback difference: 0;
- ponding rollback difference: 0.

The persistent-KLAG trajectory remains untouched and authoritative.

There is no accepted-accounting leakage from the shadow transaction.

## Upper TG domain

No fixture develops an upper-domain saturation crossing.

Nodes 1:3 remain finite, unsaturated and constitutively admissible over the shadow interval.

Therefore:

- upper inadmissible cases: 0;
- the already-saturated predictor-overshoot mechanism isolated by NLGLOB14R4 is absent from the upper TG-owned domain.

## Lower saturated-block evolution

The lower block remains nodes 4:16 after this single shadow interval in all 12 fixtures.

Its water-content storage change is zero in this interval because those nodes remain on the saturated constitutive branch.

This does **not** mean that the lower block was frozen.

Its pressure heads evolve in every fixture under the coupled residual:

- maximum lower-block head change is about `0.0506 cm` in the coarsest RUNOFF case;
- at the finest levels the lower-block head change remains finite and nonzero, about `0.0012-0.0016 cm`.

Thus the saturated block supports genuine pressure redistribution at constant saturated water content. No lower head or flux was held fixed by construction.

The 3/4 exchange itself remains very small over this first post-retreat interval, consistent with NLGLOB14S. Endpoint interface fluxes remain small, with the largest observed magnitude about `6.03e-11 cm/d`.

## Comparison with persistent-KLAG control

The recombined split shadow endpoint is not required to be identical to the persistent-KLAG endpoint because the temporal formulations differ.

The observed differences nevertheless decrease strongly with timestep.

HEAD:

- coarsest max head difference: about `4.87e-4 cm`;
- finest max head difference: about `1.33e-6 cm`;
- coarsest max theta difference: about `8.72e-7`;
- finest max theta difference: about `8.78e-10`.

RUNOFF:

- coarsest max head difference: about `5.88e-4 cm`;
- finest max head difference: about `1.47e-6 cm`;
- coarsest max theta difference: about `7.29e-7`;
- finest max theta difference: about `7.25e-10`.

This is consistent with the split shadow and persistent-KLAG control approaching the same local physical trajectory as dt is refined. It is supporting evidence, not a separate convergence qualification.

## Scientific interpretation

NLGLOB14T passes the first finite-interval test that NLGLOB14S deliberately did not address.

A profile with a persistent saturated lower block can be advanced transactionally for one interval using split temporal ownership without:

- restoring full-column TG;
- fitting an interface head;
- fitting independent interface fluxes;
- freezing the lower pressure field;
- redistributing residual mass.

The lower block's zero storage change in this one interval is a physical consequence of remaining saturated, while its pressure field continues to evolve.

## Consequence

A separately preregistered successor may now commit the split endpoint in a research-only accepted-state sequence and test:

- multiple consecutive accepted split intervals;
- interface motion driven only by the accepted physical saturated set;
- monotone retreat versus chatter;
- ownership-face changes;
- eventual disappearance of the saturated block;
- only then, whole-column TG eligibility.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or production temporal-ownership policy changed.

`LEGACY_NUMERICS` remains production default.
