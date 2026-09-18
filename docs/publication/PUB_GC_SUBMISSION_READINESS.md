# PUB-GC submission-readiness audit

## Status

**SCIENTIFIC PACKAGE CLOSED THROUGH E7 — REALISTIC TRANSFERABILITY BOUNDED BY COMPONENT DOMAIN**

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
| RQ5 realistic transferability | E7 Hupsel | `CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT` | ready for a bounded negative transferability claim; no regional Hupsel validation |
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
| Figure F7 | BUILT_AND_LINKED as realistic component-domain result |
| Tables T1–T5 | BUILT_AND_LINKED |
| Table T6 | BUILT_AND_LINKED as E7 application-domain disposition |
| reference metadata | externally audited / normalized |
| claim-to-sentence audit | PASS: `NO_CURRENT_CLAIM_LEDGER_OVERRUN DETECTED` |
| code/evidence reproducibility section | READY at repository level; archival DOI/release not yet frozen |
| notation / units glossary | READY: `PUB_GC_NOTATION_AND_UNITS.md` |
| supplementary methods/evidence package | READY_THROUGH_E6: `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md` |
| machine-readable reproducibility manifest | READY_THROUGH_E6: `PUB_GC_REPRODUCIBILITY_MANIFEST.json` |

## What remains scientific

The M1-C3 whole-Hupsel prerequisite is now canonically closed. E7 standalone selection has been executed prospectively and frozen before any coupled output. The remaining primary scientific addition is the preregistered loose/sequential versus production-strong coupling result for 2003-06-17 and 2003-05-20.

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

If E7 coupling cannot be completed for a genuine new technical reason, the existing E1–E6 manuscript remains internally coherent but must be framed as a **bounded coupling-method and qualification study**. The former raw-asset/M1-C3 blocker is no longer a valid reason to omit E7.

E8 should not be started merely to compensate for the E7 component-domain outcome. No additional primary experiment is required for the current bounded claim set.


## Journal-facing prose state

The scientific body has completed a repository-jargon cleanup. Internal F-GC/FMR/PUB-GC identifiers are no longer required to follow the journal-facing argument; exact identifiers remain in the evidence layer after the References section.

Audit: `PUB_GC_SUBMISSION_PROSE_AUDIT.md`.

This is an editorial cleanup only and does not change the claim/evidence state.


## E7 standalone-selection closure

Selection result: `PUB_GC_E7_STANDALONE_SELECTION_RESULT.md` / `.json`.

Frozen dates: median-dynamics `2003-06-17`; high-dynamics `2003-05-20`. Groundwater fallback is the uncalibrated qualified F-GC44 conceptual fixture. No coupled output was observed before this freeze.


## E7 closure evidence

- result: `PUB_GC_E7_RESULT.json`;
- selected-day freeze: PR #325 / merge `080c24be1fd352d390647c832d215833e1ae3df2`;
- E7 static application/domain gate: run 35375158694 / job 105698010382 — SUCCESS;
- PPA-WU01 O0/O2 dynamic owner gate: run 35375158471 / job 105698009081 — SUCCESS;
- F7/T6: built;
- coupled Hupsel head/exchange curves: intentionally absent by preregistered stop rule.
