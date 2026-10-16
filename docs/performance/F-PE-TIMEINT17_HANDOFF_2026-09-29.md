# F-PE TIMEINT17 / NLGLOB handoff — 2026-09-29

Date: 2026-09-29

Status: HANDOFF

Current canonical at handoff:

`integration/f-ci-canonical@c62c6de8886030767c70e699448077aa70a7f269`

AGENTS authority at handoff:

`AGENTS.md@3da9ffe679b8fcde0ccab1fa1311dd6c81e5336b`

## Executive status

The original TIMEINT16 Thomas-Gladwell line is no longer blocked on generic endpoint globalization.

Current research authority is:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`

from:

- `docs/performance/F-PE-TIMEINT17_REQUALIFICATION_RESULT.md`
- `docs/performance/F-PE-TIMEINT17_REQUALIFICATION_CLOSEOUT.md`

The frozen 96-case same-route dynamic-top bank requalified 96/96 with:

- zero process failures;
- zero unsafe terminal reasons;
- finite accepted states;
- max interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`;
- 8 saturation-root attempts;
- 8 saturated-mode entries;
- 38 persistent saturated-mode intervals;
- zero post-entry root-attempt violations.

The smooth TIMEINT16C bank remains strongly second order at about 2.048 with deterministic work ratio 1.0 versus KLAG BE.

The historical TIMEINT17 blocker:

`BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`

remains valid for the earlier solver composition but is superseded as current mechanism authority.

## Key authority chain

### TIMEINT16

Qualified mechanism:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

Core result:

- second order recovered only when coefficient staging remains endpoint-oriented/provider-consistent;
- physical mass at roundoff;
- no production source admitted.

### NLGLOB01–12

The generic endpoint blocker was progressively decomposed.

Important preserved results include:

- NLGLOB04: storage representation floor identified;
- NLGLOB08: post-S0 tail state physically inert;
- NLGLOB09: initial S0 replay physically clean but insufficient recovery;
- NLGLOB10: separated TG predictor-domain failures from above-floor endpoint failures;
- NLGLOB11/11A: fixed half-step predictor falsified; head-space predictor preserved smooth order but did not solve the near-saturation accepted-state issue;
- NLGLOB12B: simple MAXIT increase falsified as general solution;
- NLGLOB12A: aggregate storage-representation floor confirmed;
- NLGLOB12C: representation-aware endpoint replay qualified at research level.

NLGLOB12C full-bank result:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`

with:

- 87/96 completion at that stage;
- all 8 stagnation targets recovered;
- representation acceptances obeying exact local and aggregate representation bounds;
- physical mass near roundoff.

### NLGLOB13–14

The remaining TG near-saturation issue was pursued as a temporal saturation-event problem.

NLGLOB13 one-level halfstep subdivision closed insufficiently.

NLGLOB14 established that a one-shot linear saturation-event estimate is insufficient and opened bracketed event localization.

The accumulated NLGLOB14 chain ultimately supported the positive TIMEINT17 requalification above.

## Current remaining boundary

The broad same-route dynamic-top research policy is qualified.

The remaining unqualified physics is **desaturation / release from persistent saturated mode**.

Current canonical closeout:

`F-PE-NLGLOB14H_CLOSEOUT.md`

Final status:

`NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`

Observed across all eight frozen forcing-reversal fixtures:

- profile storage decreases;
- ponding disappears;
- surface route returns to surface-flux;
- bottom flux remains zero;
- original saturation-event node remains node 16;
- event-node theta remains saturated;
- event-node pressure head becomes strongly positive.

Therefore release cannot safely be defined from the original event node alone.

## Direct current successor

Current preregistered successor:

`F-PE-NLGLOB14I — dry-phase saturated-set migration attribution`

Preregistration exists on branches including:

- `research/f-pe-nlglob14i-saturated-set-migration-current`
- `research/f-pe-nlglob14i-saturated-set-migration-r2`
- `research/f-pe-nlglob14i-saturated-set-migration`

The cleanest preregistration authority read during handoff is:

`docs/performance/F-PE-NLGLOB14I_PREREGISTRATION.md`

on:

`research/f-pe-nlglob14i-saturated-set-migration-current@9ece20abe4ed0e9c6f6cce468d85853562da75bf`

That branch is based on canonical `cf043007...` and is behind current canonical only by unrelated ELASTIC22 admission commits. Reconcile before any write.

## NLGLOB14I frozen question

Determine whether desaturation progresses spatially through the profile during the dry phase.

Reuse exactly the 8 NLGLOB14G/H forcing-reversal fixtures:

- material O05;
- TG mode;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.012 d;
- identical wet-to-dry forcing reversal;
- unchanged complete same-route research policy;
- unchanged physical mass authority.

For every accepted dry-phase interval derive:

1. saturated-node count;
2. shallowest saturated node;
3. deepest saturated node;
4. whether saturated nodes form one contiguous lower block ending at node 16;
5. number of unsaturated nodes above that block;
6. surface route;
7. ponding;
8. storage;
9. top and bottom flux.

Saturation requires both existing indicators to agree:

- `SAT_H_i = 1`;
- `SAT_THETA_i = 1`.

Any disagreement is a state-consistency failure.

Frozen aggregate classifications:

- `NLGLOB14I_LOWER_SATURATED_BLOCK_RETREATS`;
- `NLGLOB14I_LOWER_SATURATED_BLOCK_PERSISTS`;
- `NLGLOB14I_NONCONTIGUOUS_SATURATION_PATTERN`;
- `NLGLOB14I_SATURATION_INDICATOR_INCONSISTENT`;
- otherwise `NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`.

Do not extend the horizon, change dry forcing, alter saturation indicators, invent a release threshold, or introduce a release switch inside NLGLOB14I.

## Repository / branch caution

Parallel work remains active.

Before every write:

1. fetch current `integration/f-ci-canonical`;
2. fetch the chosen NLGLOB14I branch;
3. reread `AGENTS.md` if changed;
4. compare the live delta;
5. incorporate only relevant canonical changes;
6. force-push never;
7. do not overwrite parallel result/closeout files;
8. preserve preregistration-before-results discipline.

At handoff, canonical advanced from `cf043007...` to `c62c6de...` only through unrelated ELASTIC22 files, so the NLGLOB14I scientific dependency surface appeared unchanged. Recheck this at resume.

## Workstream state

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

CURRENT MECHANISM AUTHORITY: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`

CURRENT OPEN WORK UNIT: F-PE-NLGLOB14I

PRODUCTION STATUS: research only

PRODUCTION DEFAULT: `LEGACY_NUMERICS`

MASS AUTHORITY: unchanged

TIMEINT18 VARIABLE-STEP/LTE: still downstream of release/event semantics

NEXT SAFE STEP: reconcile NLGLOB14I to current canonical, execute the unchanged 8-fixture saturated-set migration attribution, persist result/closeout, and only after its frozen classification decide whether a release criterion can be preregistered.

## Stop boundary

Do not reopen generic endpoint globalization unless new evidence invalidates the admitted NLGLOB01–14 dependency surface.

Do not return to empirical threshold tuning.

Do not open TIMEINT18 before release semantics are qualified or explicitly re-ordered by a new preregistered authority.
