# F-PE-ELASTIC15 — explicit generated-prior application binding result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic15-current-clean-admission-v2`

Qualified postimage:
`7bf06a31659973c7174084211e17bdcb9ded9797`

Current-canonical extraction base:
`integration/f-ci-canonical@c3207db3a95ac120c133f130ecfa328963ebfe29`.

Workflow run:
`36557311500`

Job:
`109369460919`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90`.

No existing production source is modified.

The binding translates only:
- an explicit application request;
- already materialized ELASTIC14 node priors;

into the admitted parameter contract.

## A1 default-off identity

With `generated_prior_requested=.false.`:
- output parameters equal input parameters;
- `elasticity_active` remains false;
- row 24 remains unchanged;
- prepared-cache availability remains unchanged.

PPA-WU01 also passes unchanged.

Markers:
- `F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS`;
- `F_PE_ELASTIC15_A1_PPA_DEFAULT_OFF=PASS`.

## A2 heterogeneous node-local binding

With explicit request and eligible MINERAL priors:
- each active node receives its own prior in `cofgen(24,i)`;
- `elasticity_active=.true.`;
- unrelated rows remain identity copies.

Marker:
`F_PE_ELASTIC15_A2_HETEROGENEOUS_BINDING=PASS`.

## A3 explicit/user ELAS ownership preservation

The binding fails closed when:
- ELAS is already active; or
- dormant row-24 values are already nonzero.

Existing explicit/user values are never overwritten.

Marker:
`F_PE_ELASTIC15_A3_EXPLICIT_CONFLICT=PASS`.

## A4 atomic fail-closed behavior

The entire generated-prior binding is rejected if any active node has:
- unavailable prior;
- non-MINERAL regime;
- OUT-domain classification;
- non-finite/non-positive prior;
- invalid prior count or parameter shape.

No partial assignment survives.

Marker:
`F_PE_ELASTIC15_A4_FAIL_CLOSED=PASS`.

## A5 prepared-cache invalidation

Successful binding invalidates an already available prepared-default-MvG cache
so the normal preparation path reconstructs from the new typed parameter
postimage.

Marker:
`F_PE_ELASTIC15_A5_CACHE_INVALIDATION=PASS`.

## A6 admitted application identity

A CI-only generated variant of the admitted ELASTIC09 application oracle:

1. starts from default-off parameters;
2. materializes heterogeneous MINERAL priors through ELASTIC14;
3. binds them through ELASTIC15;
4. runs normal production application bootstrap;
5. compares against direct serialized execution from the same bound typed
   parameters.

The following remain preserved:
- application bootstrap;
- heterogeneous ELAS preparation;
- committed state;
- mass closure;
- application/direct serialized identity;
- existing ELASTIC09 fail-closed composed-option gates.

Marker:
`F_PE_ELASTIC15_A6_APPLICATION_IDENTITY=PASS`.

## A7 O0/O2 identity

Both focused binding and full application integration pass O0/O2 identity.

Markers:
- `F_PE_ELASTIC15_A7_BINDING_O0_O2=PASS`;
- `F_PE_ELASTIC15_A7_APPLICATION_O0_O2=PASS`.

## A8 source scope

Production delta is exactly:

`src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90`.

No other `src/**` file changes.

Marker:
`F_PE_ELASTIC15_A8_SOURCE_SCOPE=PASS`.

## Ownership interpretation

This admission candidate deliberately does **not** implement a general
user-vs-generated source selector inside runtime.

Instead:
- an explicit/user ELAS configuration remains higher-ownership and blocks
  generated-prior binding;
- generated priors are applied only through an explicit application request;
- mixed mineral/peat columns fail closed as a whole in this work unit;
- no automatic BOFEK/BRO lookup or parser behavior is introduced.

This keeps source choice outside the runtime binding and prevents generated
priors from silently replacing user-owned physical parameters.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
