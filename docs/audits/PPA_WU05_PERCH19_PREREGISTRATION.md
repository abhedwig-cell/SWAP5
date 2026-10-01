# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / PRODUCTION_DEPENDENCY`

Baseline:
`research/ppa-wu05-a18-perched-authority-fixture@5434665c34cff570066ccd2d76e10a092f7979d7`

Canonical reconciliation at start:
`integration/f-ci-canonical@acdcccfd1ad95bb3693524907b378d8e06d33475`.

## Purpose

Move the exact B1.11 macropore flow-reduction retry ladder out of the A18 qualification
fixture and into explicit SWAP5 inner-Richards runtime policy.

Exact source ladder:

`FrReduQ = [1.0, 0.1, 0.01, 0.001]`

corresponding to bounded `IDecMpRat = 0..3`.

A18 proved this is an active production dependency: the source-backed Andelst perched
fixture requests retry at 1.0 and converges at 0.1.

## Ownership

The ladder is numerical/trial policy, not physical continuation state.

For one runtime execute call:

1. start from the caller's accepted matrix/macropore state;
2. attempt the inner-Richards solve with factor 1.0;
3. only when the solve explicitly advises retry, discard all attempt-local outputs;
4. retry from the exact same accepted state with 0.1, then 0.01, then 0.001;
5. publish candidate/history only from the first converged attempt;
6. if all four fail, return retry/failure without mutating accepted physical state.

The selected factor is diagnostic output, not restart state.

## Gates

G1: exact factor order and bounded attempt count.

G2: A18 Andelst authority automatically retries 1.0 -> 0.1 and converges without
test-side mutation of `flow_reduction`.

G3: failed factor attempts do not mutate accepted seven-field macropore state.

G4: final candidate, exchange receipt and mass closure equal the previously qualified
A18 fixed-0.1 result within existing tolerances.

G5: default outer A8-A10 route is unchanged when the inner route/retry ladder is disabled.

G6: A16/A15/corrected perched carrier preservation remains green.

## Non-scope

- no new persistent physical state;
- no covering-layer extension;
- no RossFast;
- no parallel MultiSWAP;
- no dynamic crack continuation feedback;
- no widening of mass or nonlinear tolerances.

## Decision

If G1-G6 pass on one persisted postimage:
`QUALIFIED_SOURCE_FAITHFUL_FREDUQ_RETRY_POLICY`.

Production admission remains a subsequent explicit workunit reconstructed from current
canonical because the historical perched research namespace collides with later canonical
generic PPA-WU05 identifiers.
