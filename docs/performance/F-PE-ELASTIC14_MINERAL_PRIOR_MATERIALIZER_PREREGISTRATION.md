# F-PE-ELASTIC14 — production-shaped mineral ELAS prior materializer preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`research/f-pe-elastic13-parameter-policy@65c2163324bcc112a8149e5aab786b1342e58b89`

Canonical reconciliation:
`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`

Parent authority:
- `F-PE-ELASTIC13_CLOSEOUT.md`;
- admitted ELASTIC05/08/09 production chain.

## Purpose

Add the smallest production-shaped materializer for the qualified MINERAL ELAS
prior policy.

This work unit does not change the Richards solver, application bootstrap,
parser, activation default, timestep policy or physical acceptance criteria.

## Ownership boundary

The materializer may compute a prior object from already resolved layer
properties.

It may not:
- set `elasticity_active`;
- write `cofgen(24,:)`;
- infer a BOFEK profile;
- fetch external data;
- classify peat from MvG parameters;
- choose a reference head;
- tune any value from solver behavior.

The caller remains responsible for explicitly applying the returned prior to the
already admitted ELASTIC08/09 row-24 route.

## Input contract

Inputs:

- dry bulk density `rho_dry_g_cm3`;
- volumetric water content at the frozen reference state
  `theta_ref_cm3_cm3`;
- explicit regime code.

Frozen reference state:
`h_ref=-100 cm`.

The materializer does not evaluate the retention curve itself. This preserves
separation between soil-data preprocessing and runtime physical-parameter
ownership.

## Regime codes

Public typed constants:

- MINERAL;
- ORGANIC_RICH_NONPEAT;
- PEAT;
- UNKNOWN.

Only MINERAL is eligible for generated automatic prior materialization.

All other regimes return an explicit `NOT_AUTO_ASSIGNED` status and an
unavailable prior.

## Frozen calculation

For MINERAL:

`rho_wet = rho_dry + theta_ref`

`water_pct = 100 * theta_ref / rho_dry`

`z_rho = (rho_wet - 1.4337873737373736) / 0.34422692442216535`

`z_w = (water_pct - 191.8190909090909) / 182.02868188688447`

`log10(ELAS) =
 -5.144312248981006
 -0.25581251314464676 * z_rho
 +0.15229775506831100 * z_w`

`ELAS = 10**log10(ELAS)`.

Frozen uncertainty factor:

`F=2.123968031921196`.

Output:
- prior value;
- lower = prior/F;
- upper = prior*F;
- reference head = -100 cm;
- domain classification;
- available flag.

## Domain gate

- IN_DOMAIN when max(|z|) <= 2;
- EDGE when 2 < max(|z|) <= 3;
- OUT_OF_DOMAIN when max(|z|) > 3.

OUT_OF_DOMAIN is fail closed and must not produce an available prior.

## Input validation

Fail closed on:
- non-finite inputs;
- dry density <= 0;
- theta_ref < 0;
- theta_ref > 1;
- unknown regime integer;
- non-finite derived predictor or ELAS.

## Qualification matrix

The production postimage must pass:

A1. exact formula identity on representative mineral cases spanning low,
median and high dry density / water state;

A2. MINERAL IN_DOMAIN and EDGE produce finite positive prior and uncertainty
ordering `lower < prior < upper`;

A3. PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN return NOT_AUTO_ASSIGNED and no
available prior;

A4. invalid/non-finite input and OUT_OF_DOMAIN fail closed;

A5. default-off preservation: merely linking or constructing the materializer
must not change application ELAS activation or row-24 values;

A6. explicit bridge identity: when a qualified prior is deliberately copied by
a test caller into `cofgen(24,:)` and `elasticity_active=.true.`, the existing
ELASTIC09 application route remains bit-identical to the same direct scalar
configuration;

A7. O0/O2 identity;

A8. production source scope is exactly one new module and no existing
production source is modified.

## Production boundary

A green ELASTIC14 authorizes a reusable physical-prior materializer only.

It does not authorize:
- default-on elasticity;
- automatic BOFEK lookup inside SWAP runtime;
- automatic peat assignment;
- a new input-file keyword;
- removal of explicit user ELAS;
- automatic activation from a generated prior.

Those remain separate application/input-policy decisions.
