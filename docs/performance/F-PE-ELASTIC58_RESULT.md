# F-PE-ELASTIC58 — mode-7 multi-metric endpoint-error bracketing result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-endpoint-error-bracketing`

Qualified postimage:
`3d250bf4b38633e823ce0fa454343c8cfafa745d`

Canonical baseline at qualification start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Current canonical after qualification:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Workflow run:
`36691317206`

Job:
`109808951170`

Conclusion:
SUCCESS.

## Question

Which physical endpoint quantities actually carry the one-full versus two-half
temporal discrepancy in the bounded mode-7 bank, before any numeric F-CI14
endpoint limits are selected?

## Frozen replay

The ELASTIC55-57 four-profile bank was replayed unchanged:
- profiles 11060, 10260, 8016, 3030;
- same profile geometry and Staringreeks retention materialization;
- same generated Ss;
- bottom mode 7, swkimpl=0;
- fixed-flux top boundary;
- states -75, -20, +2, +10 cm;
- perturbations -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- same nine-step dt ladder.

All metrics were emitted only where full, half1 and half2 all converged.

Paired comparisons:
`801`.

O0/O2 identity passed.

No production source changed.

## Aggregate physical error envelope

Across all 801 paired endpoints:

- maximum H_INF:
  `0.2935041542464561 cm`;

- maximum THETA_INF:
  `6.143772462302577e-5`;

- maximum signed column-storage difference:
  `1.36164561548857e-5 cm water`;

- maximum unsigned local-storage difference:
  `1.05178821891910e-3 cm water`;

- maximum ponding-depth difference:
  `0 cm`;

- maximum groundwater-level difference:
  `0 cm`;

- maximum bottom-flux difference:
  `1.74290638775521e-3 cm/day`;

- maximum relative bottom-flux difference:
  `3.66927660580043e-4`
  = approximately `0.0367%`.

The frozen ELASTIC54 head envelope remained conservative.

Maximum observed:

`H_INF / (alpha * Binf) = 0.5186669835093733`.

Thus even the worst paired head error used only about 52% of the frozen
conservative head envelope.

## Metric localization

### Pressure head

Pressure head differs in every paired case.

This remains the dominant directly observable endpoint discrepancy.

### Water content

Water content also differs in every paired case.

Its magnitude is bounded by:
`THETA_INF <= 6.144e-5`.

For saturated active-ELAS cases the local theta difference remains linked to
the elastic storage slope, as established in ELASTIC50-52.

### Ponding

Ponding difference is exactly zero in all 801 paired comparisons.

Within this bounded fixed-flux bank, ponding therefore carries no observed
temporal endpoint error.

### Groundwater level

Groundwater-level difference is exactly zero in all 801 paired comparisons.

It likewise carries no observed temporal endpoint error in this bank.

### Column storage

Signed total-storage disagreement is generally extremely small because local
positive and negative theta differences cancel.

For three profiles the maximum signed difference is at or near floating-point
roundoff:
- 11060: `2.50e-15 cm`;
- 8016: `3.04e-8 cm`;
- 3030: `2.74e-15 cm`.

Profile 10260 contains the largest signed storage difference:
`1.36165e-5 cm`.

Unsigned local storage is much more informative:
maximum `1.05179e-3 cm water`.

Therefore signed bulk storage and local state error must remain conceptually
separate.

### Bottom flux

Bottom-flux temporal sensitivity is strongly profile dependent.

Profile 11060:
- zero observed bottom-flux difference in all paired cases.

Profile 3030:
- only roundoff-scale differences, maximum about `2.44e-15 cm/day`.

Profile 8016:
- maximum `1.82e-6 cm/day`;
- relative maximum `6.99e-7`.

Profile 10260:
- one materially larger response;
- maximum absolute difference `1.74291e-3 cm/day`;
- maximum relative difference `3.66928e-4`, about `0.0367%`.

Thus bottom-flux error cannot be assumed identically zero for all material
profiles, but the observed relative error remains small in this bank.

## Per-profile maxima

### 11060

- paired: 200;
- H_INF: `0.0276524 cm`;
- THETA_INF: `1.11837e-6`;
- STORAGE_L1: `1.67756e-5 cm`;
- qbot relative error: 0.

### 10260

- paired: 205;
- H_INF: `0.175967 cm`;
- THETA_INF: `2.01858e-5`;
- STORAGE_L1: `3.09516e-4 cm`;
- qbot relative error: `3.66928e-4`.

### 8016

- paired: 170;
- H_INF: `0.293504 cm`;
- THETA_INF: `6.14377e-5`;
- STORAGE_L1: `1.05179e-3 cm`;
- qbot relative error: `6.98970e-7`.

### 3030

- paired: 226;
- H_INF: `0.242157 cm`;
- THETA_INF: `4.04264e-5`;
- STORAGE_L1: `5.39018e-4 cm`;
- qbot relative error: roundoff scale.

## Interpretation

ELASTIC58 narrows the F-CI14 calibration problem substantially for this bounded
mode-7 Richards-only envelope.

Observed temporal endpoint error is carried primarily by:
1. pressure head;
2. local water content;
3. unsigned local storage redistribution;
4. profile-dependent bottom flux.

Ponding and groundwater level are exact in the present bank.

Signed total column storage is mostly too cancellation-prone to serve as the
sole accuracy criterion.

This does not mean ponding or groundwater limits can be omitted from a general
F-CI14 production profile. It means they are inactive/non-discriminating in
this specific fixed-flux, no-optional-process mode-7 bank.

## Decision

Classification:

`QUALIFIED_MODE7_MULTIMETRIC_ENDPOINT_ERROR_CHARACTERIZATION`.

No numeric endpoint tolerance is selected.

No production temporal policy is admitted.

The next bounded workunit should construct independent candidate endpoint-limit
profiles for the active metrics, with explicit provenance and holdout:
- head;
- theta;
- local/column storage;
- bottom flux.

That work should treat ponding/GWL as preserved exact controls in this bounded
bank rather than silently assigning arbitrary nonzero tolerances.
