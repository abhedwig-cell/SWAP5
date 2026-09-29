# F-PE-ELASTIC19 — Staringreeks reference-state descriptor preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@57fba7961ed5a32679556653c6c4730d775623f2`

Parent authority:
- `F-PE-ELASTIC18_CLOSURE.md`;
- admitted ELASTIC17 horizon-node mapping;
- admitted ELASTIC16 descriptor assembly;
- admitted ELASTIC14 mineral-prior materializer;
- qualified ELASTIC13 reference state `h_ref=-100 cm`.

## Purpose

Add one stateless preprocessing adapter that constructs the ELASTIC16
per-node descriptor from source-bound Staringreeks retention parameters plus
already resolved dry bulk density and regime.

The adapter owns only:

`Staringreeks standard-MvG retention parameters + rho_dry + regime`
-> `theta_ref(h=-100 cm)`
-> `fmr_elastic_storage_descriptor_t`.

It does not:
- fetch BOFEK/BRO;
- select a profile or Staringreeks code;
- map horizons to nodes;
- infer regime;
- calculate ELAS;
- activate elasticity;
- change solver policy.

## Input contract

Inputs are already source-resolved:

- residual volumetric water content `wcr`;
- saturated volumetric water content `wcs`;
- MvG alpha `alpha_cm_inv`;
- MvG exponent `npar`;
- dry bulk density `rho_dry_g_cm3`;
- explicit ELASTIC14 regime code.

The Staringreeks conductivity parameters `lambda` and `ksfit` are not inputs
because ELASTIC19 evaluates retention only.

## Frozen reference state

`h_ref = -100 cm`.

This value is not selected in ELASTIC19. It is inherited unchanged from the
qualified ELASTIC13 physical policy.

## Frozen retention relation

ELASTIC19 uses the standard Mualem-van Genuchten retention form already used in
the ELASTIC12 transfer:

`m = 1 - 1/n`

`theta(h) = wcr + (wcs-wcr) / (1 + |alpha*h|^n)^m`.

At the frozen reference head:

`theta_ref = theta(-100 cm)`.

No near-saturation, entry-head, PDI, bimodal or tabulated extension is part of
this work unit.

## Existing-provider identity gate

To prevent a second divergent hydraulic interpretation, the ELASTIC19
retention calculation must be executable-identity checked against the admitted
`mod_b110_default_mvg_provider` in its equivalent ordinary standard-MvG
branch.

The comparison fixture constructs the provider with:
- row 1 = wcr;
- row 2 = wcs;
- row 4 = alpha;
- row 6 = n;
- row 7 = m;
- row 9 = 0 cm, so the ordinary MvG branch is selected;
- all unrelated rows bounded to valid inert values.

The provider is queried only for water content at `h=-100 cm`.

A disagreement is a blocker. ELASTIC19 may not independently redefine
retention semantics.

## Input validation

Fail closed when any are true:

- non-finite numeric input;
- `rho_dry_g_cm3 <= 0`;
- `wcr < 0`;
- `wcs <= wcr`;
- `wcs > 1`;
- `alpha_cm_inv <= 0`;
- `npar <= 1`;
- unknown regime integer;
- derived `m <= 0` or non-finite;
- derived `theta_ref` non-finite;
- `theta_ref < wcr` or `theta_ref > wcs`.

No clipping is allowed.

## Output contract

On success return:

`fmr_elastic_storage_descriptor_t`

with:
- `rho_dry_g_cm3` copied bit-identically from input;
- `theta_ref_cm3_cm3` equal to the frozen standard-MvG evaluation;
- `regime` copied unchanged.

Also return diagnostics:
- status;
- `theta_ref`;
- derived `m`;
- reference head.

## Qualification matrix

A1. representative mineral Staringreeks tuples produce finite descriptors at
h=-100 cm.

A2. ELASTIC19 `theta_ref` is bit-identical to the admitted default-MvG
provider in the equivalent ordinary standard-MvG branch.

A3. heterogeneous parameter tuples remain node-local and independent.

A4. invalid physical parameters fail closed without clipping.

A5. PEAT/high-organic/unknown regimes are copied faithfully; ELASTIC19 does not
change eligibility policy.

A6. descriptors produced by ELASTIC19 compose through admitted ELASTIC16 exactly
as manually constructed descriptors with the same `theta_ref`.

A7. a PEAT descriptor produced by ELASTIC19 is rejected downstream by admitted
ELASTIC16/14 generated-prior policy, proving regime ownership is preserved.

A8. O0/O2 identity.

A9. production source scope is exactly one new stateless adapter module; no
existing solver/runtime/kernel/legacy source is modified.

## Admission boundary

A green ELASTIC19 admits only source-resolved Staringreeks retention-to-
descriptor construction at the already qualified -100 cm reference state.

It does not admit:
- Staringreeks code lookup;
- BOFEK/BRO profile retrieval;
- location-to-profile selection;
- file syntax;
- automatic generated-prior request;
- any change to the physical reference state;
- any conductivity or capacity calculation.
