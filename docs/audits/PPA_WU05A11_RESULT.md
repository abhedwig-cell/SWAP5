# PPA-WU05-A11 result — bounded RFM unponded activation service

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Qualified postimage:

    bf3e8424eccf271d943e03bfe16c76f97ff0bc08

Qualification run:

    36859780186 — SUCCESS

Focused gate output:

    PPA_WU05A11_RFM_UNPONDED_ACTIVATION=PASS

## Qualified scope

A11 promotes only the deterministic source-controlled activation/partition
operator to production source.

Inputs:

    explicit sigma_B > 0
    matrix conductivity K >= 0
    surface sorptivity S >= 0
    source rate R >= 0
    event age tau >= 0
    ponding depth >= 0

For unponded positive source:

    b50 = K + S/(2 sqrt(tau))

with tau bounded away from zero numerically by 1e-12 day inside the operator.

The frozen lognormal distributed-intake law then returns:

    matrix_rate
    preferential_rate
    preferential_fraction

with exact identity:

    source_rate = matrix_rate + preferential_rate

to floating-point tolerance.

## Independent oracle

The preregistered fixture:

    sigma_B = 0.65
    K = 0.16264 cm/day
    S = 2.92460 cm/sqrt(day)
    R = 4.8 cm/day
    tau = 0.25 day

reproduces:

    b50 = 3.08724
    matrix = 3.1439554598512593
    preferential = 1.6560445401487405
    fraction = 0.3450092791976543

within the focused 5e-13 tolerance.

## Fail-closed behavior

Qualified:

- positive ponding -> SURFACE_BOUNDARY_REQUIRED;
- sigma_B <= 0 -> INVALID;
- zero source -> AVAILABLE with zero matrix/preferential rates;
- all emitted rates remain bounded by source.

The frozen source-rate screen also preserves nondecreasing preferential fraction
for fixed K/S/tau.

## Architecture boundary

A11 changes no existing FMR runtime composition.

It does not:

- infer K or S from state;
- own event age;
- choose sigma_B;
- route preferential water;
- use f_MB, p or chi_wall;
- mutate committed/candidate state;
- alter restart payload;
- alter A8/A9/A10 behavior.

Therefore A11 is a reusable production process service, not yet a complete
alternative macropore execution mode.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
