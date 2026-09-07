# F-MQ10 — F-CI11 Physical Fixture Admission Assessment

## Purpose

F-MQ10 resumes the qualification-only MultiSWAP workstream after F-CI11 removed two earlier architecture blockers:

- the controlled B1.10 source now has a qualified generic physical interval seam, including non-midnight and cross-calendar-day intervals;
- worker/job-local unrounded trial-mass wiring is qualified for the exercised Hupsel profile and satisfies the hard mass bound.

The purpose of this unit is deliberately narrower than creating a new physical oracle. F-MQ10 asks whether the canonical F-CI11/F-VQ evidence is already sufficient to build the first `mq-event-fixture-v1` reference fixture through the existing F-MQ03/F-MQ04c admission path.

It is not.

## Exact basis

F-MQ10 is based on F-MQ09 commit:

`96cacecb7c0dba4795d475044eb09727a3ce61c8`

Canonical physical provenance is pinned to:

- repository: `abhedwig-cell/SWAP5`;
- qualified F-CI11 source head: `4e8894fc741d7abd711367f712e7aad29d1361eb`;
- qualification evidence commit: `b18150cb4f5313f01fc1c775917c617b421c9ba0`;
- canonical workflow run: `34100440481`;
- B1.10 manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

F-VQ01 was also inspected at `4bf00d23fc35944df30cc17fc5dd4544e813c29d` as downstream qualification state, not as production-source authority.

## What F-CI11 now proves

F-MQ accepts the following F-CI11 results as capability evidence:

1. generic interval termination is independent of calendar-day termination;
2. non-midnight and cross-calendar-day physical intervals were exercised;
3. unrounded trial mass is accumulated from the controlled timestep terms;
4. the exercised Hupsel profile remains within the hard `1e-6 cm` mass bound;
5. O0 and O2 qualification results are identical for the reported evidence.

These results remove the old claim that generic physical time and unrounded trial mass are wholly unavailable.

They do **not** themselves constitute an F-MQ event fixture.

## F-MQ03 fixture boundary

`mq-event-fixture-v1` requires one source-bound reference-run record containing all of the following as a coherent interval artifact:

- a physical `reference_run_id`;
- serialized committed physical continuation state exactly at `t0`;
- the short forcing slice for `[t0,t1]`;
- the numerical reference configuration;
- serialized expected endpoint state;
- unrounded mass accounting with storage start/end and identified signed boundary terms;
- extractor identity plus exact extractor-output hash.

The record must then pass the existing F-MQ04c admission bridge before the F-MQ03 builder may create a fixture.

## Why F-CI summary evidence cannot be converted directly

The F-CI11 canonical evidence explicitly states that the detailed raw local run matrix remains outside canonical Git. The canonical summaries contain qualification assertions and selected metrics, not a serialized event checkpoint.

Likewise, F-CI10/F-CI11 mass evidence contains unrounded totals and residual qualification, but it is not the F-MQ03 mass record. In particular, F-MQ03 requires `storage_start`, `storage_end`, and stable boundary-term/interface identities for the exact interval.

Therefore F-MQ10 forbids the following shortcuts:

- reconstructing committed state from summary metrics or legacy globals described in documentation;
- using `total_in`, `total_out`, and residual as a substitute for the F-MQ03 boundary-term record;
- treating the GitHub Actions workflow run ID as a physical reference-run ID;
- slicing forcing ad hoc from legacy input files without the qualified extractor;
- invoking a non-admitted `execute_reference_interval` path to manufacture the expected endpoint;
- hand-constructing any missing physical payload.

Any of those would break provenance and would turn qualification infrastructure into a second, unqualified oracle.

## F-VQ / F-CI12 handoff

F-VQ01 currently keeps real B1.10 `execute_reference_interval` fail-closed and names F-CI12 as a blocker. That is now the relevant handoff boundary for F-MQ.

The required upstream result is not another F-MQ testdouble. It is a persisted, exact-provenance `reference_run_checkpoint` record emitted from an admitted real B1.10 reference execution path.

Once that exists, F-MQ should reuse the contracts already present:

`F-VQ reference-run extraction -> F-MQ04c admission bridge -> F-MQ03 fixture builder -> physical P10/P11/P16 qualification`

No new fixture schema is needed for that transition.

## Result

F-MQ10 remains qualification-only and changes no production source.

The new F-CI11 candidate is syntactically valid under the existing F-MQ04b candidate contract but remains fail-closed with all seven reference-record requirements missing as persisted event artifacts.

Formal status:

`BLOCKED_FCI11_CAPABILITY_READY_REFERENCE_RUN_RECORD_NOT_ADMITTED`

This is progress relative to F-MQ04b: the physical kernel capability blockers for generic time and trial-mass wiring are substantially reduced. The remaining blocker is now primarily the admitted reference-execution/extraction artifact boundary, with F-CI12/F-VQ as owners.
