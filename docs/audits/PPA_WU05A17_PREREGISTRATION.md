# PPA-WU05-A17 preregistration — bounded explicit-parameter RFM preferential routing

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@f71cccad728b4cc0dc515c449ac6a06a0de30716

Research authorities:

    F-MACRO-ALT26
    F-MACRO-ALT30
    F-MACRO-ALT34

## Purpose

Promote only the deterministic reduced RFM preferential-routing operator into
production source.

A17 does not map into existing SWAP macropore state.

## Inputs

The caller supplies explicitly:

    A15 surface-composition receipt
    f_MB in [0,1]
    p > 0
    Z_AH >= 0
    Z_IC > Z_AH
    endpoint depth upper bounds

No default value is supplied for f_MB or p.

The endpoint-depth array must:

    be strictly increasing
    have positive entries
    end at or below no shallower than Z_IC:
        last endpoint depth >= Z_IC

This keeps discretisation caller-owned.

## Frozen routing law

Let:

    a = preferential_supply / effective_supply

For the one-shape terminating connectivity:

    C(z)=1                        for z <= Z_AH
    C(z)=1-x^p                    for Z_AH < z < Z_IC
    C(z)=0                        for z >= Z_IC

where:

    x=(z-Z_AH)/(Z_IC-Z_AH).

The absolute active terminating-path survival is:

    S_active(z)=max(0, a-(1-C(z))).

Endpoint loss mass is the decline in S_active between successive explicit
endpoint bounds.

Normalised endpoint weights are the endpoint loss divided by a.

The preferential amount is split:

    MB = f_MB * preferential
    IC = (1-f_MB) * preferential

and IC is distributed over endpoint weights.

## Hard boundaries

A17 SHALL NOT:

- default or infer f_MB;
- default or infer p;
- derive Z_AH or Z_IC;
- introduce a fixed endpoint grid;
- mutate physical state;
- assign endpoints to current SWAP macropore domains;
- implement transit time;
- implement wall exchange;
- implement bottom breakthrough;
- use recovery to balance f_MB.

## Qualification oracle

Use:

    effective supply = 8
    preferential supply = 2
    f_MB = 0.2
    p = 1
    Z_AH = 20
    Z_IC = 100
    endpoints = [20,40,60,80,100] cm

Then:

    activation fraction = 0.25
    MB amount = 0.4
    IC amount = 1.6

For p=1 the active terminating survival falls from 0.25 to zero at 40 cm, so:

    endpoint weights = [0,1,0,0,0]
    endpoint amounts = [0,1.6,0,0,0]

and exact mass closure is:

    preferential = MB + sum(IC endpoints).

## Qualification gates

1. oracle above matches within 1e-12;
2. endpoint weights are nonnegative;
3. endpoint weights sum to 1 when IC input is positive;
4. exact total mass closure <= 1e-12;
5. zero preferential input yields all-zero route;
6. invalid f_MB fails closed;
7. invalid p fails closed;
8. non-increasing endpoint grid fails closed;
9. final endpoint shallower than Z_IC fails closed.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_PREFERENTIAL_ROUTER
    ROUTING_ORACLE_FALSIFIED
    MASS_CLOSURE_FALSIFIED
    TRUE_BLOCKER
