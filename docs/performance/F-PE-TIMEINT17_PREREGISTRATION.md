# F-PE-TIMEINT17 preregistration — provider-consistent Thomas-Gladwell dynamic-top composition

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@f73372ec97e431e10d03b1cf6eb9db4368dfb97f`

Parent authority:

- TIMEINT16 final classification:
  `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- TIMEINT12:
  fully implicit dynamic-top analytical surface derivative qualified;
- TIMEINT12A:
  ordinary SWKIMPL=1 dynamic-top execution not robust/cost-effective;
- BOFEK00:
  corrected wet/ponding top-boundary/Jacobian authority admitted.

## Objective

Determine whether the qualified one-step Thomas-Gladwell mechanism can be composed with SWAP's dynamic atmospheric/ponding/runoff top boundary while preserving:

1. physical consecutive-state interval mass;
2. second-order temporal accuracy away from boundary events;
3. robust flux/head switching;
4. explicit physical ponding storage ownership;
5. transaction-safe event semantics;
6. the cost advantage of the provider-consistent predicted-K endpoint solve.

No adaptive timestep controller is introduced in TIMEINT17.

## Literature/context authority

Dynamic Richards top boundaries are commonly represented as switching conditions between prescribed flux and prescribed head depending on surface saturation or water availability.

Current model documentation and recent mass-conservative Richards implementations explicitly restart or switch the boundary solve when the surface saturation constraint is crossed rather than silently averaging incompatible boundary modes.

Event-driven treatment is also standard for discontinuous vector fields: the discontinuity surface is located and the governing field is changed at the event.

Implication for TIMEINT17:

a flux-to-head, head-to-flux, ponding-onset, ponding-depletion, or runoff-onset transition is a **hard temporal event candidate**.

Do not assume that a TG interval spanning such a transition can retain second-order semantics by endpoint mode selection alone.

## Existing SWAP dynamic-top regime surfaces

The canonical B1.10 dynamic-top provider currently distinguishes:

- atmospheric-head evaporation limitation;
- surface-flux route;
- ponded-head route;
- ponded-head-linear-runoff route.

Key route predicates include:

- atmospheric limitation from `q1 > emax`;
- surface-flux versus head switching through the saturated-head estimate `h0 <= 1e-6 cm`;
- ponding/runoff transition through the no-runoff ponding solution versus `ponding_max`;
- previous accepted ponding storage participates explicitly in the top-boundary water budget.

TIMEINT17 treats changes between these routes as temporal events for diagnostic purposes.

## Qualified interior TG mechanism

Within one fixed boundary regime, use TIMEINT16C unchanged:

1. evaluate accepted-origin physical derivative;
2. form current-step moisture predictor
   `theta_tilde = theta_n + h theta_dot_n`;
3. exact constitutive projection to predicted head;
4. evaluate provider-consistent `K_tilde`;
5. hold `K_tilde` fixed in the endpoint nonlinear solve;
6. obtain endpoint predictor derivative;
7. accept
   `theta_TG = theta_n + 0.5 h (theta_dot_n + theta_dot_p)`;
8. project accepted moisture to constitutively consistent head.

No historical K extrapolation.

## TIMEINT17 candidate set

### A. TG_DYNTOP_UNSPLIT

Diagnostic baseline only.

Apply the qualified TG coefficient staging over the full interval while allowing the existing dynamic-top provider to select its endpoint route through the normal candidate solve.

Purpose:

- determine completion/robustness;
- detect route changes between accepted origin and endpoint;
- quantify physical mass;
- establish whether unsplit event-crossing trajectories lose order or produce route ambiguity.

This arm may qualify **same-route intervals only**.

It may not establish second-order authority for an interval that changes dynamic-top route.

### B. TG_DYNTOP_EVENT_SPLIT

Primary event candidate.

If origin and trial endpoint imply different dynamic-top route class, treat the first route transition as a hard event.

Locate an event time fraction `0 < lambda <= 1` inside the trial interval using a deterministic bracketed search over the route-switch scalar associated with the relevant transition.

Frozen P0 event-locator policy:

- use bisection only;
- no Newton/secant event timing;
- max 40 bisection iterations;
- event-time tolerance:
  `max(1e-10 d, 1e-8 * h)`;
- route predicate must be evaluated from a transaction-safe trial state;
- no accepted state mutation during event search.

After event location:

1. solve/accept the pre-event subinterval with the origin regime;
2. commit physical state exactly at the event;
3. restart TG derivative/coefficient staging from that event state;
4. solve the post-event remainder under the new route;
5. publish the outer requested interval as the sum of the two physical subinterval ledgers.

The event state is a real physical intermediate accepted state for the purpose of the interval transaction, not numerical history water.

### C. BOUNDARY-ONLY EVENT SPLIT COMPARATOR

If needed for attribution, use the same event split with ordinary KLAG Backward Euler subinterval solves.

Purpose:

- distinguish event-location/boundary problems from TG temporal problems;
- not a production candidate.

## Event surfaces and stop rule

TIMEINT17 P0 only opens event splitting for route transitions for which a deterministic scalar sign change can be constructed directly from existing provider algebra.

Priority order:

1. surface-flux ↔ ponded-head onset/depletion;
2. ponded-head ↔ linear-runoff onset/cessation;
3. atmospheric-head transition.

Do not invent a generic route-index interpolation.

If a route transition cannot be represented by a bracketable physical scalar under existing provider semantics, classify that transition as deferred rather than using route-number bisection.

## Physical mass contract

Surface ponding is physical storage.

For each accepted subinterval:

`soil_storage_change + ponding_storage_change = physical_surface_input - runoff - evaporation - bottom_outflow - internal_sinks`

using the existing SWAP sign/ledger authority.

For an outer interval split at one event:

`L_outer = L_pre + L_post`.

The intermediate event-state storage cancels algebraically.

No temporal-history term may be added to the physical ledger.

No storage-derived external flux reconstruction.

## Fixed P0 bank

Use the established TIMEINT13/14 dynamic-top bank:

materials:

- B01;
- B12;
- O05;
- O14.

Initial surface classes:

- MOIST;
- WET;
- POND.

Total:

12 trajectories.

Initial fixed dt authority:

`0.005 d`

Initial horizon:

`0.12 d`

Bottom:

- mode 2;
- zero prescribed bottom flux.

No macropores/root/drains in P0.

Use the currently admitted corrected dynamic-top provider/Jacobian authority.

## P0 metrics

Per trajectory and per accepted requested interval record:

- completion;
- accepted route at interval origin;
- endpoint route;
- event count;
- event type;
- event fraction;
- bisection iterations;
- minimum pre/post event subinterval;
- physical interval ledger;
- cumulative ledger;
- soil storage;
- ponding storage;
- runoff;
- actual infiltration/top flux;
- accepted top head/theta;
- deterministic work;
- retries/backtracking;
- nonfinite/clamp events.

For same-route smooth segments, also run a local dt ladder around selected windows to measure TG order.

Do not estimate global second-order convergence across a genuine boundary discontinuity.

## Frozen P0 gates

### Interior/same-route mechanism

For at least one representative smooth same-route window in each available route class:

- 4-level halving ladder;
- median head and theta order >=1.6;
- individual representative order >=1.5;
- physical ledger <=5e-8 cm;
- constitutive roundtrip <=1e-12.

### Dynamic trajectory robustness

Primary event-split arm:

1. at least 10/12 complete;
2. every MOIST class complete;
3. at least 2/4 POND complete;
4. no nonfinite accepted state;
5. no negative ponding beyond numerical tolerance;
6. no unexplained route oscillation/chatter;
7. max per-requested-interval physical ledger <=5e-8 cm;
8. max cumulative physical ledger <=5e-8 cm.

### Event location

For every split event:

- physical scalar bracket exists;
- event fraction finite and within [0,1];
- event-time bracket width meets frozen tolerance;
- exactly one route transition is committed per located event;
- no zero-length infinite restart loop.

### Work

Compare completed TG event-split trajectories to current KLAG dynamic-top at the same requested dt.

Research mechanism work gate:

- median total deterministic work ratio <=1.35;
- no completed trajectory ratio >1.75.

If mechanism passes but work fails:

`TG_DYNTOP_MECHANISM_QUALIFIED_COST_BLOCKED`.

## Interpretation

### Positive

If same-route second-order gates, dynamic robustness, physical mass and event-location gates pass:

`QUALIFIED_TG_DYNAMIC_TOP_EVENT_SPLIT_MECHANISM`

This remains research-only.

### Positive without event crossings

If TG is robust/second-order only on trajectories that remain in one route and event-crossing authority is insufficient:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_ONLY`

Do not claim event qualification.

### Negative event semantics

If unsplit works but event split cannot obtain a physical bracket or produces route chatter:

`BLOCKED_TG_DYNAMIC_TOP_EVENT_SEMANTICS`.

### Negative solver composition

If fixed-route/same-route TG itself loses robustness under dynamic-top operator composition:

`BLOCKED_TG_DYNAMIC_TOP_OPERATOR_ROBUSTNESS`.

### Negative conservation

If state trajectories complete but physical ledger fails:

`BLOCKED_TG_DYNAMIC_TOP_CONSERVATION`.

## Transaction rules

Event search is a nested trial operation.

Required ownership:

- outer requested interval checkpoint;
- pre-event trial checkpoint;
- event candidate states are discardable;
- only converged event state may become the origin of the post-event subinterval;
- any post-event failure rolls the entire requested interval back unless the transaction architecture explicitly supports partial commit;
- publication remains one requested interval containing zero or more physical subintervals.

No hidden accepted mutation during bisection.

## Stop rules

Do not in TIMEINT17:

- tune DTMIN/DTMAX;
- introduce variable-step TG formulas;
- tune LTE controller;
- change mass tolerances;
- add historical K extrapolation;
- use fully implicit SWKIMPL=1 as rescue;
- average flux-mode and head-mode residuals across an unresolved switch;
- open root/drain/macropore composition.

If event-split semantics qualify, variable-step/LTE work belongs to TIMEINT18.

## Production boundary

Test-only research qualification.

No production `src/**` change before reproducible mechanism authority.

No default change.

`LEGACY_NUMERICS` remains production default.
