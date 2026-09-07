# F-MQ03 Event-local fixture and canonical comparison contract

Status: `QUALIFICATION_INFRASTRUCTURE_ONLY / NO_PRODUCTION_RUNTIME_OR_PHYSICS_CHANGE`

## Scope

F-MQ03 adds test-only infrastructure for short reference-derived continuation fixtures and canonical result comparison. It does not add or modify SWAP production kernel code, solver physics, numerical policy or MultiSWAP runtime.

The purpose is to make MQ-T1 and later MQ-T2/T3 tests short and reproducible. A long SWAP run may be used to generate a checkpoint, but the qualification test consumes only the committed state immediately before the event and the minimum data needed to continue over a short interval.

## Fixture contract

A valid fixture contains:

- an exact source repository and 40-character commit SHA;
- a named corrected/reference family and snapshot;
- source case and run identity;
- an extractor identity and `reference_run_checkpoint` extraction mode;
- one or more SHA-256 hashes for source artifacts;
- event kind and generic `[t0,t1]` metadata;
- committed continuation state at exactly `t0`;
- immutable parameter reference, or a small inline immutable parameter set;
- forcing for the short continuation interval;
- numerical reference configuration;
- expected endpoint state and explicitly qualified numeric tolerances;
- expected canonical observables and exact discrete diagnostics;
- unrounded normalized mass accounting with a hard tolerance;
- component hashes and one canonical whole-fixture integrity hash.

The fixture is deterministic JSON. Key order in the file is canonicalized, component payload hashes are recomputed, and the whole fixture is protected by a SHA-256 over its canonical content excluding only the integrity field itself.

## What is forbidden

The committed state may not contain reconstructible worker or solver workspace such as:

- worker scratch/context;
- Jacobian matrices;
- Newton vectors;
- residual workspace;
- linear-solver workspace;
- reconstructible constitutive caches.

These belong to workers or attempts, not persistent logical columns. Expected diagnostic counters such as `newton_iterations` are allowed because they are results, not continuation state.

## Provenance rule

`build_fixture_from_reference_record()` accepts only records marked as extracted from a reference run. The contract therefore fails closed on a hand-edited extraction-mode marker or an unpinned branch name.

This is a structural provenance gate, not yet proof that an external source run really existed. The actual extractor and source-run execution still need to be supplied by VQ/F-CI once the canonical production/reference interface is available.

No physical B1.10 or SWAP5 event fixture is admitted by F-MQ03 itself.

## Mass rule

A fixture hard mass oracle must use either:

- `unrounded_internal`, for real model accounting; or
- `synthetic_exact`, for the T0 testdouble.

Rounded legacy BAL/BLC report values are rejected as a hard oracle. This matches the existing VQ finding that legacy report precision is insufficient for the final SWAP5 hard mass-conservation gate.

The normalized convention is:

`residual = storage_end - storage_start - sum(external signed boundary amounts)`

Internal diagnostic transfer terms are excluded from the external balance. The hard tolerance is fixed by the fixture. An observed runtime result cannot relax that tolerance.

## Canonical comparator

`compare_observed_to_fixture()` separates several comparison classes:

1. event interval and time basis are exact;
2. endpoint-state structure is exact, while numeric values use explicit absolute/relative tolerances;
3. selected observables use their own qualified tolerances;
4. selected discrete diagnostics are exact;
5. normalized mass accounting must first pass the hard mass gate, then match the expected canonical mass terms within the fixture comparison tolerance.

Extra runtime diagnostics are allowed, but every diagnostic named by the fixture must be present and exact. State structure is stricter: missing or extra state fields are a qualification failure because that usually indicates a changed continuation-state contract.

## Qualification evidence in this work unit

The F-MQ03 unit gate covers:

- deterministic serialization and reload;
- source commit and artifact-hash pinning;
- refusal of non-reference extraction mode;
- component and whole-fixture mutation detection;
- compact immutable parameter references;
- inline immutable parameter hashing;
- checkpoint equal to interval start;
- rejection of worker/solver scratch in committed state;
- rejection of rounded legacy mass as hard oracle;
- hard closure of expected mass accounting;
- exact canonical observation comparison;
- path-specific endpoint numeric tolerance;
- exact discrete diagnostic comparison;
- prevention of runtime mass-tolerance relaxation;
- forcing changes producing a different fixture identity.

## Dependencies left open

F-MQ03 deliberately does not create a physical reference fixture. The next integration points are:

- VQ: reference-run extractor and oracle provenance;
- F-CI/F-KT: canonical committed-state and short-interval kernel contracts;
- F-SI: canonical state serialization where that workstream owns the representation;
- F-MR: production runtime adapter that consumes the fixture and returns per-column canonical results.

Until those interfaces exist, this work unit qualifies the fixture and comparator machinery only.

## Architecture invariants

F-MQ03 directly supports invariants 3, 4, 5, 7, 8, 9, 13, 23, 26, 27, 29 and 30. It keeps reference extraction and serialization outside the production kernel.

## Next step

F-MQ04 should add the first fixture-extraction adapter against an explicitly pinned qualified reference source, preferably starting with one quiet or infiltration interval. If the canonical SWAP5 state interface is not yet available, F-MQ04 should remain VQ-side and generate a fixture candidate without claiming production-kernel executability.
