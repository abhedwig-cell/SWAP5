# F-PE-NLGLOB13B preregistration — bounded second-level near-saturation subdivision

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@5c498c9df933f900fd00869b72106584f10f6622`

Parent authority:

- NLGLOB13: `CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`;
- NLGLOB13A: `NLGLOB13A_MIXED_HALFSTEP_FAILURE`;
- all seven target failures are accepted-state retention-domain failures;
- 5/7 fail in halfstep 1 and 2/7 fail in halfstep 2;
- no halfstep endpoint, route, ponding or nonfinite failure was observed.

## Purpose

NLGLOB13B tests one additional bounded temporal subdivision level.

The candidate asks whether the failing `h/2` interval can be made admissible by replacing that interval with two `h/4` TG substeps while preserving the accepted-state and physical-mass contracts.

This is not an unbounded adaptive controller.

## Frozen candidate: TG_NEARSAT_SUBDIV4_BOUNDED

For TG only:

1. attempt the nominal interval `h` unchanged using the NLGLOB11A head-space endpoint coefficient stage;
2. if and only if the prospective accepted TG state leaves the retention domain, reject the nominal trial and split it into two `h/2` child intervals;
3. attempt each `h/2` child independently;
4. if and only if a given `h/2` child fails accepted-state retention admissibility, reject that child and replace it with two `h/4` intervals;
5. `h/4` intervals may not be subdivided further;
6. a non-domain failure at any level is fail-closed and is not rescued by subdivision;
7. if any child required to cover the nominal interval fails, rollback the entire nominal interval state and physical ledgers;
8. rejected trial work remains numerical work, but rejected trial state and physical mass do not become accepted authority.

Each accepted subinterval uses:

- NLGLOB11A head-space endpoint/provider-consistent K staging;
- unchanged TG accepted moisture average;
- unchanged constitutive projection;
- unchanged S0 replay in the dynamic bank.

No accepted-theta clipping is allowed.

## Mandatory banks

### Bank S — smooth second-order preservation

Use the original TIMEINT16C smooth four-ladder bank with the NLGLOB11A head-space stage.

Subdivision must remain inactive.

Require:

- 4/4 ladders complete;
- median refined top-head order >= 1.6;
- median refined top-theta order >= 1.6;
- at least 3/4 individual head orders >= 1.5;
- physical interval and cumulative ledgers <= 5e-8 cm;
- median work ratio versus KLAG BE <= 1.15.

### Bank N — seven near-saturation target trajectories

Reuse exactly the NLGLOB13A seven-case target set.

Require:

1. 7/7 complete requested horizon;
2. every case uses at least one subdivision event;
3. no accepted-state retention-domain failure remains;
4. no non-domain failure is silently subdivided;
5. all accepted states finite and route-consistent;
6. max accepted-interval physical ledger <= 5e-8 cm;
7. max cumulative physical ledger <= 5e-8 cm;
8. maximum subdivision depth is exactly bounded at `h/4` and no deeper interval occurs.

### Bank D — full 96-case S0 replay bank

Reuse the NLGLOB13 isolated S0-only dynamic bank plus the bounded second-level subdivision candidate.

Require:

- complete requested horizon in >=80% of cases;
- completed cases span TG and KLAG;
- all three routes represented;
- at least three materials represented;
- no process failure;
- no accepted-state retention-domain failure in completed trajectories;
- physical ledgers <=5e-8 cm;
- all completed states finite and route-consistent.

## Frozen classifications

If all three banks pass:

`QUALIFIED_TG_NEARSAT_SUBDIV4_BOUNDED_RESEARCH`.

If the seven target cases do not all complete:

`CLOSED_TG_NEARSAT_SUBDIV4_INSUFFICIENT`.

If smooth second-order behavior regresses:

`CLOSED_TG_NEARSAT_SUBDIV4_ORDER_REGRESSION`.

If mass, route, finite-state or rollback safety fails:

`CLOSED_TG_NEARSAT_SUBDIV4_PHYSICAL_ADMISSIBILITY_FAILED`.

If Bank N passes but the full dynamic bank remains below 80%:

`TG_NEARSAT_SUBDIV4_QUALIFIED_BUT_ENDPOINT_BLOCKER_REMAINS`.

## Stop rules

Do not:

- subdivide below `h/4`;
- tune subdivision depth after result exposure;
- subdivide endpoint nonconvergence, route mismatch, ponding failure or nonfinite state;
- clip accepted theta;
- change S0, BALTOL02, MAXIT, backtracking or physical route semantics.

A negative result closes this bounded depth-2 subdivision candidate.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
