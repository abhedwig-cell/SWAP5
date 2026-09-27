# F-PE-MULTI04 closeout — production application-context worker-local groundwater parallel admission

Date: 2026-09-27

Status: `CLOSED_PRODUCTION_PARALLEL_ADMITTED`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Branch:
`work/f-pe-multi04-production-groundwater-parallel-admission`

Canonical base at closeout preparation:
`integration/f-ci-canonical@cda49c018e7b56416f992c11d43f1909e78a0f22`

Qualified code head:
`26353c45d5eee6388264bc1aeecd0be35578ec13`

Closeout documentation head before this file:
`56ccff5450616f7af84e72ada366814c5295ae52`

## Closure decision

F-PE-MULTI04 closes as:

`CLOSED_PRODUCTION_PARALLEL_ADMITTED`

The admitted scope is bounded:

- default production groundwater worker count remains 1;
- worker count 1 remains on the pre-existing serial trial route;
- only groundwater mode 5 may request worker counts 2 or 4;
- unsupported worker counts fail closed;
- non-groundwater parallel requests fail closed;
- worker counts 2 and 4 use worker-local mutable Reference backends;
- production scheduling follows the frozen MULTI03 bounded deterministic hybrid rule;
- result storage, aggregation and publication remain canonical-order deterministic.

No physics or coupling concession is part of this admission.

## Qualification ledger

### P0 — production worker ownership/configuration

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P0_RESULT.md`

Established:
- default worker count = 1;
- worker-local backend pools for 2 and 4;
- unsupported counts fail closed;
- non-groundwater parallel requests fail closed;
- production owner close releases worker-local storage.

### P1A — live candidate backend ownership

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P1A_RESULT.md`

Established:
- explicit backend trial seam;
- candidate backend ownership is recorded;
- discard resolves through the producing backend;
- commit resolves through the producing backend;
- candidate ownership is cleared only after successful discard/commit;
- default serial registry route remains unchanged.

### P1B — production application-context identity

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P1B_RESULT.md`

Established exact worker 1/2/4 production application-context identity for q and tangent and clean discard/abort.

### P1C — production TEMPORAL08 scaling

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P1C_RESULT.md`

Measured median at N=1000:
- 1 worker: 0.097694413 s;
- 2 workers: 0.049966367 s;
- 4 workers: 0.036203590 s.

Speedup:
- 2 workers: 1.955203x;
- 4 workers: 2.698473x.

Frozen gates:
- 2 workers >=1.5x PASS;
- 4 workers >=2.2x PASS.

Exact aggregate checksums:
- q = 2.63219253438378203e-05;
- tangent = -1.46925912412419323e-02.

### P2 — bounded hybrid production scheduling

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P2_RESULT.md`

Workflow:
- run `36318282587`;
- job `p2-hybrid-production-scheduling`;
- job id `108617039264`;
- completed successfully.

The production harness enforces, and the green job therefore proves:
- q exact identity;
- tangent exact identity;
- STATIC selection for the balanced ordering;
- COST_AWARE selection for the adverse ordering;
- selected predicted max/mean load <=1.20;
- 2-worker speedup >=1.5x;
- 4-worker speedup >=2.2x;
- selected runtime <=1.02 * static runtime.

No frozen threshold was relaxed.

### P3/P4 — live worker-4 MODFLOW6

PASS.

Authority:
`docs/performance/F-PE-MULTI04_P3P4_RESULT.md`

Workflow:
- run `36318282587`;
- job `p3p4-live-worker4`;
- job id `108617039453`;
- completed successfully.

The live authority requires for worker 1 and worker 4:
- TEMPORAL08 live production bootstrap PASS;
- exactly-once publication PASS;
- MODFLOW6 6.8.0 PASS;
- SWAP-to-ledger publication PASS;
- exact identity of coupling iteration count;
- exact identity of maximum cell residual.

Therefore live worker-4 coupling, publication and ledger semantics are preserved.

## Preservation gates

### PPA-WU01

PASS on the qualified code head.

Workflow:
- run `36318282438`;
- job `owner-qualification`;
- job id `108617038706`;
- conclusion `success`.

This preserves the production application owner/lifetime authority.

### F-CI canonical qualification

PASS on the qualified code head.

Workflow:
- run `36318282583`;
- conclusion `success`.

All jobs in the returned canonical qualification run completed successfully, including:
- historical F-CI03 through F-CI18;
- F-CI19 candidate preservation;
- F-CI19 source lineage;
- F-CI24;
- F-CI27;
- F-CI28;
- F-CI29;
- F-CI30;
- F-CI31;
- F-CI34;
- F-CI36;
- F-CI37;
- F-CI39;
- F-CI40;
- current restricted canonical preservation.

## Ownership, leakage and deterministic-order audit

Production code retains the following invariants:

1. Worker count 1 uses the original serial `trial_from_origin` path.
2. Parallel workers each own one private mutable Reference backend.
3. Participant accepted-origin and committed state remain tile-local.
4. Live candidate backend ownership is explicit in the registry.
5. Candidate discard and commit are routed to the exact producing backend.
6. Parallel trial outputs are written to canonical tile-index slots.
7. Aggregation occurs only after the parallel phase, in canonical cell/tile order.
8. Equal-cost scheduler ties use canonical tile index.
9. Equal worker-load scheduler ties resolve to the lowest deterministic worker index.
10. Failure of any parallel tile trial triggers candidate cleanup and zeroes the returned aggregate flux vector before failure return.
11. Production-owner close deallocates worker-local backend storage and resets the configured worker count to 1.

No state, candidate or worker-backend lifetime is transferred across production ownership boundaries.

## Exactly-once commit/publication audit

The admitted parallel path changes trial execution only.

It does not introduce a second commit or publication path.

The live P3/P4 authority reuses the TEMPORAL08 production publication lifecycle and requires:
- exactly-once SWAP publication;
- live SWAP ledger publication;
- successful worker-1 and worker-4 completion;
- identical live coupling diagnostics.

Therefore worker-local parallel trial execution does not duplicate candidate commit, SWAP publication or ledger publication.

## Frozen semantics preserved

MULTI04 does not alter:

- Richards equations;
- c = 0.65 history-aware temporal-budget coefficient;
- temporal floor = 1e-5 cm;
- BALTOL02;
- retry scale;
- nonlinear tolerances;
- tangent mathematics;
- MODFLOW equations;
- participant accepted-origin ownership;
- candidate lifecycle semantics;
- canonical result/publication order.

## Admission boundary

Admitted:
- production groundwater mode-5 worker counts 2 and 4;
- deterministic STATIC scheduling when predicted static load ratio <=1.20;
- deterministic COST_AWARE scheduling when the ratio >1.20;
- worker-local mutable Reference backend execution.

Retained as default:
- worker count 1;
- original serial production route.

Not admitted:
- arbitrary worker counts;
- non-groundwater parallel execution;
- relaxed physics/tolerances;
- changed temporal coefficient/floor;
- changed MODFLOW or publication semantics.

## Final status

`F-PE-MULTI04 = CLOSED_PRODUCTION_PARALLEL_ADMITTED`

Merge is permitted only from a freshly fetched PR head with the relevant post-documentation checks green and with canonical still reconciled.
