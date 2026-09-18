# PUB-GC submission-readiness audit

## Status

**SCIENTIFIC CORE READY THROUGH RQ5 — E7 CLOSED AS REALISTIC_COMPONENT_DOMAIN_LIMIT**

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
| RQ5 realistic transferability | E7 Hupsel | `CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT` | bounded negative result; authentic drainage exceeds current prescribed-head participant envelope before coupled execution |
| regional scaling | E8 | deferred | not a submission prerequisite unless journal positioning later makes quantitative scaling central |
| physical N:1 aggregation validity | PUB-SG / SCALE | separate paper | excluded from PUB-GC |

## Manuscript assets

| Asset | State |
| --- | --- |
| result-bearing abstract | READY through E7 |
| Introduction / novelty boundary | READY; external prior-art audit completed |
| Methods E1–E7 | READY; E7 executed to preregistered component-domain stop |
| Results E1–E7 | READY |
| Discussion / conclusions | READY through E7 and evidence-bounded |
| Figures F1–F7 | BUILT_AND_LINKED |
| Tables T1–T6 | BUILT_AND_LINKED |
| reference metadata | externally audited / normalized |
| claim-to-sentence audit | PASS: `NO_CURRENT_CLAIM_LEDGER_OVERRUN DETECTED` |
| code/evidence reproducibility section | READY at repository level; archival DOI/release not yet frozen |
| notation / units glossary | READY: `PUB_GC_NOTATION_AND_UNITS.md` |
| supplementary methods/evidence package | READY_THROUGH_E7: `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md` |
| machine-readable reproducibility manifest | READY_THROUGH_E7: `PUB_GC_REPRODUCIBILITY_MANIFEST.json` |

## What remains scientific

No preregistered primary experiment remains open for the current bounded manuscript.

E7 closes RQ5 negatively but validly: the prospectively selected Hupsel days require active drainage, whereas the current production prescribed-head owner rejects active drainage before owner-state allocation. The study therefore reports a realistic component-domain limit rather than inventing a looser Hupsel process profile.

E8 remains deferred and is not required for the current central claims. A future prescribed-head capability that admits active drainage could support a separate prospective follow-up, but it must not retroactively replace E7.

## Journal positioning

Primary target: **Geoscientific Model Development (GMD)** as a **Development and technical paper**.

Secondary target: **Environmental Modelling & Software**.

The target-journal rationale and GMD-specific submission gates are frozen in `PUB_GC_JOURNAL_POSITIONING.md`. Journal positioning does not broaden the E1–E7 claim set.

The remaining submission blockers are archival/governance rather than scientific. They are frozen in `PUB_GC_GMD_ARCHIVAL_GATE.md`: (A1) a governed SWAP5 publication version/release identifier, (A2) explicit software-licence and redistribution authority, and then (A3) a persistent exact-version archive with DOI or equivalent unique identifier. The live GitHub repository remains the development location but is not sufficient by itself for the GMD archive requirement.

## What remains editorial / submission-specific

These items do not require new science:

- convert the already selected GMD route to final title/version, section, template and bibliography format;
- insert final author list, affiliations, corresponding-author details and contribution statement;
- add acknowledgements, funding and conflict/data/code availability declarations required by the journal;
- freeze an archival repository release/DOI and replace development-revision language with the archived identifier;
- final language/notation consistency pass on the closed E1–E7 manuscript;
- prepare journal-resolution raster/PDF exports if the journal does not accept SVG.

## Decision boundary

The intended broader coupling-method framing now has a complete E1–E7 scientific core, but the external-validity result is a **component-domain boundary**, not a successful realistic loose-versus-strong comparison.

Accordingly the manuscript may claim that:

- the coupling contract is hydrologically and transactionally explicit in the qualified controlled envelope;
- a realistic prospectively selected Hupsel application exposes a concrete production participant boundary;
- component admissibility is part of the coupled-model domain.

It may not claim that:

- realistic Hupsel loose/strong corrections were quantified;
- active-drainage Hupsel is currently production-coupled to MODFLOW6 under prescribed-head trials;
- regional Hupsel groundwater behaviour was validated;
- E7 demonstrates that strong coupling is or is not hydrologically important in realistic Hupsel.

This bounded framing is scientifically complete enough for journal selection and submission preparation without manufacturing a positive E7 trajectory.

## Journal-facing prose state

The scientific body has completed a repository-jargon cleanup. Internal F-GC/FMR/PUB-GC identifiers are no longer required to follow the journal-facing argument; exact identifiers remain in the evidence layer after the References section.

Audit: `PUB_GC_SUBMISSION_PROSE_AUDIT.md`.

This is an editorial cleanup only and does not change the claim/evidence state.


## E7 standalone-selection closure

Selection result: `PUB_GC_E7_STANDALONE_SELECTION_RESULT.md` / `.json`.

Frozen dates: median-dynamics `2003-06-17`; high-dynamics `2003-05-20`. Groundwater fallback is the uncalibrated qualified F-GC44 conceptual fixture. No coupled output was observed before this freeze.


## Archival/release gate

Current state: **BLOCKED_GOVERNANCE_METADATA_NOT_SCIENCE**.

Controlling records:

- `PUB_GC_GMD_ARCHIVAL_GATE.md`;
- `PUB_GC_GMD_ARCHIVAL_GATE.json`.

Open blockers:

- A1 — SWAP5 publication release/version identifier: governance decision required;
- A2 — software licence / redistribution authority: governance or legal decision required;
- A3 — persistent exact-version archive and DOI: external archive action after A1/A2;
- A4 — final version-bound GMD title: depends on A1;
- A5 — final Code and data availability statement: depends on A2/A3.

No additional hydrological experiment is required to close these blockers.
