# F-PE-ELASTIC59 — real accepted-history budget-bridge attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-real-history-budget-bridge`

Qualified postimage:
`39a76a74f27129b9a406ebc7508e71d3014bba7a`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36699972365`

Job:
`109836863924`

Conclusion:
SUCCESS.

## Question

Did ELASTIC58's direct P2E09 budget-bridge falsification arise primarily from
the zero-history bootstrap proxy, or does the mismatch remain when the
history-based defect indicator receives a real accepted previous derivative?

## Accepted-history construction

For every exact P2E08 material/Se/forcing case, ELASTIC59 first executed a
previous Reference interval of 0.0064 day from the exact P2E08 initial state.

The previous interval used stationary prescribed-flux forcing:

`q_history_top = q_history_bottom = -K(h0)`.

The history solve had to:
- converge;
- satisfy the same strict Reference validity gates;
- preserve the P2E08 initial head to <= 1e-10 cm;
- preserve water content to <= 1e-12.

All history intervals passed.

Observed maxima:

- history max |delta h| = `0.0 cm`;
- history max |delta theta| = `0.0`;
- history max right-derivative infinity norm = `0.0 cm/day`.

The stationary history is therefore bit-exact under this frozen construction.

## Paired ZERO versus HISTORY indicator

For each of the 54 current P2E08 coarse solves, the admitted bottom-mode-2
defect indicator was evaluated twice:

1. ZERO:
   `previous_right_derivative = 0`;

2. HISTORY:
   previous derivative from the accepted stationary history interval.

Because the accepted history derivative is exactly zero, the two indicator
results are bit-identical.

Maximum relative Binf change:

`0.0`.

## Budget-bridge result

The ELASTIC58 direct bridge behavior is reproduced exactly.

ZERO:
- bridge failures: `30 / 54`;
- maximum scaled-bound / P2E09-budget ratio:
  `13.501173306023919`.

HISTORY:
- bridge failures: `30 / 54`;
- maximum ratio:
  `13.501173306023919`.

By Se:

### Se = 0.65

- ZERO failures: 15;
- HISTORY failures: 15;
- worst ratio: `13.5012` for both.

### Se = 0.85

- ZERO failures: 15;
- HISTORY failures: 15;
- worst ratio: `4.62120` for both.

### Se = 0.98

- ZERO failures: 0;
- HISTORY failures: 0;
- worst ratio: `0.994347` for both.

## Independent Reference authority preservation

The current P2E08/P2E09 realized Reference self-disagreement remains fully
inside the frozen P2E09 head-infinity envelopes:

`0 / 54` realized threshold failures.

Frozen ELASTIC54/55 alpha remained:

`0.17320259355765216`.

O0/O2 output identity passed.

No `src/**` or `reference/**` changes were made.

## Attribution

The zero-history bootstrap proxy is not the cause of the ELASTIC58 bridge
falsification in this stationary-origin experiment.

A real accepted stationary history produces exactly the same previous
right-derivative and exactly the same Binf.

Therefore the remaining mismatch is attributed to the transfer of the
ELASTIC54/55 global Binf-to-realized-error scaling from its mode-7/profile
calibration domain into the independent P2E08 mode-2 material/Se domain.

This is a domain-transfer limitation, not a startup-history artifact.

## Hypothesis outcome

Stationary accepted history exists and preserves the P2E08 initial state:
SUPPORTED exactly.

Real-history Binf differs materially from zero-history Binf:
FALSIFIED. Difference is exactly zero.

Bootstrap/history initialization explains ELASTIC58:
FALSIFIED for the tested stationary-history construction.

Alpha/domain transfer as the dominant remaining limitation:
SUPPORTED.

## Decision

Classification:

`QUALIFIED_ALPHA_DOMAIN_TRANSFER_AS_DOMINANT_BRIDGE_LIMITATION`.

No production history policy, F-CI14 numeric temporal profile or controller
admission is authorized.

The next bounded workunit should test whether a state-stratified scaling can
simultaneously satisfy two independent constraints on held-out materials:

1. realized-error lower requirement:
   `alpha(Se) >= max(H_INF/Binf)`;

2. independent P2E09 budget upper requirement:
   `alpha(Se) <= min(P2E09_limit(Se)/Binf)`.

A useful bridge exists only where the admissible interval is non-empty and a
preregistered training-derived alpha survives blind material holdout.
