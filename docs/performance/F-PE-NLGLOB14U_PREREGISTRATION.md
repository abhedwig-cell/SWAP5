# F-PE-NLGLOB14U preregistration — accepted-state moving-interface split evolution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14T: `QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`;
- parent branch/postimage: `research/f-pe-nlglob14t-transactional-split-shadow@9d529e71cb02283f3599d3203a51d38e88cf7347`;
- NLGLOB14S: mechanically conservative 3/13 split qualified;
- NLGLOB14N3: refined first-retreat event and retry-bracket contraction remain authority;
- whole-column first-retreat TG release remains falsified.

## Purpose

NLGLOB14U asks whether the qualified one-interval split shadow can become a research accepted-state sequence over the remaining frozen dry horizon, with temporal ownership recomputed from the accepted physical state after every interval.

This workunit is not production admission.

## Frozen fixtures

Use the existing 12 O05 trajectories:

- HEAD and RUNOFF wet-entry families;
- six dt levels from `2.5e-4` through `7.8125e-6 d`;
- start from the first accepted 14 -> 13 retreat state;
- evolve to the already established `0.05 d` horizon;
- preserve the NLGLOB14G/L dry forcing exactly:
  - precipitation, irrigation, snowmelt and runon = 0;
  - potential bare-soil evaporation = original wet precipitation magnitude;
  - potential pond evaporation = the same magnitude;
- qbot remains the existing zero-flux lower condition.

The persistent-KLAG trajectory remains the matched control comparator.

## Dynamic-top authority

Unlike the one-interval NLGLOB14T feasibility test, do not hold the origin top flux fixed over the full sequence.

Reconstruct the admitted dynamic-top dry-surface semantics from the existing provider:

- evaluate the atmospheric evaporation capacity from the current accepted top head and provider conductivity;
- on an unponded surface, actual bare-soil evaporation is the minimum of frozen demand and nonnegative hydraulic capacity;
- use the corresponding current physical top flux;
- preserve the provider's atmospheric-head limitation when demand exceeds capacity;
- ponding must remain physically zero in this frozen dry sequence; any positive ponding is a classification failure rather than a fitted correction.

The same provider law is used at origin and candidate endpoint in the temporal residual.

## Moving ownership rule

Ownership is derived only from the accepted physical state.

After each accepted interval:

1. identify the maximal contiguous saturated block ending at node 16 using the exact accepted constitutive state:
   - `h >= 0`;
   - `theta == theta_s`;
2. all nodes above that block are upper TG-owned;
3. if a nonempty saturated block remains, the ownership interface is the single face immediately above its first node;
4. if the saturated block is empty, the profile becomes eligible for a separately interpreted whole-column TG state.

No fitted h/theta epsilon, saturated-count release threshold or hysteresis is allowed.

Under the unchanged dry forcing, an increase in saturated-block size after the 14T origin is classified as reverse interface motion/chatter unless directly required by a newly accepted physical crossing and separately attributable. It is not silently accepted as a release heuristic.

## Split interval residual

For each interval with upper nodes `1:k` and lower saturated nodes `k+1:16`:

- solve one coupled endpoint head system;
- compute every Darcy face flux from that one endpoint state;
- upper nodes use trapezoidal/TG physical storage balance;
- lower nodes use saturated/full-Richards endpoint treatment;
- the ownership-face exchange has exactly one temporal integral, the trapezoidal average of origin and endpoint physical interface flux, and enters both domain balances with opposite sign;
- the top exchange uses the same origin/endpoint dynamic-top provider law;
- lower internal faces and qbot retain the lower saturated treatment;
- no interface head is fitted and no residual redistribution is permitted.

If the saturated block disappears, do not silently continue with a new production policy. Record disappearance and stop the split-ownership sequence at that accepted state. Whole-column TG continuation belongs to a successor.

## Transaction semantics

Each interval is a research transaction:

- begin from the current private accepted research state;
- solve a candidate;
- evaluate finite-state, mass, ownership and physical-domain gates;
- commit only a passing candidate to the private research accepted state;
- on any failure, retain the previous accepted state exactly and record rollback differences.

The repository control trajectory is never mutated.

## Required diagnostics

For each fixture and accepted interval record:

- accepted step/time;
- upper-node count;
- saturated-block nodes;
- interface face;
- interface flux origin/endpoint/integral;
- dynamic top flux origin/endpoint and route;
- upper/lower/total storage changes;
- physical mass ledger;
- nonlinear iterations and residual;
- interface motion;
- retreat/expansion;
- rollback on any rejection;
- matched persistent-KLAG max head/theta differences where available.

Aggregate diagnostics include:

- total accepted split intervals;
- number and sequence of interface-face changes;
- any chatter/re-expansion;
- earliest complete disappearance, if any;
- maximum mass ledger/residual;
- endpoint discrepancy versus control as a function of dt.

## Frozen gates and classifications

A fixture is `ACCEPTED_SPLIT_EVOLUTION_VALID` if it reaches the 0.05 d horizon or an earlier physical saturated-block disappearance with:

- every committed interval finite;
- residual <= `1e-10`;
- physical mass ledger <= `5e-8 cm`;
- exact single-valued interface exchange;
- no upper-domain constitutive invalidity;
- no rejected-candidate state leakage;
- no empirical ownership threshold.

Aggregate outcomes:

If all 12 fixtures are valid and at least one accepted interface retreat beyond the initial 3/4 face is observed consistently:

`QUALIFIED_MOVING_INTERFACE_ACCEPTED_STATE_EVOLUTION_RESEARCH`.

If all 12 are valid but no further interface motion occurs before 0.05 d:

`NLGLOB14U_ACCEPTED_SPLIT_EVOLUTION_WITHOUT_INTERFACE_MOTION`.

If accepted ownership reverses or oscillates without a separately attributable physical crossing:

`NLGLOB14U_MOVING_INTERFACE_CHATTER`.

If one or more coupled intervals cannot close while rollback remains exact:

`NLGLOB14U_MULTI_INTERVAL_COUPLING_NOT_CLOSED`.

If mass, rollback or state authority leaks:

`NLGLOB14U_ACCEPTED_STATE_TRANSACTION_INCONSISTENT`.

If dynamic-top reconstruction diverges from the existing provider semantics or becomes unsupported:

`NLGLOB14U_DYNAMIC_TOP_NOT_PRESERVED`.

Mixed otherwise-valid fixture outcomes:

`NLGLOB14U_MIXED_ACCEPTED_SPLIT_EVOLUTION`.

## Interpretation boundary

A positive NLGLOB14U result qualifies research accepted-state split evolution only for this O05 dry-reversal bank and frozen horizon.

It does not yet authorize production temporal ownership.

Complete saturated-block disappearance, if observed, authorizes a separately preregistered whole-column TG re-entry study. If disappearance is not observed, a longer unchanged-forcing horizon requires its own preregistration.

## Stop rules

Do not:

- reintroduce full-column TG while any accepted lower saturated block remains;
- fit ownership thresholds or hysteresis;
- use the persistent-KLAG control top-flux sequence as hidden forcing;
- freeze lower heads;
- tune MAXIT/BALTOL or dry forcing;
- introduce independent interface fluxes;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14U

BASELINE: `9d529e71cb02283f3599d3203a51d38e88cf7347`

BRANCH: `research/f-pe-nlglob14u-accepted-moving-interface`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement provider-faithful multi-interval accepted split evolution over the existing 12-case 0.05 d bank.

## Production boundary

Research only. No production source or default policy changes.
