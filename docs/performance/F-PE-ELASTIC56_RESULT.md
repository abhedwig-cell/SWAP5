# F-PE-ELASTIC56 — mode-7 Binf monotonicity violation attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic56-monotonicity-attribution`

Qualified workflow postimage:
`94b0ab1d787c4f11fa472b20315a42f3909c0332`

Current documentation head:
`6d0cca3a10bed42b42b5b8e49142a5e41eb63eae`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36677374243`

Job:
`109765169909`

Conclusion:
SUCCESS.

## Question

What exactly causes the Binf monotonicity caveat observed in ELASTIC55?

## Parent-semantic replay

The complete ELASTIC55 multi-profile bank was replayed without changing:
- selected profiles;
- profile geometry;
- Staringreeks retention materialization;
- generated Ss;
- solver;
- forcing;
- tolerances;
- mode-7 research indicator;
- frozen ELASTIC54 global alpha.

ELASTIC55's original "15 monotonicity violations" means:
15 eligible sequences with at least one increasing retained Binf transition,
where eligibility requires at least three full-converged,
indicator-available points.

The exact replay reproduced:
- 15 violating eligible sequences;
- 48 increasing retained transitions inside those sequences.

O0/O2 semantic identity passed.

## Transition attribution

Across the 48 increasing transitions:

- CONTIGUOUS: `38`;
- GAP: `10`.

Thus approximately 79% of increases occur between directly neighboring retry
indices.

The caveat is therefore not primarily caused by skipped non-convergent dt
windows.

Magnitude:
- SMALL, <=5%: `1`;
- MODERATE, >5% and <=25%: `19`;
- LARGE, >25%: `28`.

The majority are material increases, not roundoff-scale noise.

## Regime attribution

Of the 48 increasing transitions:

- OFF: `45`;
- FIXED_1E6: `3`;
- GENERATED: `0`.

This is the strongest ELASTIC56 result.

The multi-profile nonmonotonicity caveat is overwhelmingly associated with the
default-off saturated route.

No increasing transition was observed in the GENERATED regime over the
parent-eligible sequences.

Therefore the ELASTIC55 monotonicity caveat should not be described as a
generated-ELAS-specific problem.

## State and forcing attribution

All 48 increasing transitions occur at:

- h0 = `+2 cm`: `29`;
- h0 = `+10 cm`: `19`.

None occur at the tested unsaturated states:
- h0 = `-75 cm`;
- h0 = `-20 cm`.

All violations occur under positive perturbations:

- delta = `+0.035 cm/day`: `26`;
- delta = `+0.05 cm/day`: `22`.

No monotonicity violation occurs under the negative perturbations in the
ELASTIC55 eligible sequences.

The caveat is therefore localized to a strongly specific domain:

`saturated state + positive top-flux perturbation`.

## Profile attribution

Increasing transitions by profile:

- profile 11060, Zn30A: `2`;
- profile 10260, Zd30: `11`;
- profile 8016, EZg21: `11`;
- profile 3030, gY30: `24`.

The behavior is therefore material/profile dependent rather than universal.

Profile 3030 accounts for half of all increasing transitions.

## Worst transition

The largest observed increase is:

- profile: `10260`;
- regime: `FIXED_1E6`;
- h0: `+2 cm`;
- delta: `+0.05 cm/day`;
- dt: `0.015625 -> 0.0078125 day`;
- Binf: `20.2746 -> 166.412 cm`;
- relative increase: approximately `+720.8%`;
- class: CONTIGUOUS;
- both endpoints have converged full and two-half trajectories.

Observed H_INF:
- larger dt: `0.153300 cm`;
- smaller dt: `0.168947 cm`.

The frozen ELASTIC54 envelope remains conservative at both endpoints:
- margin at larger dt: approximately `3.36 cm`;
- margin at smaller dt: approximately `28.65 cm`.

Thus even the strongest Binf nonmonotonicity does not threaten the currently
qualified global conservative error envelope.

## Paired endpoint evidence

Thirteen increasing transitions have paired-converged full/two-half endpoints
at both sides of the transition.

In those cases the frozen global error envelope remains positive-margin.

This confirms that:
- indicator monotonicity and conservative error bounding are distinct
  properties;
- local Binf increase does not imply loss of the ELASTIC54/55 envelope.

## GAP cases

Ten transitions span at least one unavailable full-solve/indicator point.

These are real convergence-window discontinuities and should not be ignored.

However, because 38 transitions are CONTIGUOUS, convergence gaps cannot explain
the majority of the nonmonotonicity.

## Interpretation

ELASTIC55 raised a broad warning:
Binf was not universally monotone over multiple materials.

ELASTIC56 narrows that warning substantially.

The nonmonotonicity is:
- concentrated in OFF;
- absent in GENERATED over the observed eligible sequences;
- restricted to saturated initial states;
- restricted to positive forcing perturbations;
- predominantly contiguous rather than gap-mediated;
- often large;
- profile dependent.

This means the next problem is not a generic failure of the mode-7 defect
indicator.

It is a bounded controller-design issue in a specific saturated,
positive-forcing part of the state/material domain.

The globally conservative Binf-to-realized-error envelope remains intact.

## Decision

Classification:

`QUALIFIED_LOCALIZED_BINF_NONMONOTONICITY_WITH_GLOBAL_ENVELOPE_PRESERVED`.

No production change is authorized.

The next bounded workunit should evaluate controller robustness under this
localized nonmonotonicity.

The appropriate candidate should:
- never assume indicator decrease after a single dt halving;
- preserve hard mass acceptance;
- preserve the global conservative error envelope;
- fail safely when refinement increases Binf;
- be tested first against the 15 violating sequences plus matched monotone
  controls.

Only after such controller-level falsification should production integration be
considered.
