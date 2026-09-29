# F-PE-ELASTIC14 — mineral ELAS prior materializer result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic14-mineral-prior-materializer`

Qualified clean production postimage:
`02fc46ad51b804e1b1de9604d48c0e38963a8a72`

Clean extraction base:
`integration/f-ci-canonical@ab151e5dcc3054f8be2bc0d7a25f905e44395f96`.

The clean extraction contains only the bounded ELASTIC13 authority documents,
ELASTIC14 documentation/tests/workflow and the single new production module.

Workflow run:
`36554278578`

Job:
`109359574070`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_prior_policy.f90`.

No existing production source is modified.

The new module:
- materializes only a physical ELAS prior object;
- does not set `elasticity_active`;
- does not write `cofgen(24,:)`;
- performs no external data access;
- performs no BOFEK lookup;
- performs no retention calculation;
- performs no solver/runtime tuning.

## Frozen mineral policy

Inputs:
- dry bulk density [g/cm3];
- volumetric water content at the already selected reference state;
- explicit regime code.

Reference state remains:
`h=-100 cm`.

For MINERAL only, the module evaluates the exact frozen ELASTIC11 M1 relation
and returns:
- prior value;
- factor-2.123968031921196 lower/upper uncertainty envelope;
- frozen reference head;
- reconstructed wet density and gravimetric water content;
- predictor z-scores;
- predictor-domain class.

## A1 formula identity

Focused production-module oracle:

`rho_dry=1.454 g/cm3`

`theta_ref=0.36 cm3/cm3`

gives:

`ELAS_prior=2.7124308428813305e-6 cm^-1`.

O0 and O2 produce identical output.

Markers:
- `F_PE_ELASTIC14_A1_FORMULA=PASS`;
- `F_PE_ELASTIC14_PRIOR_ORACLE=PASS`.

## A2 uncertainty

The materializer preserves exact ordering:

`lower < prior < upper`

with both ratios equal to the frozen independent-holdout uncertainty factor.

Marker:
`F_PE_ELASTIC14_A2_UNCERTAINTY=PASS`.

## A3 non-mineral fail-closed policy

The following explicit regimes return
`FMR_ELAS_PRIOR_NOT_AUTO_ASSIGNED` and an unavailable prior:

- ORGANIC_RICH_NONPEAT;
- PEAT;
- UNKNOWN.

Marker:
`F_PE_ELASTIC14_A3_NONMINERAL=PASS`.

## A4 invalid/out-of-domain fail closed

Rejected:
- non-positive dry density;
- negative theta;
- theta > 1;
- non-finite input;
- predictor values outside the frozen 3-sigma domain.

No available prior survives these cases.

Marker:
`F_PE_ELASTIC14_A4_FAIL_CLOSED=PASS`.

## A5 default-off preservation

The admitted PPA-WU01 production application bootstrap gate was replayed
unchanged.

Result:
PASS.

Marker:
`F_PE_ELASTIC14_A5_DEFAULT_OFF=PASS`.

Therefore merely linking the materializer introduces no ELAS activation.

## A6 explicit application bridge

A CI-only generated copy of the already qualified ELASTIC09 application oracle
was used.

The only semantic fixture change was:
- call the new ELASTIC14 materializer for a qualified MINERAL case;
- deliberately copy the returned scalar into row 24;
- keep explicit `elasticity_active=.true.`.

The existing ELASTIC09 application-vs-direct serialized runtime identity passed
again at O0 and O2, including:
- committed state;
- solver counters;
- mass ledger;
- accepted physical state;
- fail-closed composed-option gates.

Markers include:
- `F_PE_ELASTIC14_A6_BRIDGE_IDENTITY=PASS`;
- `F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS`.

This establishes that the new materializer feeds the already admitted ELAS
route without changing runtime semantics.

## A7 optimization identity

Both:
- focused prior oracle;
- generated-prior application oracle

passed O0/O2 identity.

Markers:
- `F_PE_ELASTIC14_A7_PRIOR_O0_O2=PASS`;
- `F_PE_ELASTIC14_A7_APPLICATION_O0_O2=PASS`.

## A8 source scope

Observed production delta:

`src/runtime/mod_fmr_elastic_storage_prior_policy.f90`

and no other `src/**` file.

Marker:
`F_PE_ELASTIC14_A8_SOURCE_SCOPE=PASS`.

## Scientific boundary

ELASTIC14 does not:
- auto-activate elasticity;
- auto-load BOFEK data;
- assign peat/high-organic ELAS;
- define a new parser keyword;
- remove explicit user ELAS;
- change solver numerics;
- claim the generated prior is measured truth.

The materializer transports the already qualified mineral physical policy into a
production-shaped typed helper.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
