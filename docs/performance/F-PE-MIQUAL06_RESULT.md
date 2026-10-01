# F-PE-MIQUAL06 result — serialized runtime moving-interface manager seam

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`

Qualification authority:

- workflow run: `36824274774`;
- job: `110246344924`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Qualified branch postimage before result persistence:

`work/f-pe-miqual06-serialized-runtime-manager-seam@a2c8e0aae70793e402e11c4aa89abbf29968cb7a`

Earlier invalid executions are preserved in `F-PE-MIQUAL06_EXECUTION_CORRECTION.md` and are not qualification authority.

## Aggregate result

The previously admitted moving-interface manager is now wired into the normal serialized-reference runtime behind an explicit execution-ready profile.

Classification:

`QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`.

## Default boundary

The default/unconfigured serialized runtime remains on the existing full Richards route.

Observed default trial:

- manager requested: false;
- status: completed;
- candidate published;
- solver converged;
- one attempt;
- no temporal, mass, solver or admission rejection.

No implicit activation from saturation occurs.

## Explicit manager route

With an execution-ready moving-interface profile and an eligible saturated-tail state:

- full node count: 16;
- active reduced node count: 13;
- manager route: reduced;
- serialized transaction completes;
- full-shape candidate is published;
- solver converges;
- no fallback is used;
- nonlinear iterations: 1;
- Jacobian builds: 1;
- linear solves: 1.

The focused gate also compares the default full and manager candidate states under the frozen equilibrium fixture and finds pressure head, water content and ponding identical within 1e-12.

## Typed full bypass

With the manager explicitly requested but an ineligible unsaturated state:

- serialized transaction completes;
- exact full route is used;
- manager route reports `FULL_BYPASS`;
- typed reason: `reduced-view-ineligible`;
- no fallback is reported.

Thus manager request does not make an unsupported state invalid.

## Preserved manager seam

The qualification reruns the existing Z43F seam smoke:

- default profile remains invalid/not manager-selected;
- legacy profile remains execution-ready;
- manager selection remains explicit;
- reduced view uses n=13 from full n=16;
- full candidate materialization remains full shaped;
- forced full fallback remains present;
- full bypass remains present;
- failed reduced trial does not leak to accepted state.

Observed Z43F aggregate:

`QUALIFIED_Z43F_MANAGER_SEAM_READY`.

## Runtime integration boundary

The new serialized runtime adapter is intentionally eligible only for the frozen basic Richards envelope:

- reference Richards;
- no RossFast;
- no macropore;
- no trajectory-direction side service;
- no root extraction;
- no drainage response;
- no snow/soil-temperature/Black/Boesten/fixed-weir process;
- no direct-retention route;
- SWKIMPL=0;
- conductivity mean method 1;
- explicit fixed-flux top;
- fixed-flux bottom with qbot=0;
- zero source/sink arrays;
- contiguous saturated tail.

Everything outside this envelope remains exact full bypass.

## Architectural result

The canonical Z43F capability was previously a manager/profile seam. MIQUAL06 establishes the missing production-runtime composition:

- explicit profile selection reaches the serialized execution callsite;
- reduced scratch/workspace is runtime-local;
- accepted full-column state remains sole physical authority;
- rematerialization happens before publication;
- exact full fallback/bypass remains available;
- transaction/commit ownership remains outside the manager;
- manager scratch is not committed or rollback state.

## Qualified claim boundary

Qualified:

- serialized-reference runtime selection seam;
- default-off preservation;
- eligible reduced route;
- typed ineligible full bypass;
- full-shape publication;
- equilibrium physical identity;
- preservation of existing Z43F manager/fallback/rollback smoke.

Not qualified:

- broad optional-process eligibility;
- dynamic-top use through the serialized manager seam;
- production-default replacement;
- whole-SWAP wall-clock speedup;
- MultiSWAP throughput improvement.

## Consequence

Proceed to:

`F-PE-MIQUAL07 — production-shaped end-to-end LEGACY versus moving-interface serialized-runtime benchmark`.

MIQUAL07 must measure the actual serialized transaction/runtime route rather than the earlier research trajectory harness.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
