# F-PE-ELASTIC60 — saturated feasibility-gap attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_CONSERVATIVE_MONOTONE_HEADSPACE_CANDIDATE_WITH_SATURATED_EXHAUSTION`

Parent postimage:
`research/f-pe-elastic59-headspace-defect@ac365fbd46377c27fde9f42ae51bec89cd96d733`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Inherited physical limits:
- head: `0.01 cm`;
- theta: `1e-5`.

## Question

Why do all saturated ELASTIC59 sequences exhaust under `HCAND <= 0.01 cm`?

For each saturated profile/state/forcing/regime sequence distinguish:

### ORACLE_INFEASIBLE
No paired-converged point in the frozen dt ladder satisfies
`H_INF <= 0.01 cm`.

### BOUND_OVERCONSERVATIVE
At least one paired-converged point satisfies
`H_INF <= 0.01 cm`, but no full-converged point satisfies
`HCAND <= 0.01 cm`.

### BOUND_REACHABLE
At least one full-converged point satisfies `HCAND <= 0.01 cm`.

A BOUND_REACHABLE sequence must also be checked for the paired physical limits
when its selected point is paired.

## Frozen bank

Reuse ELASTIC59 exactly:
- profiles 11060, 10260, 8016, 3030;
- saturated initial states only: +2 and +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- same profile materialization;
- same mode-7, swkimpl=0 head-space research indicator.

Total saturated sequences:
`4 profiles * 2 heads * 4 perturbations * 3 regimes = 96`.

Total saturated requested points:
`96 * 9 = 864`.

## Additional observations

Per sequence record:
- smallest paired H_INF in the ladder;
- dt at smallest paired H_INF;
- smallest available HCAND;
- dt at smallest HCAND;
- first paired point satisfying head <=0.01, if any;
- first point satisfying HCAND <=0.01, if any;
- solver/indicator availability count;
- paired count.

Also report:
- class counts by profile;
- class counts by regime;
- class counts by initial head;
- class counts by forcing sign/magnitude.

## Hypotheses

H1. A material fraction of saturated sequences is BOUND_OVERCONSERVATIVE rather
than ORACLE_INFEASIBLE.

H2. GENERATED and FIXED_1E6 differ in the proportion of oracle-feasible
sequences.

H3. The OFF regime contains more ORACLE_INFEASIBLE cases because nonlinear
solvability limits the paired ladder.

## Gates

A1. Exactly the 96 saturated parent sequences are replayed.

A2. O0/O2 semantic identity.

A3. Every sequence receives exactly one of the three preregistered classes.

A4. Classification uses only the inherited 0.01-cm head limit and ELASTIC59
HCAND. No new scale is fitted.

A5. Any paired BOUND_REACHABLE selected point satisfies head <=0.01 and
theta <=1e-5.

A6. Zero `src/**` production changes.

## Decision

If BOUND_OVERCONSERVATIVE is common, route next work toward a sharper
non-fitted bound or a different independent temporal certificate.

If ORACLE_INFEASIBLE dominates, the immediate issue is the tested dt/solver
domain rather than indicator conservatism.

No production change is authorized by ELASTIC60.
