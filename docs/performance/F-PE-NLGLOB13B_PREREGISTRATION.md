# F-PE-NLGLOB13B preregistration — bounded second-level failing-half subdivision

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@5c498c9df933f900fd00869b72106584f10f6622`

Parent authority:

- NLGLOB13: `CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`;
- NLGLOB13A: `NLGLOB13A_MIXED_HALFSTEP_FAILURE`;
- all 7/7 target failures are accepted-state retention-domain failures;
- 5 fail in halfstep 1 and 2 fail in halfstep 2;
- endpoint, route, ponding and nonfinite halfstep failures are absent.

## Purpose

NLGLOB13B tests one additional bounded temporal localization level.

The hypothesis is that the accepted-state retention-domain boundary can be crossed safely by reducing only the failing half-interval from `h/2` to two `h/4` substeps.

No unbounded or adaptive recursion is allowed.

## Frozen candidate: TG_NEARSAT_SUBDIV4

For a TG nominal interval:

1. attempt the full nominal interval using the order-preserving NLGLOB11A head-space endpoint coefficient stage;
2. if and only if the prospective accepted TG state fails retention-domain admissibility, reject the full trial and split into two `h/2` subintervals;
3. attempt halfstep 1;
4. if halfstep 1 fails only by accepted-state retention-domain admissibility, restore its pre-half accepted state and replace that half by two `h/4` substeps;
5. after halfstep 1, attempt halfstep 2;
6. if halfstep 2 fails only by accepted-state retention-domain admissibility, restore its pre-half accepted state and replace that half by two `h/4` substeps;
7. any non-domain failure at `h/2` or `h/4` fails closed;
8. any accepted-state domain failure at `h/4` fails closed;
9. the nominal interval is committed only when all required subintervals succeed.

Maximum depth is fixed:

`h -> h/2 -> h/4`.

No `h/8`.

## Transaction semantics

Before each rejected full or half trial:

- accepted physical state must be restored exactly;
- cumulative and per-interval physical ledger state must not retain rejected-trial effects;
- numerical work diagnostics may retain attempted work;
- no rejected-trial derivative or K-stage state may become accepted authority.

## Frozen banks

### Bank S — smooth preservation

Use the NLGLOB11A smooth TIMEINT16C bank.

Subdivision must remain inactive.

Require:

- 4/4 ladders complete;
- median refined top-head order >=1.6;
- median refined top-theta order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledgers <=5e-8 cm;
- median work ratio versus KLAG BE <=1.15.

### Bank N — seven near-saturation targets

Reuse exactly the NLGLOB13A seven target trajectories.

Require:

1. 7/7 execute;
2. 7/7 complete requested horizon;
3. at least one `h/4` event occurs in each target trajectory;
4. no accepted state leaves the retention domain;
5. no route mismatch or nonfinite accepted state;
6. max accepted-interval ledger <=5e-8 cm;
7. max cumulative ledger <=5e-8 cm;
8. no `h/4` domain failure.

### Bank D — full dynamic replay

Use the current research dynamic bank with unchanged S0 and R0 research endpoint certificates plus TG_NEARSAT_SUBDIV4.

Require:

- 96/96 execute;
- >=80% complete requested horizon;
- TG and KLAG represented;
- all 3 routes represented;
- at least 3 materials represented;
- physical/cumulative ledgers <=5e-8 cm;
- all completed states finite and route-consistent;
- no process failure.

## Frozen classifications

If all banks pass:

`QUALIFIED_TG_NEARSAT_SUBDIV4_RESEARCH`.

If any target still fails accepted-state admissibility at `h/4`:

`CLOSED_TG_NEARSAT_SUBDIV4_DOMAIN_PERSISTS`.

If target failures are non-domain at `h/4`:

`CLOSED_TG_NEARSAT_SUBDIV4_OTHER_FAILURE`.

If smooth order regresses:

`CLOSED_TG_NEARSAT_SUBDIV4_ORDER_REGRESSION`.

If physical mass/state safety fails:

`CLOSED_TG_NEARSAT_SUBDIV4_PHYSICAL_ADMISSIBILITY_FAILED`.

If Bank N passes but full dynamic recovery remains below 80%:

`TG_NEARSAT_SUBDIV4_QUALIFIED_ENDPOINT_BLOCKER_REMAINS`.

## Stop rules

Do not:

- introduce `h/8`;
- choose subdivision depth adaptively from observed overshoot magnitude;
- clip accepted theta;
- alter S0 or R0;
- change BALTOL02, MAXIT, backtracking or route physics.

A negative NLGLOB13B closes this bounded subdivision depth.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
