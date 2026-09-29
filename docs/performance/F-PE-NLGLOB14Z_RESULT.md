# F-PE-NLGLOB14Z result — saturated-block disappearance control exposure

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB14Z_DISAPPEARANCE_CONTROL`

Qualification authority:

- workflow run: `36611726887`;
- job: `109554553056`;
- workflow conclusion: SUCCESS;
- scientific aggregate classification: blocked because 2/8 preregistered controls do not complete the full selected horizon.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

The canonical delta since NLGLOB14Y is ELASTIC44-only and does not alter the TIMEINT17/NLGLOB dependency surface.

## Frozen question

Does the accepted persistent-KLAG lower saturated block disappear under unchanged dry forcing within the staged horizon 1.6 -> 3.2 -> 6.4 d?

## Stage outcome

The staged study reaches the preregistered maximum horizon of 6.4 d because complete disappearance is not observed.

No fixture reaches an empty accepted saturated set.

The disappearance claim is therefore not qualified.

## New late-retreat evidence

Six of eight fixtures, namely both route families at dt <= 1.25e-4 d, remain complete, finite and mass-clean through 6.4 d and expose a further accepted retreat:

`7:16 -> 8:16`.

Observed event time:

- HEAD: approximately 2.442875 d at dt = 1.25e-4, 6.25e-5 and 3.125e-5 d;
- RUNOFF: approximately 2.43975 d, 2.4396875 d and 2.43971875 d over the same three dt levels.

For these six completed controls:

- no reverse post-retreat expansion occurs;
- no saturated node is skipped;
- geometry remains contiguous;
- physical mass remains near roundoff;
- final accepted saturated set at 6.4 d is nodes 8:16.

Thus the physical lower edge continues to retreat, but disappearance is much later than 0.8 d and still not exposed by 6.4 d.

## Coarse-dt blocker

The two dt = 2.5e-4 d fixtures are process-return clean and mass-clean up to their terminal accepted state, but do not satisfy the control completion gate at 6.4 d.

They therefore cannot be silently credited as valid 6.4 d controls.

This prevents either of the preregistered positive aggregate classifications from being assigned.

The exact coarse-dt terminal mechanism is not established by NLGLOB14Z itself and requires a bounded attribution successor before deciding whether:

- the coarse temporal level has reached a genuine validity boundary;
- a previously qualified transactional retry mechanism should apply;
- or the long-horizon harness has exposed a separate control/instrumentation limitation.

No tolerance change is authorized.

## Physical mass

Across all records, including the incomplete coarse fixtures:

- maximum accepted-interval ledger is about `2.36e-14 cm`;
- maximum cumulative ledger among completed fine fixtures is about `1.14e-12 cm`.

There is no evidence that the observed late retreat is a mass-conservation artifact.

## Scientific interpretation

The disappearance problem remains open, but the control lifecycle has advanced one more physical step:

`7:16 -> 8:16`

near 2.44 d on the six complete finer trajectories.

The spacing of retreat events continues to grow strongly with time.

It would be unjustified to extrapolate from 2.44 d to complete disappearance.

The immediate blocker is now narrow: explain the two coarse 6.4 d non-completions before deciding how to continue the disappearance control bank.

## Consequence

Open a separately preregistered coarse-dt terminal attribution workunit.

It must reproduce only the two dt = 2.5e-4 d fixtures and record:

- terminal reason and step/time;
- solver status and retry_advised;
- accepted saturated set at terminal origin;
- candidate saturated geometry if available;
- transaction rollback;
- physical mass;
- dynamic-top route;
- whether the terminal mechanism is already covered by an existing qualified retry contract.

Do not tune MAXIT, BALTOL, forcing or dt.

## Production boundary

Research only.

No production `src/**` change.

No production temporal ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
