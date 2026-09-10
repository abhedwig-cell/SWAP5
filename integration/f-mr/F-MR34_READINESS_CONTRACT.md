# F-MR34 — Parallel Root-Uptake & Actual-Transpiration Publication Readiness

## Purpose

F-MR34 defines the smallest safe architecture boundary for extending the currently qualified parallel real-physics MultiSWAP route with restricted root-water uptake and postcommit actual-transpiration publication. It is readiness-only. No production source is changed here.

## Source-bound finding

The current canonical worker pool already dispatches each admitted parallel column through `fmr_execute_serialized_physical_column`. That procedure delegates to the same private `execute_column` implementation used by the serialized runtime. The F-MR31/F-VQ50 postcommit attribution binding therefore already exists on the per-column execution path used by parallel workers.

The current parallel-v1 admission predicate deliberately prevents that path from being exercised with root uptake. It requires `root_extraction_active = .false.` and requires `root_extraction_sink(:)` to be finite and identically zero. This is an existing qualified physical-profile boundary, not an implementation accident.

Therefore the safe next change is NOT to silently relax parallel-v1. A distinct explicitly named root-active parallel physical profile/capability must be introduced and independently qualified while the existing parallel-v1 profile remains byte/behaviour compatible.

## Dependency map

Atmospheric/crop demand authority
→ canonical potential transpiration (`ptra`)
→ restricted root-water-uptake process authority (F-VQ22)
→ `fmr_b110_physical_forcing_t%root_extraction_sink(:)`
→ serialized reference backend / B1.10 root-sink provider
→ transaction trial and accepted candidate
→ authoritative `mass_out` root sink booking
→ successful commit
→ existing F-MR31 exact-forcing-bound `actual_transpiration_amount`
→ per-column runtime result
→ deterministic MultiSWAP publication order.

For parallel execution the worker pool contributes only scheduling, worker-local backend/executor ownership, and deterministic collection. It must not become an owner of root-uptake physics or actual-transpiration arithmetic.

## Data classification

| Item | Classification | Ownership / lifetime |
| --- | --- | --- |
| root-water-uptake stress/shape parameters | immutable physical parameters | shared parameter registry by reference |
| `root_extraction_active` | physical configuration | parameter set / execution profile |
| `root_extraction_sink(:)` | forcing / accepted process input for the frozen outer interval | forcing registry, read-only during execution |
| pressure head / water content | committed dynamic hydraulic state | committed column state |
| root-sink provider pointer binding | worker/trial scratch | worker-local backend/model lifetime |
| Newton/Jacobian/workspace | worker scratch | never persistent per column |
| `actual_transpiration_available` | output/result metadata | per execution result |
| `actual_transpiration_amount` | postcommit output attribution | per execution result |
| root-extraction water mass | authoritative mass contribution | existing transaction mass ledger only |
| worker id / assignment | runtime diagnostic | ephemeral runtime/result metadata |

No new persistent per-column state is required by this readiness design.

## Physical-process interface contract

1. Root uptake remains owned by the existing qualified root-water-uptake / B1.10 root-sink provider chain. Parallel runtime code must not reimplement Feddes or any other root-uptake physics.
2. The root-sink provider receives only the accepted process input vector and standard solver hydraulic inputs. Scheduling code does not access HeadCalc arrays, Newton vectors, Jacobians or solver globals.
3. F-MR31 remains the single actual-transpiration publication binding. A parallel worker must reach it through the same per-column executor; no parallel-specific duplicate attribution formula is introduced.
4. The root-active parallel capability must be represented as an explicit physical profile distinct from the existing root-inactive parallel-v1 profile. A numerical policy or worker count must not silently switch physics.

## Transaction contract

A rejected trial, rejected candidate or failed commit publishes no actual transpiration. `actual_transpiration_available` remains false and the amount remains zero.

Publication occurs only after successful commit in the same private per-column execution call that resolved the column forcing handle used for `run_trial`. This preserves the F-VQ50 exact-forcing pairing guarantee in parallel execution.

Worker scheduling must not mutate committed state outside the candidate/commit route. Each state handle remains uniquely claimed within one batch execution.

## Mass-contribution contract

Root extraction is already part of the authoritative transaction `mass_out`. Actual-transpiration publication is an attribution of that already-booked sink and MUST NOT add a second water-mass contribution.

Qualification of the root-active parallel profile must demonstrate, for every accepted column:

`storage_change = mass_in - mass_out + residual`

within the existing hard tolerance, and must demonstrate aggregate identity from the authoritative per-column ledgers. Zero root uptake is a valid active-physics case and must publish an available amount of exactly zero after commit.

## Generic-time contract

No day, midnight or calendar boundary is fundamental. The current F-MR31 attribution is valid only while `root_extraction_sink(:)` is invariant over the requested outer interval `[t0,t1]` and the completed candidate covers that full interval.

For this restricted scope:

`actual_transpiration_amount = sum(root_extraction_sink(:)) * (t1 - t0)`.

Time-varying root sink inside accepted substeps is explicitly NOT qualified by this contract. That future scope requires accepted-history attribution rather than reconstruction from one outer-interval forcing vector.

## Parallel safety contract

The root-active candidate must preserve worker-local backend and transaction-control instances. Shared parameter and forcing registries remain read-only. Each logical column must own a unique committed state handle during execution.

Qualification must compare 1-worker serialized reference execution with admitted 2-worker and 4-worker execution over caller-order permutations, batch-size permutations, shared and distinct forcing handles, A-B-A sequences, active-zero uptake, and fail-closed invalid/rejected cases.

Publication must remain deterministic in canonical column order and independent of worker assignment.

## Restart contract

F-CI35 qualifies committed-boundary restart for the currently admitted root-inactive parallel profile. That qualification does not automatically extend to a new root-active parallel profile.

After the root-active parallel execution profile is independently qualified, committed-boundary restart for that profile requires a separate restart requalification. Worker scratch, provider pointer bindings, Newton/Jacobian data and warm-start workspace remain reconstructed rather than persisted.

## Optionality

Inactive root uptake must not add persistent state. The existing root-inactive parallel-v1 path remains available without root-active costs or semantic changes. Any future memory-layout optimization of forcing arrays is separate from this physical-profile admission.

## Required qualification matrix for the structural candidate

The future candidate must at minimum prove:

- serialized 1-worker versus parallel 2-worker and 4-worker scientific identity for the frozen restricted root-active profile;
- caller-order and batch-size independence;
- exact forcing-handle association of actual-transpiration publication;
- hard per-column and aggregate mass conservation;
- no second mass booking;
- active-zero, root-inactive and rejected-column semantics;
- worker-local backend/provider isolation under concurrent root-active solves;
- O0/O2 identity;
- preservation of the old root-inactive parallel-v1 profile;
- no claim of root-active committed restart until a separate restart requalification is green.

## Migration slices

**F-MR34**: readiness only, this workunit. Freeze boundary, source authority, data ownership, mass/time/transaction contracts, optionality, and qualification obligations.

**F-MR35**: restricted structural candidate. Add an explicit root-active parallel physical profile/capability without changing root-uptake physics or the F-MR31 attribution implementation. Preserve the existing parallel-v1 profile unchanged.

**F-MQ30**: independent many-column qualification of root-active parallel execution and actual-transpiration publication against serialized reference, including hard mass and forcing provenance.

**Separate restart requalification**: only after F-MQ30. Qualify committed-boundary restart of the new root-active profile, including worker-count changes, without persistent worker scratch.

**F-CI admission**: only after all required independent qualifications are green on exact pinned candidates.

## Exit criterion

F-MR34 may close as:

`QUALIFIED_PARALLEL_ROOT_UPTAKE_ATTRIBUTION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE`

only if a source-bound gate confirms the pinned canonical source semantics and no production/reference source was changed by F-MR34.
