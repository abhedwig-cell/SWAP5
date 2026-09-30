# F-PE-NLGLOB14Z9A result — confirmatory retreat 10:16 -> 11:16 control

Date: 2026-09-30

Status:

`QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`

Qualification authority:

- workflow run: `36670693926`;
- job: `109744847122`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Do all four unchanged persistent-KLAG control fixtures complete 60.0 d and expose exact accepted retreat:

`10:16 -> 11:16`?

## Coverage

PASS.

All four O05 fixtures complete 60.0 d and expose the exact accepted event.

HEAD:

- dt 1.25e-4 d: 53.994375 d;
- dt 6.25e-5 d: 53.994500 d.

RUNOFF:

- dt 1.25e-4 d: 53.991250 d;
- dt 6.25e-5 d: 53.9913125 d.

All final accepted saturated sets at 60.0 d are nodes 11:16.

## State and mass

All four trajectories are:

- finite;
- contiguous;
- non-reversing after the established late phase;
- non-skipping;
- mass-clean.

Observed maxima:

- accepted-interval physical mass ledger: about `2.36e-14 cm`;
- cumulative physical mass ledger: about `1.84e-12 cm`.

No mass correction or residual redistribution is used.

## Relation to NLGLOB14Z9

NLGLOB14Z9 remains historically blocked under its original 102.4 d aggregate completion contract because the fine RUNOFF trajectory fails after the accepted event.

Z9A is a separate, preregistered confirmatory workunit with a fixed 60.0 d horizon.

It confirms that the physical retreat itself is robust and reproducible across all four fixtures with accepted progression beyond the event.

This does not rewrite or weaken the Z9 blocked result.

## Instrumentation note

The emitted diagnostic prefix appears as `F_PE_NLGLOB14Z9AA_*` because of a harmless double string replacement in the research harness label.

The branch, workflow, fixtures, horizon, physical event definition and frozen classification are all NLGLOB14Z9A.

No numerical or physical behavior depends on the diagnostic prefix.

## Scientific interpretation

The accepted physical lower-edge retreat:

`10:16 -> 11:16`

is now independently confirmed.

It occurs near 53.99 d and is stable across both route families and both retained dt levels.

## Qualified claim boundary

Qualified:

`QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`.

Not yet qualified:

- split ownership through this event;
- later retreats beyond 11:16;
- complete saturated-block disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

A separately preregistered split successor may now test:

`10:16 -> 11:16`

with ownership move:

`face 9/10 -> face 10/11`

from accepted split state only.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
