# F-PE-ELASTIC56 — mode-7 Binf monotonicity violation attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC55 — QUALIFIED_MULTIPROFILE_GLOBAL_ENVELOPE_RESEARCH_CANDIDATE_WITH_MONOTONICITY_CAVEAT`

Parent postimage:
`research/f-pe-elastic55-multiprofile-holdout@fdca01fef07f005af4b72d327a71028a06452a09`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

What exactly causes the 15 Binf monotonicity violations observed in ELASTIC55?

## Frozen replay

Replay the ELASTIC55 bank byte-for-byte in physical/numerical meaning:
- same four preregistered selected profiles;
- same retention materialization;
- same generated Ss;
- same states, perturbations, regimes and nine-step dt ladder;
- same mode-7 research indicator;
- same O0/O2 checks.

No alpha, solver, forcing, tolerance, geometry or material changes.

## Violation definition

For each profile/state/forcing/regime sequence:
1. retain full-converged points with available Binf;
2. order by decreasing dt;
3. a violation occurs when the next retained smaller-dt Binf is greater than
   the previous retained Binf by more than 1e-12 relative.

For every violation record:
- profile id;
- regime;
- h0;
- delta;
- larger and smaller dt;
- their retry indices;
- Binf values;
- growth factor and relative increase;
- full/half convergence status at both endpoints;
- realized H_INF when paired;
- frozen-envelope margin when paired.

## Attribution classes

`CONTIGUOUS`:
the violating retained points are direct neighboring retry indices.

`GAP`:
one or more intervening retry indices are absent because the full solve or
indicator was unavailable.

For GAP cases record every intervening retry point and its full-solve status.

## Secondary classification

For CONTIGUOUS cases classify:
- `SMALL`: Binf increase <= 5%;
- `MODERATE`: >5% and <=25%;
- `LARGE`: >25%.

This magnitude classification is descriptive only.

## Gates

A1. Replay reproduces ELASTIC55 profile selection exactly.

A2. Replay reproduces exactly 15 monotonicity violations.

A3. O0/O2 semantic identity.

A4. Every violation receives exactly one CONTIGUOUS/GAP class.

A5. Frozen ELASTIC54 global envelope remains observation-only and unchanged.

A6. Zero `src/**` production changes.

## Decision

If violations are predominantly GAP, route next work toward convergence-window
handling.

If violations are predominantly CONTIGUOUS and material, route next work toward
controller robustness to locally non-monotone indicators.

No controller or production policy is changed in ELASTIC56.


## Clarification amendment after first replay

The first ELASTIC56 replay exposed a counting-semantic ambiguity in the parent
ELASTIC55 wording.

ELASTIC55's reported `15 monotonicity violations` were 15 **sequences with at
least one increasing retained Binf transition**, not 15 individual increasing
dt-to-dt transitions.

Under the ELASTIC56 pairwise definition above, those 15 parent sequences contain
51 increasing retained transitions in total.

This amendment does not alter:
- any case;
- any profile;
- any numerical result;
- any classification rule.

It corrects only gate A2:

A2a. replay reproduces exactly 15 distinct violating
`(profile,h0,delta,regime)` sequences;

A2b. every increasing retained transition within those sequences is attributed;
the first replay observed 51 such transitions and this count becomes the
reproducibility check for the unchanged replay.

The CONTIGUOUS/GAP and magnitude classifications remain preregistered exactly as
above.
