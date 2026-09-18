# PUB-GC submission-readiness audit

## Status

**SCIENTIFIC CORE READY THROUGH RQ4 — RQ5 / E7 REMAINS THE ONLY INTENDED PRIMARY SCIENTIFIC GAP**

Audit date: 2026-09-18.

Canonical basis at audit start: `integration/f-ci-canonical@337277cc690508966f533488ab7f9493352cfa77`.

This is a journal-neutral readiness audit. It does not select a journal and does not reinterpret existing evidence.

## Scientific readiness

| Element | Evidence / asset | State | Submission implication |
| --- | --- | --- | --- |
| RQ1 interface and authority | E1/E2 | `SUPPORTED_RESTRICTED` | ready for bounded claim |
| RQ2 coupled convergence and hydrological relevance | E3/E3-R | `SUPPORTED_RESTRICTED` | ready; explicitly a weak-feedback control |
| RQ3 response identity and information value | E4/E5 | `SUPPORTED_RESTRICTED` | ready; no universal-Jacobian or standalone-ACCELERATE claim |
| RQ4 component-envelope interaction | E3-D2/E6 | `SUPPORTED_RESTRICTED` / negative stress extension | ready; component-domain failure kept distinct from coupling divergence |
| RQ5 realistic transferability | E7 Hupsel | `PREREGISTERED / BLOCKED_EXTERNAL_PREREQUISITE` | principal remaining scientific gap |
| regional scaling | E8 | deferred | not a submission prerequisite unless journal positioning later makes quantitative scaling central |
| physical N:1 aggregation validity | PUB-SG / SCALE | separate paper | excluded from PUB-GC |

## Manuscript assets

| Asset | State |
| --- | --- |
| result-bearing abstract | READY through E6; must be updated after E7 if executed |
| Introduction / novelty boundary | READY; external prior-art audit completed |
| Methods E1–E7 | READY; E7 explicitly prospective |
| Results E1–E6 | READY |
| Discussion / conclusions | READY through E6 and evidence-bounded |
| Figures F1–F6 | BUILT_AND_LINKED |
| Figure F7 | BLOCKED_E7 |
| Tables T1–T5 | BUILT_AND_LINKED |
| Table T6 | BLOCKED_E7 |
| reference metadata | externally audited / normalized |
| claim-to-sentence audit | PASS: `NO_CURRENT_CLAIM_LEDGER_OVERRUN DETECTED` |
| code/evidence reproducibility section | READY at repository level; archival DOI/release not yet frozen |
| notation / units glossary | READY: `PUB_GC_NOTATION_AND_UNITS.md` |
| supplementary methods/evidence package | READY_THROUGH_E6: `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md` |
| machine-readable reproducibility manifest | READY_THROUGH_E6: `PUB_GC_REPRODUCIBILITY_MANIFEST.json` |

## What remains scientific

The only planned primary scientific addition is E7. It requires the existing M1-C3 final whole-Hupsel file-driven adapter execution against the exact authorized SWAP 4.3.1 distribution. Until that prerequisite closes, no coupled Hupsel output, F7 or T6 may be fabricated or inferred.

If E7 eventually returns weak feedback or a component-domain limit, that remains a valid E7 outcome under the frozen preregistration. A positive strong-feedback result is not required for acceptance of the evidence.

## What remains editorial / submission-specific

These items do not require new science:

- select target journal and adapt title, abstract length, section style and bibliography format;
- insert final author list, affiliations, corresponding-author details and contribution statement;
- add acknowledgements, funding and conflict/data/code availability declarations required by the journal;
- freeze an archival repository release/DOI and replace development-revision language with the archived identifier;
- final language/notation consistency pass after E7 or after an explicit decision to submit the bounded E1–E6 paper without E7;
- prepare journal-resolution raster/PDF exports if the journal does not accept SVG.

## Decision boundary

For the intended broader hydrological-method framing, E7 materially strengthens external validity and remains the preferred next scientific step.

If the M1-C3 external asset gate remains unavailable at the submission decision, the existing E1–E6 manuscript is still internally coherent, but it must be framed explicitly as a **bounded coupling-method and qualification study** rather than a realistic-application validation paper. No claim may imply that RQ5 was answered.

E8 should not be started merely to compensate for a blocked E7.


## Journal-facing prose state

The scientific body has completed a repository-jargon cleanup. Internal F-GC/FMR/PUB-GC identifiers are no longer required to follow the journal-facing argument; exact identifiers remain in the evidence layer after the References section.

Audit: `PUB_GC_SUBMISSION_PROSE_AUDIT.md`.

This is an editorial cleanup only and does not change the claim/evidence state.
