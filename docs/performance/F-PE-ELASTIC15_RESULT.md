# F-PE-ELASTIC15 — explicit generated-prior application binding result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic15-explicit-prior-binding`

Qualified postimage:
`1db70d14af093d980ffbbae297c301801e232d60`

Workflow run:
`36555570006`

Job:
`109363772280`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90`.

No existing production source is modified.

The binding translates only an explicit application request plus already
materialized ELASTIC14 node priors into the admitted parameter contract.

## First-run negative result retained

The first qualification attempt exposed a real trap-safety defect in the new
binding.

Fortran does not guarantee short-circuit evaluation. A compound finite/value
predicate therefore evaluated a comparison on NaN and triggered SIGFPE.

The correction:
- changed finite/value tests to sequential fail-closed checks;
- changed no physical equation;
- changed no threshold;
- changed no ownership boundary.

The corrected persisted postimage is the one qualified here.

## A1 default-off identity

With `generated_prior_requested=.false.`:
- output parameters are identity copies;
- `elasticity_active` remains false;
- row 24 remains unchanged;
- prepared-cache availability remains unchanged.

The existing PPA-WU01 production application bootstrap gate also passes
unchanged.

Markers:
- `F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS`;
- `F_PE_ELASTIC15_A1_PPA_DEFAULT_OFF=PASS`.

## A2 heterogeneous node-local binding

With explicit request and three eligible MINERAL node priors:
- each node receives its own prior in `cofgen(24,i)`;
- `elasticity_active=.true.`;
- unrelated rows remain identity copies.

Marker:
`F_PE_ELASTIC15_A2_HETEROGENEOUS_BINDING=PASS`.

## A3 explicit/user ELAS ownership preservation

The binding rejects:
- already active ELAS;
- dormant non-zero row-24 values.

Neither case is overwritten.

Marker:
`F_PE_ELASTIC15_A3_EXPLICIT_CONFLICT=PASS`.

This preserves explicit/user ELAS as a higher-ownership existing parameter
source rather than silently replacing it with a generated prior.

## A4 atomic fail-closed eligibility

The whole binding is rejected if any active node has:
- unavailable prior;
- non-MINERAL regime;
- OUT_OF_DOMAIN classification;
- non-finite/non-positive prior;
- wrong prior count/parameter shape.

No partial row-24 binding survives.

Marker:
`F_PE_ELASTIC15_A4_FAIL_CLOSED=PASS`.

## A5 prepared-cache invalidation

When a generated prior is successfully bound:
- any existing `prepared_default_mvg_available` flag is invalidated;
- normal preparation must rebuild from the new parameter postimage.

Marker:
`F_PE_ELASTIC15_A5_CACHE_INVALIDATION=PASS`.

## A6 admitted application identity

A CI-only generated variant of the admitted ELASTIC09 application oracle:

1. starts with default-off row-24 parameters;
2. materializes heterogeneous MINERAL priors through ELASTIC14;
3. binds them through ELASTIC15;
4. runs the normal application bootstrap;
5. compares against direct serialized execution from the same bound typed
   parameters.

Results:
- application bootstrap PASS;
- heterogeneous ELAS preparation PASS;
- committed state PASS;
- mass closure PASS;
- application/direct serialized identity PASS;
- existing ELASTIC09 fail-closed composed-option gates PASS.

Marker:
`F_PE_ELASTIC15_A6_APPLICATION_IDENTITY=PASS`.

## A7 optimization identity

Both focused binding and application integration pass O0/O2 identity.

Markers:
- `F_PE_ELASTIC15_A7_BINDING_O0_O2=PASS`;
- `F_PE_ELASTIC15_A7_APPLICATION_O0_O2=PASS`.

## A8 source scope

Production delta is exactly:

`src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90`.

No other `src/**` file changes.

Marker:
`F_PE_ELASTIC15_A8_SOURCE_SCOPE=PASS`.

## Admitted-boundary candidate

The candidate adds explicit opt-in application binding only.

It does not:
- fetch BOFEK/BRO;
- compute ELASTIC14 priors;
- select reference moisture state;
- auto-bind peat/high-organic priors;
- define file-parser syntax;
- make generated priors default-on;
- overwrite explicit/user ELAS;
- alter solver or timestep policy.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
