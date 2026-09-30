# F-PE-ELASTIC61 — verification-only total-balance sensitivity preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC60 — QUALIFIED_HALF1_TOTAL_BALANCE_FLOOR_CANDIDATE`

Parent postimage:
`research/f-pe-elastic60-half1-postmortem@493663e8f48d02e1d71546f2b074cfbf77f22a4e`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Is the persistent half1 oracle failure in the six ELASTIC59/60 cases causally
controlled by the solver's total-balance convergence criterion
`CritDevBalTot`?

## Frozen physical cases

Exactly the six existing cases:
- profile 8016;
- h0 = -20 cm;
- delta = +0.035 and +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- full-step dt = 0.0009765625 day;
- half-step dt = 0.00048828125 day.

## Production-shaped full solve

The full solve remains unchanged:
- max_iterations = 16;
- compartment balance tolerance = 1e-12;
- total balance tolerance = 1e-12;
- head/ponding tolerances unchanged;
- all physics unchanged.

Its accepted/research-indicator semantics must be invariant across sensitivity
arms.

## Verification-only half-step sensitivity

Half1 and half2 retain:
- max_iterations = 16;
- compartment balance tolerance = 1e-12;
- head tolerances unchanged;
- max_backtracking unchanged;
- all forcing/physics unchanged.

Only their solver-local total balance tolerance varies over the preregistered
set:

- 1.0e-12;
- 1.1e-12;
- 2.0e-12;
- 5.0e-12;
- 1.0e-11.

This is not a transaction mass tolerance change and not a production proposal.

## Expectations from ELASTIC60

Observed terminal total residual sums at the baseline half1 failure were:

- delta +0.035: about 4.1693e-12 cm/day;
- delta +0.05: about 1.0567e-12 cm/day.

If the total-balance convergence gate is causal:

- delta +0.05 may recover at 1.1e-12 or above;
- delta +0.035 should require a tolerance above roughly 4.17e-12, so 5e-12 is
  the first preregistered arm expected to permit convergence.

These are preregistered mechanistic predictions, not post hoc thresholds.

## Observations

For every case/tolerance arm record:
- full status and indicator Binf;
- half1/half2 status;
- half1/half2 nonlinear/backtracking counts;
- half1 terminal max compartment residual;
- half1 terminal total residual sum;
- paired H_INF and DTHETA_INF when available.

## Gates

A1. Exactly 30 physical sensitivity arms execute.

A2. Full solve semantics are invariant across tolerance arms.

A3. O0/O2 outputs agree.

A4. Baseline 1e-12 reproduces the six persistent half1 failures.

A5. Any recovered paired oracle must satisfy:
- H_INF <= 0.01 cm;
- DTHETA_INF <= 1e-5;
- frozen ELASTIC54/55 global envelope.

A6. Compartment tolerance remains exactly 1e-12 in all arms.

A7. Zero `src/**` production changes.

## Decision

If the preregistered threshold pattern recovers half1/paired convergence in
accord with the observed residual floors, qualify the total-balance convergence
criterion as causal for the verification gap.

No solver-tolerance production change is authorized by ELASTIC61.
