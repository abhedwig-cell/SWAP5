# F-PE-TIMEINT05 preregistration — variable-step BDF2 mechanism and step-ratio qualification

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2304aa642589090b9a3f7924b34c9e7d6e6eec79`

Parent authority:

- TIMEINT04 / PR #732;
- constant-step fully implicit BDF2 is qualified on the smooth fixed-flux mechanism bank;
- BDF2 requires a representation-aware scalar total-balance floor;
- no production BDF2 admission exists.

## Purpose

Qualify the variable-step BDF2 storage operator and a bounded step-ratio envelope before any adaptive BDF2 controller or embedded error estimator is attempted.

Research-only. No production source change.

## Variable-step BDF2 operator

Let:

- current step = `h_n`;
- previous accepted step = `h_{n-1}`;
- step ratio = `r = h_n / h_{n-1}`.

For step index >= 2 use:

`a0 = (1 + 2r)/(1+r)`

`a1 = -(1+r)`

`a2 = r^2/(1+r)`

and storage rate:

`(a0*theta_np1 + a1*theta_n + a2*theta_nm1)/h_n`.

For `r=1` this reduces exactly to constant-step BDF2:

`1.5 theta_np1 - 2 theta_n + 0.5 theta_nm1`.

The storage Jacobian coefficient is `a0*C_np1/h_n`.

The first step of every trajectory uses fully implicit Backward Euler to bootstrap history.

## Representation-aware total-balance floor

Only in variable-step BDF2 mode:

`floor = sum_i 0.5*dz_i/h_n * (`

`|a0| spacing(theta_np1_i) + |a1| spacing(theta_n_i) + |a2| spacing(theta_nm1_i))`.

Use:

`effective_total_balance_tolerance = max(configured_total_balance_tolerance, floor)`.

No other convergence criterion changes.

## Step-ratio patterns

Use predefined periodic two-step patterns, normalized so each pair has mean step = base dt.

### R1 — constant

`[1.0, 1.0]`

local ratios: 1.0.

### R1P5 — mild variability

`[0.8, 1.2]`

alternating ratios: 1.5 and 2/3.

### R2 — moderate variability

`[2/3, 4/3]`

alternating ratios: 2.0 and 0.5.

### R3 — aggressive variability

`[0.5, 1.5]`

alternating ratios: 3.0 and 1/3.

No post-hoc ratio pattern is added.

## Refinement ladder

For every pattern use base pair scales:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Each level repeats its two-step pattern until the fixed horizon of 0.04 d is reached exactly.

Refinement halves both substeps, preserving the dimensionless step-ratio pattern.

## Physical bank

Reuse TIMEINT04 smooth fixed-flux bank:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Use fully implicit conductivity `SWKIMPL=1` through the already-qualified test-only explicit binding.

## Metrics

Per run:

- completion;
- final top/mid/bottom head;
- storage;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- work per accepted step.

Per case/pattern:

- refined top-head temporal order;
- storage spread;
- completion across all four refinement levels.

## Frozen qualification gates

A pattern qualifies only if:

1. 4/4 physical ladders complete;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. storage spread <=1e-10 cm in all 4 physical ladders;
5. median work per step <=1.5 times constant-step BDF2;
6. no nonfinite state or solver retry pathology.

The variable-step mechanism advances if:

- R1 qualifies;
- R1P5 qualifies;
- R2 qualifies.

R3 is exploratory boundary evidence and is not required to qualify.

If R2 fails but R1P5 passes, classify a bounded envelope with max adjacent step ratio 1.5.

If R2 passes, classify a bounded envelope with max adjacent step ratio 2.0.

If R3 also passes, do not automatically admit ratio 3.0; record it as evidence for a wider future envelope only.

## Preservation

R1 must match TIMEINT04 constant-step BDF2 endpoints and work to roundoff-scale bounds.

Required R1 endpoint differences versus constant-step authority:

- top/mid/bottom head <=1e-10 cm;
- storage <=1e-12 cm;
- identical completion status.

## Possible outcomes

- `VARIABLE_BDF2_RATIO2_MECHANISM_QUALIFIED`;
- `VARIABLE_BDF2_RATIO1P5_MECHANISM_QUALIFIED`;
- `CLOSED_VARIABLE_BDF2_NOT_QUALIFIED`.

## Production boundary

No production `src/**` change.

No adaptive controller is authorized in TIMEINT05.
