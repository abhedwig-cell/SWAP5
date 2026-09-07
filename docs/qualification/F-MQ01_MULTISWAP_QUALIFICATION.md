# F-MQ01 MultiSWAP Qualification Matrix and reuse assessment

Status: `QUALIFICATION_BASELINE_ESTABLISHED / PRODUCTION_INTEGRATION_NOT_CLAIMED`

## 1. Scope

F-MQ01 establishes qualification infrastructure only. It does not change the production kernel, solver physics, numerical policy or a production MultiSWAP runtime.

The authoritative machine-readable matrix is:

`tests/multiswap/qualification_matrix.json`

Its structural gate is:

`tests/multiswap/test_qualification_matrix.py`

F-CI remains the authority for the canonical SWAP5 production baseline. A test using real SWAP5 source must pin an exact source commit. Historical A23 source, patches, reports and tests are reusable only in their explicitly qualified role.

## 2. Pins used by F-MQ01

Qualification host at creation:

- repository: `abhedwig-cell/SWAP5`
- branch observed: `main`
- exact commit: `fafeebdece209abcc320b24a3c8c2757800b2e0e`

Historical transactional reuse source:

- branch: `integration/a23bk-transactional-rebase`
- exact commit: `763f276a96ee1722a465bacd3a710172a5f38107`
- role: qualified test/evidence source only, not canonical production baseline

Corrected legacy reference observed on the qualification host pin:

- snapshot: `B1.10`
- manifest: `reference/swap-4.3.1/snapshots/B1.10.yml`
- reconstruction tool: `tools/vq/b1_10_reconstruct.py`

This observation does not supersede F-CI's responsibility to define the canonical integration baseline.

## 3. Qualification layers

### MQ-T0: runtime contracts

Purpose: falsify runtime logic cheaply with a deterministic testdouble. No real SWAP physics is required.

Primary claims: column identity, template classification, partition coverage, dispatch, queueing, ordering, aggregation and replay.

Typical scale: 1 to 32 columns. Non-power-of-two cases such as 17 are deliberate.

Target frequency: every commit once the test-only scheduler seam exists.

### MQ-T1: short real-SWAP transactions

Purpose: qualify physical continuation and transaction semantics where a testdouble is insufficient.

Primary claims: committed state, checkpoint, rejected trial, rollback, retry, commit, deterministic replay, per-column mass accounting and worker scratch isolation at the physical seam.

Typical scale: 1 to 8 columns and a short reference-derived continuation interval.

These tests must not bootstrap a long legacy run on every execution once event-local fixtures are available.

### MQ-T2: MultiSWAP isolation and concurrency

Purpose: prove that runtime organization cannot change a column's physical or diagnostic result.

Primary claims: single versus MultiSWAP equivalence, execution-order independence, worker-count independence, batch partition independence, cross-column isolation, forcing locality, diagnostics aggregation, interleaving and scratch poisoning.

Typical scales: 8, 17, 31 or 32 columns. The minimum is property-specific and recorded in the matrix.

### MQ-T3: difficult-column and scheduling qualification

Purpose: expose batch divergence, retry concentration, failure isolation and later routing between execution classes.

Initial target fixtures:

- 15 normal plus 1 difficult column;
- 31 normal plus 1 difficult column.

A real B12 or heavy-clay-like fixture is blocked until it can be generated from a pinned qualified reference run at an event-local checkpoint.

### MQ-T4: long scientific regression

Purpose: preserve representative long-duration SWAP physics and cumulative water balance.

This is explicitly not the default MultiSWAP unit-test layer. It belongs to nightly, milestone or release qualification.

### MQ-P: orthogonal scale/performance lane

Correctness scale, cache scale and throughput scale are separate concerns. MQ-P may reach 1,024 or 100,000 logical columns, but it cannot replace T0 to T4 correctness evidence.

Wall-clock time is not a general shared-CI correctness gate. Prefer deterministic counters and memory accounting. Timing is admissible only on a controlled benchmark host.

## 4. Qualification matrix

The matrix contains 35 rows:

- `R01` to `R08`: cheap runtime contracts;
- `P01` to `P22`: the 22 mandatory MultiSWAP properties;
- `D01` and `D02`: difficult-column scheduling cases;
- `S01`: long scientific regression separation;
- `PFX01` and `PFX02`: cache-scale and throughput-scale qualification.

Every row records:

- architecture invariant numbers;
- minimum columns;
- minimum workers;
- testdouble, real SWAP or both;
- interval duration/class;
- required fixture;
- expected result;
- mass gate;
- determinism requirement;
- relative cost;
- intended frequency;
- current status;
- production dependency;
- identified reusable evidence.

Status meanings are intentionally strict:

- `executable`: an existing qualified test already exercises the claim or its exact primitive without production changes;
- `interface-needed`: final qualification needs a production contract that is not yet canonical;
- `blocked`: a qualified fixture or oracle is missing, not merely an API.

An executable historical primitive does not automatically qualify the future F-MR runtime.

## 5. Event-local fixture contract

### 5.1 Principle

A physical F-MQ fixture is a captured committed continuation state from a pinned qualified reference run immediately before an interesting event or interval. It is never hand-constructed to obtain a desired endpoint.

The generator and the fixture loader belong to verification/test infrastructure, not to the production kernel.

### 5.2 Required fixture content

A fixture must contain or content-address the following information.

1. `fixture_identity`
   - fixture schema version;
   - immutable fixture ID;
   - intended qualification property IDs;
   - creation timestamp as metadata only, never as oracle input.

2. `reference_identity`
   - repository;
   - exact source commit;
   - qualified reference snapshot/tag when applicable;
   - source-tree or reconstruction manifest hash;
   - generator path/version/hash;
   - qualification gate IDs that admitted the reference.

3. `committed_state`
   - state schema/version;
   - only physical continuation state required to resume;
   - hashes for the complete state payload and, where useful, named subcomponents;
   - no worker scratch;
   - no reconstructible solver workspace.

4. `immutable_parameters`
   - parameter-set ID or immutable parameter payload;
   - content hash;
   - model-template/physics signature required to interpret the state.

5. `forcing`
   - only the forcing needed for the short continuation interval;
   - content hash;
   - forcing time basis and interval coverage.

6. `numerical_reference_config`
   - reference-mode policy ID;
   - exact configuration or content hash;
   - qualified tolerance IDs rather than undocumented literals where possible.

7. `event_metadata`
   - `t0` and `t1` in the kernel time basis;
   - event kind, if any;
   - provenance of the checkpoint relative to the pinned reference run;
   - no assumption that the interval begins at midnight or lasts one day.

8. `expected_canonical_result`
   - endpoint committed-state hash or component values required by the comparator;
   - accepted/rejected status;
   - expected discrete transaction route where qualified;
   - deterministic diagnostic counters where they are part of the oracle;
   - explicit list of fields intentionally excluded from comparison.

9. `water_accounting`
   - committed storage start/end;
   - signed external boundary terms;
   - residual definition;
   - hard tolerance qualification ID;
   - component/column identity and area basis.

10. `provenance`
    - full fixture content hash;
    - parent long-run case ID;
    - reference run output/evidence hashes sufficient to reproduce extraction;
    - oracle-change reason when regenerated.

### 5.3 Fixture generation rule

A generator must:

1. reconstruct or select the exact pinned reference source;
2. verify the source/reference identity before execution;
3. run the admitted reference case to the checkpoint;
4. capture only committed continuation state;
5. continue through the short target interval;
6. capture expected endpoint, diagnostics and water accounting;
7. hash all semantic inputs and outputs;
8. emit the fixture and provenance manifest atomically;
9. regenerate, rather than edit, a fixture when an oracle intentionally changes.

A fixture is rejected if its source identity, generator identity or parent-run provenance cannot be reproduced.

### 5.4 Initial fixture set

Proposed order:

1. quiet soil-water continuation;
2. infiltration/rainfall event;
3. irrigation event;
4. drainage activation;
5. retry-sensitive interval;
6. crop/process transition;
7. difficult clay/B12-like interval;
8. later coupling-window boundary.

The quiet fixture should be first because it gives the smallest real-SWAP oracle for P01, P10, P11 and P16 without mixing in event-specific continuation state.

## 6. Existing assets: reuse decisions

### A23BL transaction reference: reuse directly as a transaction-contract primitive

Pinned source:

`tests/transaction/test_transaction_reference.f90` at `763f276a96ee1722a465bacd3a710172a5f38107`.

Already covers with a cheap deterministic model:

- accepted transaction;
- temporal rejection and retry;
- solver failure with no state leak;
- hard mass rejection with no commit;
- generic non-calendar time;
- deterministic repeatability;
- parallel independence.

Decision: reuse the semantics and, where convenient, the existing testdouble rather than inventing a second transaction model. It is not a scheduler/batch test and must not be presented as one.

### A23BU worker context: reuse directly as a worker-isolation primitive

Pinned source:

`tests/runtime/test_a23bu_worker_context.f90` at the A23BU commit.

Evidence:

- 8 workers;
- 1,000 repeated checks per worker;
- 8,000 total parallel checks;
- worker-local control, time, reporting, scratch and diagnostics;
- explicit scratch/reporting payload accounting.

Decision: reuse for P06 and as a lower-level prerequisite for P03/P18. Do not hard-code A23BU's worker representation into the future F-MR API.

### A23BU real Hupsel worker component and poisoning: reuse as historical physical/isolation evidence

Pinned source:

`tests/adapter/test_a23bu_hupsel_worker_component.f90` at the A23BU commit.

It already demonstrates:

- real SWAP transaction execution;
- full versus two-half sampling;
- hard mass gate;
- trial-output suppression;
- persistent irrigation cursor negative control;
- serial references for two logical columns;
- interleaving through a legacy singleton backend;
- poisoning of worker scratch, legacy irrigation workspace, time, reporting and numerical control;
- exact equality of physical state and diagnostics after poisoning/interleaving;
- deterministic cost counters.

Decision: reuse the test pattern and evidence for P19 and for designing T1/T2 fixtures. Do not copy its B1.6 physical constants forward as a B1.10 or SWAP5 oracle. Its backend is explicitly historical and serialized.

### VQ B1.10 reconstruction/admission tooling: reuse for fixture provenance

Observed on the F-MQ01 host pin:

- `reference/swap-4.3.1/snapshots/B1.10.yml`;
- `tools/vq/b1_10_reconstruct.py`;
- `tools/vq/b1_10_admission_gate.py`.

Decision: use as source-identity and reconstruction building blocks when a B1.10-derived fixture is admitted. The final SWAP5 source pin still comes from F-CI.

### VQ mass-accounting schema: reuse and extend, do not replace

`tools/vq/contracts/mass-accounting-record.schema.json` already distinguishes:

- column/tile identity;
- interval;
- trial versus committed accounting;
- storage start/end;
- signed boundary terms;
- execution class;
- qualification context.

Decision: this is the correct base for P16, P17, P20 and P22. F-MQ will need a deterministic aggregation rule on top, not a second incompatible accounting format.

### VQ legacy BAL/BLC parser: reuse only as legacy regression evidence

`tools/vq/balance.py` explicitly documents that legacy BAL/BLC values are printed at 0.01 cm precision and are not precise enough to be the final hard SWAP5 mass-conservation oracle.

Decision: useful for B0/B1 scientific comparison, not sufficient for T1/T2 hard mass gates. F-MQ requires unrounded committed mass accounting from the production seam.

### VQ reference identity: reuse the hash/identity pattern

`tools/vq/reference_identity.py` is currently B0-specific.

Decision: reuse the fail-closed source identity pattern. Do not misuse its B0 manifest lookup as a generic fixture identity service.

### MP measurement collector and aggregation: reuse selected fields and counters

`tests/test_mp_measure.py` and `tools/performance/mp_measure.py` already model:

- column, template, worker and batch identity;
- numerical policy and execution class;
- Newton iterations, Jacobian builds, linear solves, retries and related counters;
- persistent-state and scratch memory;
- mass pass/fail metadata;
- per-worker and per-batch aggregation.

Decision: reuse the identity/counter vocabulary and exact integer aggregation patterns. Keep timing metadata optional and outside correctness oracles.

### MP repeatability utilities: reuse scheduler-order helpers and physical hashes

`tests/test_mp_repeatability.py` already tests rotating execution order and rejects changed physical output hashes.

Decision: reuse rotating/seeded-order methodology for P02 and benchmark-order balancing. Do not infer concurrency correctness from timing repeatability alone.

### MP workload catalog and B12 lock: partial reuse only

`tests/test_mp_workloads.py` locks B12 source-row parameters, which is useful provenance for a future difficult-column fixture.

However, on the F-MQ01 host pin it still asserts corrected legacy `B1.5p1` with `PENDING_VQ_IDENTITY_GATE`, while the same repository contains a later B1.10 qualified snapshot.

Decision: reuse the B12 parameter lock only. Do not use the workload catalog's corrected-reference metadata as current oracle authority. Updating that metadata belongs to its owning integration/verification work, not to F-MQ01 production changes.

### MP isolated runner: reuse only for MQ-P

`tests/test_mp_isolated_runner.py` provides fail-closed checks for CPU affinity, cpuset, quota, frequency metadata, SMT reservation and reference identity.

Decision: keep it in performance qualification. It is not evidence for runtime correctness, transaction semantics or physics.

## 7. Required production interface contracts

F-MQ does not implement these contracts in production. It records them so the owning workstream can expose the smallest adequate seam.

### MQ-KERNEL-01: interval advance

Owner/dependency: F-CI and F-KT.

Required semantics:

- inputs: immutable parameter reference, committed state, forcing, numerical reference configuration, `t0`, `t1`;
- output: trial endpoint state, solver/transaction status, diagnostics and unrounded mass-accounting record;
- trial execution cannot mutate the caller's committed state;
- no file paths, file units or legacy parser concerns in the kernel contract;
- time interval is generic.

### MQ-STATE-01: committed state capture and restoration

Owner/dependency: F-KT with F-CI integration.

Required semantics:

- clone/checkpoint a complete physical continuation state;
- restore it without reconstructing physical history from output files;
- expose a deterministic semantic hash or comparator for qualification;
- exclude worker scratch and reconstructible workspace.

### MQ-RUNTIME-01: logical column execution envelope

Owner/dependency: later F-MR.

Required semantics:

- stable column ID;
- template ID/physics signature;
- parameter reference;
- forcing reference or view;
- committed-state handle;
- batch and worker attribution in diagnostics;
- deterministic result collection independent of execution order.

### MQ-DIAG-01: committed diagnostics aggregation

Owner/dependency: later F-MR, coordinated with F-KT/F-SI as needed.

Required semantics:

- per-column discrete counters are authoritative;
- batch/run counters are deterministic reductions of per-column committed counters;
- rejected-trial cost may be reported but must remain distinguishable from accepted-route diagnostics;
- no silent loss of failed/retried column diagnostics.

### MQ-MASS-01: unrounded committed mass accounting

Owner/dependency: F-CI/F-KT for the kernel record, later F-MR for aggregation, F-SI for coupling interfaces.

Required semantics:

- storage at start and committed end;
- signed external boundary terms;
- trial versus committed scope;
- column/tile ID and area basis;
- explicit residual definition and qualified tolerance ID;
- deterministic aggregate reduction rule;
- coupling boundary terms preserve the interface sign convention.

### MQ-COUPLING-01: later predictor/corrector transaction seam

Owner/dependency: F-SI and later F-MR/F-CI integration.

Required semantics:

- coupling-window checkpoint;
- predictor trial;
- corrector from the correct committed physical state;
- rollback of rejected trials;
- commit exactly once;
- exposed interface head/flux residuals and mass accounting.

## 8. Immediate gaps after F-MQ01

The main remaining gaps are deliberate, not hidden:

1. no test-only MultiSWAP scheduler/testdouble harness yet exercises R01 to R08 as a coherent runtime harness;
2. no canonical F-CI production baseline has yet been consumed by F-MQ;
3. no event-local real-SWAP fixture format/generator has yet been executed end to end;
4. no qualified short B12/heavy-clay fixture exists yet;
5. no future F-MR runtime interface exists to qualify worker-count, partition and failure behavior end to end;
6. tile and coupling properties remain interface contracts, not production claims.

## 9. F-MQ01 conclusion

F-MQ01 is complete as the matrix and reuse-assessment unit when the matrix structural gate passes. It intentionally does not claim completion of the broader first F-MQ phase.

The logical next unit is a production-independent T0 harness: a deterministic column testdouble plus test-only partition/dispatch/reorder/aggregation machinery that can make R01 to R08 and the testdouble portions of P02, P04, P09 and P15 executable without waiting for F-MR.
