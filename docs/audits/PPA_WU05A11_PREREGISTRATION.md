# PPA-WU05-A11 preregistration — FMR perched-zone macropore carrier

Date: 2026-10-01

Status: `PREREGISTERED_SOURCE_AUTHORITY_RECONCILIATION`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

A10 closed the bounded serialized Reference-Richards FMR route for source-faithful top input and main-domain rapid drainage. The next bounded functional gap toward the standard SWAP 4.3.1 macropore route is perched/top saturated matrix-zone coupling.

A11 is deliberately narrower than a general macropore expansion. It targets only the missing production carrier and source-authority needed to activate the already source-bound A6 perched-zone behavior.

## Repository authority already established

The recovered A6 source maps on the historical A8 research postimage establish that exact B1.11 MACRORATE:

- excludes the perched partly saturated matrix interval from unsaturated absorption;
- calls the same SATFLOW law for a perched/top saturated matrix zone and for the main saturated matrix zone;
- identifies `QInIntSatDmCp` as matrix-to-macropore saturated interflow from the perched/top saturated zone, not domain-to-domain macropore exchange.

Current canonical production code already contains those bounded rate semantics:

- `sorptivity_rate_request_t%perched_active/perched_top_node/perched_bottom_node`;
- perched exclusion in `evaluate_sorptivity_rate` and `evaluate_unsat_absorption`;
- a separate `interflow_sat` saturated-zone request in the A6 rate bundle.

Current FMR composition intentionally disables them:

- `prepare_standard_macropore_rate_request` forces `perched_active=.false.`;
- `interflow_sat` is configured as an empty matrix zone;
- `fmr_macropore_config_valid_for_nodes` rejects a perched-active template.

## Required A11 authority before implementation

A11 must recover or re-establish from the exact B1.11 source oracle the rule that determines, for each physical trial:

1. whether a distinct perched/top saturated matrix zone exists;
2. its top and bottom compartment indices;
3. the reference level/head used by the SATFLOW request;
4. how partial saturation at its boundary is represented;
5. its relationship to the separately derived main groundwater saturated-zone view.

No production rule may be invented from a convenient proxy such as `pressure_head >= 0` unless the exact source trace proves that equivalence for the admitted route.

## Intended implementation if authority closes

The smallest admissible production change is:

- add a derived `matrix_perched_zone_view_t` or equivalent non-persistent hydraulic view;
- populate A6 `perched_*` fields and the existing `interflow_sat` request from that view;
- keep the seven-field macropore continuation state unchanged;
- keep Reference Richards as the inner solver with `macropore_active=.false.`;
- preserve A8/A9/A10 behavior bit-for-bit when no perched zone is present;
- prove reject/discard/replay and restart continuation with active perched-zone exchange;
- keep all perched matrix/macropore exchange internal to whole-column mass accounting.

## Explicit non-scope

A11 does not admit:

- arbitrary within-compartment rapid-drain levels;
- multiple rapid-drain levels;
- covering-layer `IcTopMp > 1` top-input physics;
- within-corrector dynamic crack-geometry displacement feedback;
- RossFast;
- parallel/concurrent MultiSWAP.

## Affected invariants

- 3 explicit data separation;
- 4 compact persistent state;
- 7 transactional time steps;
- 13 mass conservation;
- 21 reuse SWAP physics;
- 22 no HeadCalc-internal dependency;
- 23 physical options separate from numerical policy;
- 25 Reference mode remains available.

Expected effect: compliant. No new persistent state is expected.

## Gates

A11-G1: exact perched-zone source/carrier rule recovered.

A11-G2: deterministic FMR hydraulic-view derivation qualified against source oracle.

A11-G3: active perched A6 rate composition plus whole-column mass closure.

A11-G4: reject/discard/replay and restart continuation.

A11-G5: A8/A9/A10 preservation.

Only after G1-G5 may a production-admission candidate be claimed.
