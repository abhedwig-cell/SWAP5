# F-PE-NLGLOB14T preregistration — transactional split-domain shadow interval

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority rechecked before this write:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- `research/f-pe-nlglob14s-split-ownership-feasibility@61748c7af9a1aa5bd7faa4bda6a64be756887ab2`;
- NLGLOB14S: `NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`;
- whole-column TG release remains falsified by NLGLOB14R1-R4;
- NLGLOB14N3 retry-bracket contraction and refined first-retreat event-time qualification remain required.

The canonical delta since the NLGLOB14S parent is outside the TIMEINT17/NLGLOB constitutive, temporal-provider, saturation-entry, mass and transaction dependency surface. NLGLOB14T therefore branches from the qualified NLGLOB14S research postimage rather than pretending that NLGLOB14S is canonically admitted.

## Frozen question

Starting from exactly the accepted first-retreat state with nodes 1:3 unsaturated and nodes 4:16 forming the contiguous saturated lower block, can one finite shadow interval be advanced with:

- TG temporal storage treatment in nodes 1:3;
- saturated/full-Richards temporal storage treatment in nodes 4:16;
- one and only one hydraulic flux through face 3/4;
- one recombined physical water balance;
- no fitted interface head, no independent interface fluxes and no residual redistribution;
- no commit to the persistent-KLAG control trajectory?

## Frozen fixtures

Use the existing 12 O05 first-retreat trajectories:

- wet-entry family HEAD and RUNOFF;
- dt = 2.5e-4, 1.25e-4, 6.25e-5, 3.125e-5, 1.5625e-5 and 7.8125e-6 d;
- first accepted 14 -> 13 retreat endpoint;
- accepted split geometry nodes 1:3 / 4:16;
- unchanged dry-phase forcing;
- unchanged qbot;
- persistent-KLAG next accepted interval as control endpoint.

## Frozen split shadow formulation

The shadow owns a copied accepted state only. The control state and accounting are immutable authority.

For the single interval, solve one coupled nonlinear endpoint system for all 16 node heads. The spatial split is expressed in the temporal residual, not by two independently fitted boundary problems.

At every residual evaluation:

1. derive one constitutive state and one set of internal Darcy face fluxes from the single trial head vector;
2. face 3/4 is computed once from the heads and provider conductivity on nodes 3 and 4;
3. use that exact same signed face flux in node 3 and node 4 residuals;
4. upper nodes 1:3 use a trapezoidal/TG storage residual using origin and endpoint physical flux divergence;
5. lower nodes 4:16 use a saturated/full-Richards backward endpoint storage residual, allowing real lower-block storage change and retreat;
6. preserve the observed dry top flux and bottom flux from the accepted origin for this bounded feasibility experiment.

No interface head is an independent unknown. No interface exchange is tuned outside the coupled residual.

This is a research shadow discretization, not a production implementation and not yet an assertion that this is the final moving-interface integrator.

## Transaction contract

Before the shadow solve, copy:

- pressure heads;
- water contents;
- ponding;
- accepted top/bottom flux observations;
- control endpoint records.

The shadow may mutate only its private trial arrays. After classification, verify byte/value equality of the copied accepted origin against the untouched control-origin data. The persistent executable trajectory is never altered.

## Required diagnostics

Per fixture record at minimum:

- convergence and nonlinear iteration count;
- interface flux at origin and shadow endpoint;
- one-flux interface cancellation;
- upper/lower/total storage changes;
- top, bottom and interface interval integrals;
- recombined physical mass ledger;
- maximum residual;
- upper saturation crossings;
- lower saturated block before/after;
- lower retreat/expansion;
- shadow versus persistent-KLAG endpoint head and theta differences;
- rollback/origin differences;
- finite-state gate.

## Frozen gates

A fixture is `TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL` only if:

1. the origin geometry is exactly upper 1:3 unsaturated and lower 4:16 saturated;
2. the coupled nonlinear shadow converges to max residual <= 1e-10 cm water-equivalent per node equation;
3. all shadow heads, theta values and face fluxes are finite;
4. exactly one face-3/4 flux authority is used and algebraic interface cancellation is <= 1e-12 cm;
5. total recombined mass ledger is <= 5e-8 cm;
6. upper TG nodes remain constitutively valid;
7. lower nodes are not artificially frozen: their evolution is whatever the coupled lower residual requires;
8. the shadow control-origin rollback differences for head, theta and ponding are <= 1e-15;
9. no independent interface fitting, residual redistribution or threshold/hysteresis rule is used.

The control endpoint is a comparator, not an identity requirement. Record endpoint differences but do not fail solely because split and persistent-KLAG temporal discretizations are not identical.

## Frozen aggregate classifications

If all 12 fixtures pass:

`QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`.

If the coupled residual cannot produce a single converged interface-consistent endpoint:

`NLGLOB14T_INTERFACE_COUPLING_NOT_CLOSED`.

If lower-domain evolution is nonfinite, effectively forced frozen by the formulation, or cannot maintain a physically valid lower state:

`NLGLOB14T_SATURATED_BLOCK_EVOLUTION_INADEQUATE`.

If upper nodes cross or leave the admissible TG constitutive domain in the coupled interval:

`NLGLOB14T_UPPER_TG_SHADOW_NOT_ADMISSIBLE`.

If mass, rollback, state authority or accounting leaks:

`NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT`.

Mixed fixture outcomes classify `NLGLOB14T_MIXED_SPLIT_SHADOW_RESULT`.

## Interpretation boundary

A positive 14T result qualifies one finite research shadow interval only.

It does not yet qualify:

- committing the split endpoint;
- multiple accepted split intervals;
- moving the ownership face;
- chatter-free interface migration;
- final disappearance of the saturated block;
- production temporal ownership.

Those require a separately preregistered successor.

## Stop rules

Do not:

- return to whole-column TG release;
- freeze the saturated lower block by construction;
- fit h, theta or saturated-count thresholds;
- fit separate interface fluxes;
- introduce residual redistribution;
- tune MAXIT/BALTOL or forcing to rescue failures;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14T

BASELINE: `61748c7af9a1aa5bd7faa4bda6a64be756887ab2`

BRANCH: `research/f-pe-nlglob14t-transactional-split-shadow`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement the coupled one-interval shadow harness against the 12 qualified first-retreat fixtures, then expose results only after this preregistration commit.

## Production boundary

Research only. No production source or numerical default is changed. `LEGACY_NUMERICS` remains the production default.
