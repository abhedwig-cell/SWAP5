# F-PE-TIMEINT05 result — variable-step BDF2 mechanism

Date: 2026-09-28

Status: `VARIABLE_BDF2_RATIO2_MECHANISM_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@2304aa642589090b9a3f7924b34c9e7d6e6eec79`;
- Actions run: `36482722864`;
- qualification job: `109132032972`;
- conclusion: SUCCESS.

## Candidate

Variable-step fully implicit BDF2 with exact step-ratio coefficients:

`a0=(1+2r)/(1+r)`

`a1=-(1+r)`

`a2=r^2/(1+r)`

for `r=h_n/h_{n-1}`.

The BDF2 representation-aware total-balance floor uses the absolute values of these same coefficients.

No other solver or physical rule changes.

## Qualification result

### R1 — constant step

- 4/4 ladders complete;
- median refined top-head order: 2.0519;
- 4/4 individual orders >=1.5;
- median work per step: 16.0;
- exact endpoint/work preservation versus TIMEINT04 constant-step BDF2 at all 16 common points.

### R1P5 — adjacent ratio envelope 1.5

Pattern:

`[0.8,1.2]`.

Result:

- 4/4 ladders complete;
- median refined top-head order: 2.0921;
- all 4 individual orders >2.07;
- median work per step: 16.0;
- storage spreads remain O(1e-14 cm).

### R2 — adjacent ratio envelope 2.0

Pattern:

`[2/3,4/3]`.

Result:

- 4/4 ladders complete;
- median refined top-head order: 2.1407;
- all 4 individual orders >2.09;
- median work per step: 16.0;
- storage spreads remain below 1e-10 cm by a large margin.

R2 therefore passes every frozen gate.

### R3 — adjacent ratio envelope 3.0

Pattern:

`[0.5,1.5]`.

Result:

- only 2/4 ladders complete;
- both B01 ladders fail;
- O05 ladders complete;
- median work per step on complete ladders rises to 17.5.

R3 is outside the qualified mechanism envelope.

## Preservation

R1 variable-step implementation is exactly identical to TIMEINT04 constant-step BDF2 on all 16 common points:

- max top-head difference: 0;
- max middle-head difference: 0;
- max bottom-head difference: 0;
- max storage difference: 0;
- work difference: 0.

## Scientific conclusion

Variable-step fully implicit BDF2 is a viable second-order mechanism on the qualified smooth fixed-flux envelope when adjacent accepted step ratios are bounded by 2.0.

This is materially better founded than the legacy timestep-growth heuristic:

- temporal order is explicit;
- variable-step coefficients are mathematically defined;
- a concrete step-ratio stability/robustness envelope is now demonstrated;
- per-step deterministic work is unchanged relative to constant-step BDF2.

The first clear robustness boundary appears between ratio 2 and ratio 3.

## Decision

Classification:

`VARIABLE_BDF2_RATIO2_MECHANISM_QUALIFIED`

Safe research envelope:

`0.5 <= h_n/h_{n-1} <= 2.0`.

This is mechanism qualification only.

No production BDF2 admission, dynamic-top qualification, or adaptive timestep controller is authorized here.
