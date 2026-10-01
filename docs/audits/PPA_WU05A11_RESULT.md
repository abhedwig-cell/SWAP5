# PPA-WU05-A11 result — source-faithful FMR perched-zone carrier

Date: 2026-10-01

Status: `CORRECTED_QUALIFIED_FMR_PERCHED_CARRIER`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Corrected implementation checkpoint: `8ff742c6ba02bce9ecc745e83ef094ab9d5b59c6`

Corrected oracle checkpoint: `463c720e4d56ddd07c80f256cc7f984b26ca86d1`

Corrected qualification postimage: `867cafe3d9f50c712356d7bb40b78dbbad719b72`

Qualification run: `36838931487` — SUCCESS

## Exact-source correction

Subsequent A13 investigation re-read the exact SWAP 4.3.1 source and found that the first
A11 source translation was off by one compartment.

The exact active B1.11 assignment is:

`ICpTpPerZon = NPeGwl`

not `NPeGwl + 1`.

The apparent `+ 1` is after the Fortran comment marker and is not executable code.

Likewise, the nearby `ICpSatPeGwl` alternatives are historical commented code. Active
SATFLOW always applies the perched-level fraction in the top saturated compartment.

The implementation and A11 source oracle were corrected accordingly.

## Corrected qualified capability

A11 now qualifies:

- exact `CritUndSatVol` cumulative under-saturated-volume criterion;
- exact perched top/bottom level reconstruction;
- source-exact `ICpTpPerZon=NPeGwl` compartment mapping;
- source-exact SATFLOW top-compartment fraction;
- perched exclusion from unsaturated absorption;
- `QInIntSat` composition through the existing A6 saturated-exchange evaluator;
- recomputable runtime carrier with no new continuation state.

A direct corrected probe additionally demonstrated positive perched transfer:
`5.3846153846153863e-8 cm` in the bounded four-node fixture.

## Qualification evidence

Run `36838931487` passed both:

1. the corrected focused A11 source/carrier gate; and
2. the complete A7-A10 admitted macropore preservation gate.

The previous A11 run `36834246991` is explicitly superseded because it tested the
off-by-one implementation.

## Scope boundary

A11 remains a qualified research/follow-up capability, not a canonical production
admission.

It does not establish:

- serialized active perched production execution;
- inner-Richards macropore evaluation;
- canonical perched admission;
- covering-layer extension;
- dynamic crack feedback;
- RossFast;
- parallel MultiSWAP.

A13 subsequently falsified the bounded accepted-state-seed route for retaining transient
perched exchange in the existing outer fixed-point runtime. That result does not invalidate
the corrected A11 carrier equations.

## Decision

`CORRECTED_QUALIFIED_SOURCE_FAITHFUL_FMR_PERCHED_CARRIER`

The frozen Status-A denominator remains unchanged.
