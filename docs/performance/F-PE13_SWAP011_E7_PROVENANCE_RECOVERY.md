# F-PE13 — SWAP-011 E7 provenance recovery

Date: 2026-09-16

Status: `RECOVERY_ACTIVE / NO_RECONSTRUCTION_ALLOWED`

## Scope

This workunit continues from the closed F-PE12 performance-recovery campaign and addresses one concrete remaining gate only:

**recover the exact final E7 SWAP-011 upstream artifact needed for formal legacy admission.**

Protocol:

`RECONCILE -> RECOVER -> VERIFY -> CLOSE`

This is a provenance/recovery workunit. It is not a new implementation workunit.

Explicit exclusions:

- no reconstruction of E7 from prose, E2/E3 prototypes, expected symbols or qualification summaries;
- no change to SWAP5 production source;
- no Energy Balance work;
- no RossFast work;
- no new hydraulic formulas;
- no B1 admission unless the exact original E7 payload is recovered and verified;
- no claim that a similarly behaving reimplementation is the historical E7 artifact.

## Authorities

Current SWAP5 canonical at workunit start:

- branch: `integration/f-ci-canonical`
- commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`

Legacy source authority:

- immutable SWAP 4.3.1 B0 under `reference/swap-4.3.1/b0/`;
- SWAP-011 candidate dossier already present on current canonical;
- candidate qualification file blob on canonical: `b0dd8e5a3ad812c8e18cac3c96108ace3bf64162`;
- GitHub issue #12 remains the formal recovery gate;
- historical candidate branch: `b1-swap011-candidate@35b761f6e10fe32e438b32b94948b4b3a905f50a`.

## What is already established

Recovered qualification records establish that the final optimized E5/E6/E7 lineage is technically real and distinct from the earlier numerical correctness reference.

The recorded final E7 production source set is exactly:

```text
SWAP/MOD_MvG_functions.f90
SWAP/WC_K_models_04_11.f90
SWAP/MOD_RIA.f90
```

and `SWAP/headcalc.f90` remains byte-identical in that final line.

Recorded qualification includes:

- E5 36/36 strict full runs PASS;
- E5 Newton routes equal to the qualified reference route;
- E5 gate `result.end` byte identity;
- E6 150/150 normal completions;
- E6 60/60 Newton-route equality versus the qualified reference;
- E6 K0 30/30 byte-identical outputs;
- E6 K1 remaining differences at recorded round-off scale;
- median E5/reference runtime ratio `0.791`, about 20.9% faster;
- E7 focused sanity retained exact Newton histograms and byte-identical `result.end` in its recorded focus set;
- historical audit status `FIX_TESTED / READY_PATCH_UPSTREAM`.

These records are qualification evidence, not replacement source bytes.

## Required original artifact

Expected provenance clues remain:

```text
SWAP_4.3.1_E7_SW011_upstream_package.zip
SWAP_4.3.1_SW011_overdracht_Marius.docx
SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip
patch/SWAP-011_fix.patch
```

The filename alone is not sufficient. A recovered object must be verified by content and source identities.

## Recovery performed in F-PE13

### GitHub

- no existing F-PE13 branch or equivalent current recovery workunit was found;
- issue #12 is the existing formal provenance tracker;
- repository branch search found only the historical `b1-swap011-candidate` branch for SWAP-011;
- commit search for `SWAP-011 E7` found the dossier-staging commit `f369e68a06e97780e7879a33937b41539a81c557`, whose own message states that the exact E7 payload remains required;
- direct current-tree code search for `SWAP_4.3.1_E7_SW011_upstream_package` returned no repository file.

### File Library

Multiple recovery searches were performed using:

- each expected exact artifact filename;
- `SWAP-011`, `E7`, `Marius`, `READY_PATCH_UPSTREAM`;
- the E5/E6 qualification fingerprints `36/36`, `150/150`, `60/60`, and the 20.9% timing result;
- implementation descriptors such as lazy constitutive state and finite-difference fallback;
- date-window navigation over the late-August / early-September audit period.

Recovered relevant objects include the D2 qualification record, E2/E3 design/prototype records, the broad `SWAP_4.3.1_proposed_fixes.patch`, issue registers and general testbank material.

The exact E7 upstream package, exact E7 `SWAP-011_fix.patch`, and named Marius SWAP-011 handoff bundle/document were not returned by these searches.

The broad `SWAP_4.3.1_proposed_fixes.patch` remains explicitly unsuitable: it is an earlier multi-fix/reference-stage patch and is not the final three-file E7 payload.

## Current recovery verdict

```text
EXACT_E7_PAYLOAD_RECOVERED = NO
PATCH_PAYLOAD_STATUS = PENDING
REIMPLEMENTATION_ALLOWED = NO
B1_ADMISSION_ALLOWED = NO
```

This is not evidence that the artifact no longer exists. It means it is not recoverable from the currently searchable repository and File Library surfaces using the known provenance identifiers.

## Verification contract if an artifact is recovered later

Before an object can unlock admission it must pass all of the following:

1. compute and persist artifact SHA-256;
2. inspect package contents without altering bytes;
3. identify the exact patch payload;
4. verify changed file set is exactly the recorded E7 three-file production set;
5. verify every patch preimage against immutable B0 hashes;
6. apply through a byte-safe path, especially for non-UTF-8 `MOD_RIA.f90`;
7. confirm `headcalc.f90` remains byte-identical;
8. confirm no unlisted source changes;
9. reproduce or attach immutable E5/E6/E7 machine evidence against the recovered postimage;
10. only then consider storing `fix.patch`, promoting the legacy ledger and updating the ordered B1 manifest.

## Next permitted action

One further bounded recovery route is permitted before this workunit closes as externally blocked:

- inspect whether the surviving late-August complete testbank/package material contains nested or renamed audit transfer artifacts that are not discoverable by top-level filename/content search.

This inspection must remain artifact discovery only. If it does not recover an exact E7 object, close F-PE13 as `BLOCKED_EXTERNAL_ARTIFACT_REQUIRED` and leave issue #12 open.
