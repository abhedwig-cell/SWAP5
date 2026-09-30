# F-PE-ELASTIC58 — independent temporal-budget bridge feasibility result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-independent-budget-bridge`

Qualified postimage:
`6faa58d601889522a06af9f582a1951ed7e125a3`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36699337770`

Job:
`109834808374`

Conclusion:
SUCCESS.

## Question

Can the frozen ELASTIC54/55 conservative scaling

`E_bound = 0.17320259355765216 * Binf`

fit inside the independently frozen PUB-P2E09 Reference-only head-infinity
envelopes on the exact P2E08/P2E09 material/state/forcing/dt domain?

## Independent authority

The P2E08/P2E09 domain was replayed exactly:

- materials: B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- forcing = DRYING, NOMINAL, WETTING;
- selected common coarse dt = 0.0064 day;
- two half steps = 0.0032 + 0.0032 day;
- bottom mode 2 prescribed flux;
- Reference solver only.

Frozen P2E09 U_h_inf envelopes:

- Se=0.65: `0.002329984405367469 cm`;
- Se=0.85: `0.024875926496918055 cm`;
- Se=0.98: `1.0304935719866082 cm`.

These thresholds were frozen independently of ELASTIC46-57.

## Indicator bridge

The already admitted bottom-mode-2 defect indicator was evaluated on the
selected P2E08 coarse solve.

Because P2E08 is an isolated first-interval experiment, ELASTIC58 used the
preregistered research bootstrap proxy:

`previous_right_derivative = 0`.

No production startup-history policy is implied.

## Qualification

- all 54 exact physical cases executed;
- original P2E08 complete-domain validity remained 54/54;
- mode-2 temporal indicator AVAILABLE on all 54 selected coarse solves;
- O0/O2 output identity passed;
- no src/** or reference/** mutation;
- frozen alpha used without refit.

The realized P2E08 coarse-versus-two-half errors remain inside the frozen P2E09
envelopes:

`0 / 54` realized threshold failures.

Thus the independent P2E09 authority was reproduced correctly.

## Primary result

The direct scaled-Binf budget bridge fails.

`30 / 54` cases satisfy:

`alpha_global * Binf > P2E09_U_h_inf_limit(Se)`.

Classification:

`FALSIFIED_DIRECT_P2E09_BUDGET_BRIDGE`.

The largest ratio

`alpha_global * Binf / P2E09_limit`

is:

`13.501173306023919`.

## Effective-saturation attribution

### Se = 0.65

- cases: 18;
- maximum bound/budget ratio: `13.5012`;
- minimum ratio: `0.02587`.

Many materials therefore produce an ELASTIC54-scaled Binf more than an order of
magnitude larger than the independently frozen P2E09 head envelope.

### Se = 0.85

- cases: 18;
- maximum ratio: `4.62120`;
- minimum ratio: `0.02114`.

The bridge remains frequently too conservative.

### Se = 0.98

- cases: 18;
- maximum ratio: `0.994347`;
- minimum ratio: `0.004896`.

At the near-saturated P2E09 state the direct bridge is compatible across the
tested cases, with the worst case just below the independent envelope.

## Material pattern

Direct bridge failures occur in B01, O01, O05, O14 and O18 at Se=0.65 and/or
0.85.

Representative worst case:

- material: O05;
- Se: 0.65;
- forcing: WETTING;
- Binf: `0.1816227033 cm`;
- scaled bound: `0.0314575233 cm`;
- P2E09 limit: `0.0023299844 cm`;
- ratio: `13.5012`.

The actual Reference self-disagreement for the same case still remains within
the independent P2E09 threshold.

## Interpretation

ELASTIC58 falsifies a tempting but unjustified shortcut:

the ELASTIC54 global scaling cannot simply be combined with the independently
frozen P2E09 head envelopes and treated as a usable physical temporal budget.

The reason is not resolved inside ELASTIC58, by preregistration.

Two mechanisms remain possible:

1. the ELASTIC54 alpha is intentionally conservative and transfers poorly from
   its mode-7/profile calibration domain into the P2E08 mode-2 material domain;

2. the zero-history bootstrap proxy makes Binf excessively conservative for an
   isolated first interval.

ELASTIC58 does not choose between them post hoc.

The Se attribution is nevertheless informative:

- the mismatch is strongest in drier states;
- it weakens with increasing Se;
- at Se=0.98 the direct bridge is already compatible in the complete tested
  domain.

## Hypothesis outcome

Independent P2E09 realized-error reproduction:
SUPPORTED, 54/54.

Direct frozen-alpha Binf-to-P2E09 bridge:
FALSIFIED, 30/54 failures.

Near-saturated Se=0.98 compatibility:
SUPPORTED in the exact P2E09 bank.

Production numeric temporal budget:
NOT ESTABLISHED.

## Decision

Classification:

`QUALIFIED_DIRECT_INDEPENDENT_BUDGET_BRIDGE_FALSIFICATION`.

No F-CI14 numeric profile or production temporal policy is admitted.

The next bounded workunit should separate the two remaining explanations by
testing the same independent P2E08/P2E09 domain with a real accepted-history
right derivative rather than the zero-history bootstrap proxy, while keeping:
- the P2E09 thresholds frozen;
- alpha frozen;
- material/state/forcing domain unchanged;
- Reference solver and hard mass gates unchanged.

If history-aware Binf remains too conservative, the alpha/domain-transfer
hypothesis is strengthened.

If the bridge improves materially, startup/history initialization becomes the
next authority to qualify.
