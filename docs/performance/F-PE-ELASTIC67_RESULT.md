# F-PE-ELASTIC67 — negative-forcing N4 postmortem result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic67-negative-n4-postmortem`

Qualified postimage:
`5ff9538c7f166cf37a27848811bc7187f9d243a9`

Canonical authority:
`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Workflow run:
`36725587543`

Job:
`109921502190`

Conclusion:
SUCCESS.

## Question

Do the six negative-forcing profile-8016 N=4 Reference failures share the
total-balance-only mechanism already qualified for the positive-forcing
profile-8016 cases?

## Frozen cases

Exactly:
- profile 8016;
- h0 = -20 cm;
- delta = -0.05 and -0.035 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- parent C-SAFE accepted dt = 0.0009765625 day;
- N=2 control;
- N=4 target, substep dt = 0.000244140625 day.

No tolerance, alpha, controller, physical budget or hard mass gate changed.

## Control

All six N=2 controls complete and pass the independent mass ledger.

## N=4 failure locus

All six N=4 targets fail on substep 1 with:
- solver status = 2;
- route = `legacy-reference-retry`;
- nonlinear iterations = 16;
- Jacobian builds = 16;
- linear solves = 16;
- alternative solver calls = 0;
- internal retries = 1;
- saturated nodes = 0.

O0/O2 outputs are identical.

## Delta = -0.05 cm/day

All three ELAS regimes are diagnostically identical.

Observed:
- max compartment residual = `1.7748025271657752e-12 cm/day`;
- max-residual node = 7;
- absolute total residual = `1.5289991495137656e-12 cm/day`;
- residual L2 = `2.9659600767866181e-12 cm/day`;
- backtracking attempts = 101.

Both local and total balance criteria exceed the frozen `1e-12 cm/day`
solver threshold.

## Delta = -0.035 cm/day

All three ELAS regimes are again diagnostically identical.

Observed:
- max compartment residual = `1.8718360195180139e-12 cm/day`;
- max-residual node = 7;
- absolute total residual = `6.0573768223548541e-13 cm/day`;
- residual L2 = `2.8753439581051922e-12 cm/day`;
- backtracking attempts = 82.

Here the local compartment residual exceeds `1e-12 cm/day` while the total
residual is already below `1e-12 cm/day`.

This directly falsifies a total-balance-only attribution.

## Regime independence

For each forcing value, OFF, FIXED_1E6 and GENERATED are bit-identical across
the reported postmortem diagnostics.

The trajectories remain unsaturated.

The blocker is therefore not an active elastic-storage effect.

## Hypotheses

H1, exact N=4 substep-1 status-2 reproduction:
SUPPORTED, 6/6.

H2, regime-independent diagnostics:
SUPPORTED exactly.

H3, same total-balance-only mechanism as positive forcing:
FALSIFIED.

H4, local compartment criterion contributes independently:
SUPPORTED.

For delta -0.035 the local compartment gate alone explains the rejection,
because the total residual is already inside tolerance.

For delta -0.05 both local and total criteria are exceeded, so this workunit
does not claim which would remain limiting if the other were relaxed.

## Decision

Classification:

`QUALIFIED_NEGATIVE_FORCING_LOCAL_COMPARTMENT_RESIDUAL_BLOCKER`.

The remaining twelve-case independent-oracle gap therefore splits into two
mechanisms:

1. six positive-forcing cases:
   already-qualified total-balance-floor behavior at N=2;

2. six negative-forcing cases:
   a local compartment residual floor at N=4, with delta=-0.035 already inside
   the total-balance criterion.

A single total-balance-floor recovery rule cannot close the full profile-8016
oracle gap.

No production change is authorized.

A successor may test representation-scale attribution for the negative-forcing
local residuals, but must keep hard physical mass acceptance and the frozen
physical envelope unchanged.
