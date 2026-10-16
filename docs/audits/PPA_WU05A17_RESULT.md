# PPA-WU05-A17 result — explicit-parameter RFM preferential router

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@f71cccad728b4cc0dc515c449ac6a06a0de30716

Qualified postimage:

    9d4c247666c9641aa1c29f835187dcd4c2afcdbb

Qualification run:

    36865436660 — SUCCESS

Focused gate output:

    PPA_WU05A17_RFM_PREFERENTIAL_ROUTER=PASS

## Qualified operator

A17 promotes only the deterministic reduced RFM preferential-routing operator.

Inputs remain explicit:

    A15 surface-composition receipt
    f_MB
    p
    Z_AH
    Z_IC
    endpoint depth upper bounds

No default f_MB, p or endpoint discretisation is admitted.

The routing law is the qualified one-shape survival:

    C(z)=1-x^p

with activation-weighted endpoint recruitment.

## Qualification oracle

For:

    effective supply = 8
    preferential supply = 2
    activation = 0.25
    f_MB = 0.2
    p = 1
    Z_AH = 20 cm
    Z_IC = 100 cm
    endpoint bounds = [20,40,60,80,100] cm

the service reproduces:

    MB = 0.4
    IC = 1.6
    endpoint weights = [0,1,0,0,0]
    endpoint amounts = [0,1.6,0,0,0]

with exact closure to the focused tolerance.

## Qualified guards

- endpoint weights nonnegative;
- endpoint weights sum to one for positive IC route;
- total preferential mass closes;
- zero preferential supply gives zero route;
- invalid f_MB fails closed;
- invalid p fails closed;
- non-monotone endpoint grid fails closed;
- final endpoint shallower than Z_IC fails closed.

## Architecture boundary

A17 does not:

- map endpoints into current SWAP macropore domains;
- mutate fast-domain state;
- implement wall exchange;
- implement transit time;
- implement bottom breakthrough;
- infer or calibrate f_MB/p;
- alter current A8/A9/A10 behavior.

It is a production-grade routing receipt, not yet a live fast-domain runtime.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
