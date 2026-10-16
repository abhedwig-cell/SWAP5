# F-PE-MULTI04 P1A result — live candidate backend ownership

Date: 2026-09-27

Status: `PASS_CANDIDATE_BACKEND_OWNERSHIP`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised head: `3baa0e78e8793c81872c12615a3e0ad7d80a27b3`;
- workflow run: `36314902848`;
- job: `p1-candidate-backend-ownership`.

## Scope

P1A adds the production registry seam required before the application context may dispatch trials to worker-local mutable Reference backends.

The default registry binding remains unchanged.

Added behavior:
- `trial_from_origin_on_backend` may execute one participant trial on an explicit worker-local backend;
- after a successful trial, the registry records the exact backend that owns the live candidate;
- `discard_candidate` resolves the candidate on that recorded backend;
- `commit_candidate` commits on that recorded backend;
- ownership is cleared only after successful discard or commit;
- ordinary `trial_from_origin` uses the existing slot backend and therefore preserves the serial/default route.

No application-context parallel scheduling is admitted by P1A.

## Physical identity

PASS.

The test deliberately binds all participants to one serial authority backend, then executes worker trials through explicit alternate worker backends. Discard and commit are invoked only through the ordinary registry API.

Observed:
- q difference = 0;
- tangent difference = 0;
- discard leaves the registry quiescent;
- a live candidate created on an explicit worker backend commits successfully through ordinary `commit_candidate`.

## Scaling characterization

N=100:
- 2 workers: `1.768618x`;
- 4 workers: `2.257772x`.

N=1,000:
- 2 workers: `1.803610x`;
- 4 workers: `2.283571x`.

This is characterization of the P1A seam, not yet application-context admission.

## Existing registry authority

The independent F-VQ122 F-GC49B qualification passed on the P1A head.

The historical F-GC49B workflow failed in an unrelated compile-lineage defect:
`mod_fmr_drainage_response_binding.f90` imports `mod_drainage_extended_exchange.mod`, which the historical harness does not compile first.

Classification:
`HARNESS_COMPILE_LINEAGE_DEFECT`.

No MULTI04 production source is implicated by that failure.

## Decision

P1A closes:

`ADVANCE_TO_APPLICATION_CONTEXT_STATIC_PARALLEL`

The next step may wire worker-local backend storage into the real application context and enable deterministic static parallel trial dispatch for worker counts 2 and 4, while retaining the exact serial route for worker count 1.
