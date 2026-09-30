# F-PE-NLGLOB14Z43D result — reference-only heterogeneous holdout replacement selection

Date: 2026-09-30

Status:

`QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED`

Qualification authority:

- workflow run: `36778334241`;
- job: `110101790895`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43d-reference-holdout-replacement@e4a4b7c332fd06bbac9614d6054a9623621dcdaa`

## Frozen deterministic selection result

The first frozen replacement candidate is:

`B01_N64_T49`.

It completes the full-reference-only 4,000-interval preflight under the unchanged explicit MAXIT16 test profile.

Because the preregistered selection rule stops at the first passing candidate, `B01_N32_T25` is not executed.

## B01_N64_T49

Observed reference diagnostics:

- complete: yes;
- accepted intervals: 4,000;
- failing interval: none;
- status: converged;
- retry advised: no;
- nonlinear iterations at final interval: 2;
- Jacobian builds: 2;
- linear solves: 2;
- backtracking attempts: 2;
- internal retries: 0;
- diagnostics route: `legacy-reference-bound`;
- max accepted per-interval physical ledger: about `8.90e-16 cm`;
- final tail start: 49.

## Interpretation

The O14 synthetic holdout can be replaced without manager-driven selection or timing bias.

The selected B01 fixture was chosen using only full-reference solvability and a frozen deterministic order.

No adaptive-manager timing or physical comparison was observed during selection.

## Revised admission holdout authorized downstream

A separately preregistered admission-candidate successor may now freeze exactly:

1. O05_N64_T49;
2. B12_N64_T49;
3. O05_N32_T25;
4. B01_N64_T49.

All four must use the same explicit non-default MAXIT16 test profile from Z43C.

Historical Z43/Z43C outcomes remain unchanged.

## Qualified claim boundary

Qualified:

- B01_N64_T49 is full-reference solvable for 4,000 intervals;
- physical mass remains clean;
- deterministic reference-only selection is complete;
- one replacement fixture is now frozen for downstream admission evidence.

Not qualified:

- adaptive B01 trajectory;
- four-case admission performance;
- production admission;
- canonical admission.

## Production boundary

Reference-fixture selection only.

`LEGACY_NUMERICS` remains production default.
