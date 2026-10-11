# F-PE-ELASTIC15 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@58e2d3b24abeafdd7aaf09ee4bf6b7ef0d19050c`

Merged PR:
`#792`

Admitted production file:
`src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90`

Admitted production blob:
`1a4827e8e9f5d789cc83237dd1c9e9eaaec4b2a6`

## Admission summary

F-PE-ELASTIC15 admits an explicit application-level binding from already
materialized ELASTIC14 MINERAL priors into the existing admitted ELAS runtime
contract:

`resolved generated priors + explicit request`
-> `elasticity_active + cofgen(24,:)`
-> ELASTIC08 runtime materialization
-> ELASTIC05 constitutive ELAS
-> ELASTIC09 production bootstrap.

The binding does not discover or fit ELAS.

It only applies already qualified priors to a copied application parameter
postimage under explicit opt-in.

## Clean current-canonical qualification

Clean extraction:

`work/f-pe-elastic15-current-clean-admission-v2@7bf06a31659973c7174084211e17bdcb9ded9797`

Result-document head:

`8b6aec3b8ff6e3947ae2927bb7ee0496d45acbc8`

Extraction base:

`integration/f-ci-canonical@c3207db3a95ac120c133f130ecfa328963ebfe29`

Qualification:
- workflow run `36557311500`;
- job `109369460919`;
- conclusion SUCCESS.

Named gates:
- A1 default-off identity: PASS;
- PPA-WU01 default-off preservation: PASS;
- A2 heterogeneous node-local binding: PASS;
- A3 explicit/user ELAS conflict preservation: PASS;
- A4 atomic fail-closed eligibility: PASS;
- A5 prepared-default-MvG cache invalidation: PASS;
- A6 ELASTIC09 application/direct-runtime identity: PASS;
- A7 O0/O2 identity: PASS;
- A8 production source scope: PASS.

## Blob identity

The admitted canonical production blob is exactly the same as the clean
qualification blob:

`1a4827e8e9f5d789cc83237dd1c9e9eaaec4b2a6`.

No production source changed between the clean qualification postimage and
canonical admission.

## Admitted ownership semantics

### Default OFF

When generated priors are not explicitly requested:
- output parameters remain identity copies;
- row 24 remains unchanged;
- ELAS remains inactive.

### Explicit/user ELAS

Existing explicit/user ELAS has higher ownership.

If the base parameter set already contains:
- active ELAS; or
- nonzero dormant row-24 values;

generated-prior binding fails closed.

No generated prior may silently overwrite those values.

### Generated MINERAL prior

On explicit generated-prior request:
- one eligible prior is required per active node;
- every prior must be available;
- every prior must be MINERAL;
- every prior must remain IN_DOMAIN or EDGE;
- every prior value must be finite and positive.

The whole binding is atomic.

One invalid/non-mineral/out-of-domain node rejects the entire generated
binding. No mixed partial assignment survives.

## Prepared-cache ownership

Successful binding invalidates any existing
`prepared_default_mvg_available` view.

Normal preparation must therefore rebuild from the bound parameter postimage.

This prevents stale pre-ELAS hydraulic preparation from surviving after row 24
has changed.

## Relationship to user/source-selection policy

A generic runtime user-vs-generated source selector is **not** admitted by
ELASTIC15.

The admitted design is deliberately narrower:

- source choice remains an application/preprocessing concern;
- generated priors require explicit application request;
- runtime binding refuses to overwrite existing explicit/user ELAS.

An earlier exploratory generic source-selection branch is therefore
superseded for production admission by this stricter binding design.

## Production boundary

Still not admitted:
- input-file/parser syntax for generated priors;
- automatic BOFEK/BRO lookup inside SWAP runtime;
- automatic generated-prior request from soil identity;
- automatic peat/high-organic assignment;
- mixed generated/user source resolution inside one column;
- state-dependent ELAS constitutive behavior;
- solver-performance tuning of physical ELAS;
- replacement of explicit user ELAS.

## Preserved authority

Unchanged:
- ELASTIC05 constitutive semantics;
- ELASTIC08 runtime materialization;
- ELASTIC09 production bootstrap;
- ELASTIC14 mineral-prior materializer;
- default-off behavior;
- Full Richards reference path;
- mass and transaction semantics.

## Closure

F-PE-ELASTIC15 is canonically admitted and closed.

There is no remaining production-software action in this work unit.

A future work unit may define input/preprocessing syntax or application
orchestration that explicitly requests generated priors, but it must preserve
the ownership and fail-closed boundary admitted here.
