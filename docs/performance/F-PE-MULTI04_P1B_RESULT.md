# F-PE-MULTI04 P1B result — production application-context static parallel identity

Date: 2026-09-27

Status: `PASS_APPLICATION_CONTEXT_STATIC_PARALLEL_IDENTITY`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised head: `dba43a2ec3ae853682c498394ab9ef1960ca81a6`;
- workflow run: `36316230082`;
- job: `p1b-application-context-identity`.

## Scope

P1B qualifies the first real production application-context use of worker-local Reference backends.

Production behavior:
- worker count 1 retains the existing serial `trial_from_origin` path;
- worker counts 2 and 4 execute deterministic static worker-owned tile sequences;
- each worker uses one private mutable Reference backend;
- tile results are stored by canonical tile index;
- cell aggregation occurs only after the parallel trial phase and remains in canonical cell/tile order;
- live candidate backend ownership remains tracked by the registry from P1A.

P1B does not yet admit the MULTI03 bounded hybrid scheduler and makes no large-N performance claim.

## Production application-context identity

PASS.

The authority uses the existing F-GC49D application-context fixture and public production C API:
- capture origins;
- trial cell heads;
- obtain response tangents;
- discard candidates;
- abort prepublication;
- release context.

The same production context is executed with worker counts 1, 2 and 4.

Worker-count outputs are byte-numerically identical in the dedicated authority.

Reference values:
- cell q values:
  `-1.11792253113347007e-13`,
  `-1.11792253113347019e-13`;
- cell tangent values:
  `-3.93858335595060363e-06`,
  `-3.93858335595060363e-06`.

Qualification markers:
- `FPE_MULTI04_P1B_APPLICATION_CONTEXT_Q_IDENTITY=PASS`;
- `FPE_MULTI04_P1B_APPLICATION_CONTEXT_TANGENT_IDENTITY=PASS`;
- `FPE_MULTI04_P1B_APPLICATION_CONTEXT_DISCARD_ABORT=PASS`.

## Harness reconciliation

Three failures encountered before the final authority were classified as harness defects rather than candidate defects:

1. the historical F-GC49D compile list omitted the later admitted direct-retention provider;
2. after adding that provider, its direct-retention core dependency also had to be placed before it;
3. the temporary fixture path was accidentally propagated into the historical `git diff --check`, which rejects paths outside the repository.

The final MULTI04 harness repairs these issues only in its temporary research copy. Historical authority files and production physics were not changed for these repairs.

## Decision

P1B closes:

`ADVANCE_TO_LARGE_N_APPLICATION_CONTEXT_SCALING`

Next:
- measure the real production application-context path at sufficiently large N for 1/2/4 workers;
- require the frozen speed gates:
  - 2 workers >=1.5x;
  - 4 workers >=2.2x;
- preserve q/tangent identity and deterministic canonical aggregation;
- only after static production scaling is established proceed to bounded hybrid scheduling.
