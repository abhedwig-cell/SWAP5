# SWAP5 research publication programme

Status: **living research-design index**

This directory contains the prospective publication and doctoral-research layer for SWAP5. It does not replace capability authority, qualification evidence or canonical scientific documentation.

## Programme documents

| Document | Status | Role |
| --- | --- | --- |
| `PHD_RESEARCH_PROGRAMME.md` | living hypothesis | overarching doctoral question, thesis, research arc and synthesis claims |
| `NOVELTY_STRESS_TEST_2026-09-18.md` | adversarial literature checkpoint | strongest prior-art collision and surviving novelty boundary for all five papers |
| `PHD_MASTER_RESEARCH_MATRIX_V2_2026-09-18.md` | prospective research-design authority | binds each RQ to hypotheses, experiments, comparators, primary endpoints and falsification criteria for future work |
| `PUBLICATION_PORTFOLIO.md` | working governance contract | ownership/firewall rules across publications |
| `EVIDENCE_INVENTORY.md` | living evidence map | classifies existing and missing evidence across papers and thesis synthesis without rewriting chronology |
| `EXPERIMENT_MANIFEST.md` | prospective evidence contract | common metadata, chronology, numerical-reference and artifact rules for publication experiments |
| `EXPERIMENT_REGISTER.md` | living readiness register | run-family status, blockers and next permitted experiment actions |
| `PUB-ME_SCIENTIFIC_CONTRACT.md` | initial contract | RQ1 / PRESERVE context and contribution boundary |
| `PUB-ME_EXPERIMENT_MATRIX.md` | prospective design | migration-slice, preservation, adversarial-state, restart and evidence-successor experiment programme |
| `PUB-SQ_SCIENTIFIC_CONTRACT.md` | initial contract | RQ2 / REPLACE: scientific qualification of alternative Richards solvers |
| `PUB-SQ_EXPERIMENT_MATRIX.md` | prospective design | common-domain, boundary, equal-error cost and trajectory experiment programme |
| `PUB-GC_SCIENTIFIC_CONTRACT.md` | developed initial contract | RQ3 / COUPLE: finite-window conservative groundwater-vadose coupling |
| `PUB-GC_EXPERIMENT_MATRIX.md` | prospective design | same-origin, whole-window, convergence, MODFLOW-transfer and bounded N:1 experiment programme |
| `PUB-RC_SCIENTIFIC_CONTRACT.md` | initial contract | RQ4 / ACCELERATE context and response-method boundary |
| `PUB-SG_SCIENTIFIC_CONTRACT.md` | conditional contract | RQ5 / SCALE context and subgrid/upscaling boundary |
| `manifests/FIVE_PAPER_RESEARCH_MANIFEST_INDEX.md` | draft freeze index | sharpened confirmatory questions, dependencies and freeze gates |
| `manifests/PUB-*-RESEARCH-MANIFEST.yaml` | draft freeze candidates | paper-level hypotheses, primary endpoints, design/holdout separation, thresholds and kill/merge criteria |

## Logical research architecture

```text
                    -> REPLACE / PUB-SQ
PRESERVE / PUB-ME --|
                    -> COUPLE / PUB-GC -> ACCELERATE / PUB-RC?
                                      \
                                       -> SCALE / PUB-SG?
```

`PUB-SQ` is not a prerequisite for `PUB-GC`; the coupling study may remain on the qualified Reference Richards solver. `PUB-RC` and `PUB-SG` are evidence-dependent standalone papers rather than guaranteed manuscript slots.

## One-owner rule

Primary scientific claims, manuscript figures and tables have one publication owner. Shared model cases, benchmark harnesses, telemetry and software infrastructure may support multiple publications.

Thesis-level synthesis claims use `THESIS-SYNTHESIS` and may combine conclusions from multiple papers without reassigning their primary provenance.

## Evidence classes

`EVIDENCE_INVENTORY.md` uses four explicit historical/current-state classes:

- `FOUNDATIONAL_EXISTING`: already existing capability or qualification evidence needed by a paper;
- `RETROSPECTIVE_CANDIDATE`: historical evidence that may be publication-usable after re-audit, but was not designed as a publication experiment;
- `SHARED_INFRASTRUCTURE`: reusable code, cases, telemetry or test surfaces without primary scientific ownership;
- `PROSPECTIVE_REQUIRED`: publication-grade evidence that still has to be generated under a scientific contract.

`EXPERIMENT_MANIFEST.md` further classifies actual publication runs as `PROSPECTIVE_PRIMARY`, `PROSPECTIVE_SUPPORTING`, `RETROSPECTIVE_REEXTRACTION`, `FOUNDATIONAL_QUALIFICATION` or `SHARED_INFRASTRUCTURE`.

This distinction prevents the existence of substantial engineering/qualification work from being mistaken for a completed manuscript result.

## Current maturity

### PUB-ME

Already has a substantial real evidence base in the Status-A migration, explicit state/workspace ownership, transactional time stepping, reference preservation, qualification/admission chain and later semantic-successor preservation.

The sharpened confirmatory question is now causal: whether explicit candidate-to-accepted scientific-state authority prevents or localizes prospectively defined contamination faults beyond a matched conventional architecture. Fault injection itself is not claimed as novel.

Largest remaining gap: construct the paired B0/B1 authority experiment, freeze mechanistically distinct fault families and holdouts, and execute them without changing the preservation oracle after outcomes are known.

### PUB-SQ

The candidate-independent material-axis sequence has advanced materially. P2E13 constructed a complete tested 36-material Reference-only common state domain on Se=0.65 through 0.96; P2E14 froze thresholds at prospectively selected anchors 0.65, 0.85 and 0.96 before new RossFast outcomes; P2E15 then admitted all 180 previously unobserved material-axis candidate cases under those frozen thresholds.

This supports transfer within the frozen common fixed-request domain, not universal solver equivalence, transaction-level equivalence or a speedup claim.

Largest remaining gap: preregister and execute the separate inside/boundary/outside admissibility experiment while keeping the P2E14 thresholds immutable. Equal-error performance follows only after that boundary is interpretable.

### PUB-GC

Interface conservation screening, held-out same-origin E1 primary evidence and GC-REF-A reference infrastructure now exist. The novelty stress test shows that coupling SWAP-like vadose models to MODFLOW, iterative feedback, N:1 mapping and multirate time integration are all insufficient novelty claims by themselves.

The future primary question is therefore discriminating: which finite-window exchange and acceptance semantics measurably change conservation, convergence, time-partition consistency or robustness at matched subsystem physics and error?

Largest remaining gap: execute E2 whole-window versus terminal exchange on new frozen mechanism cases, E3 refinement to GC-REF, E4 against fair prior-practice comparators, and E5 transfer to an admitted minimal MODFLOW 6 backend.

### PUB-RC

Already has a canonically admitted optional groundwater-side response-sensitivity contract (`F-GC29`) and active work toward complementary whole-window response capability.

The standalone paper is conditional. Its comparator must include Aitken and at least one strong generic black-box quasi-Newton route. The question is not whether tangents can accelerate coupling, but how much hydrologically meaningful interface information is worth exposing after acquisition cost and safeguards are counted.

Largest research gap: freeze the response ladder, strong generic baselines, matched-error cost metric and independent holdouts before confirmatory response comparisons.

### PUB-SG

Has MultiSWAP/N:1 structural groundwork but remains intentionally conditional. The novelty stress test showed that generic cross-regime failure of equivalent vadose representations is already too well established to support the paper by itself.

The prospective v2 question now isolates the incremental role of two-way dynamic shared-groundwater feedback: does that feedback alter transferability beyond an otherwise comparable prescribed-head or one-way groundwater treatment, and are the resulting errors tied to interpretable response transitions?

Largest research gap: revise the SG manifest to this narrower question, specify the prescribed-head/one-way control, freeze calibration and holdout regimes, and establish a numerical floor from SQ/GC before any large ensemble.

## Prospective evidence rule

Before a new experiment or development unit produces publication-relevant evidence, record at least the publication owner, doctoral question, hypothesis, chronology, exact code/configuration identities, comparator, numerical reference, primary metrics and excluded claim owners.

Use `EXPERIMENT_MANIFEST.md` as the controlling schema and `EXPERIMENT_REGISTER.md` as the readiness/next-action authority.

Negative findings and failed hypotheses are evidence and should remain traceable.

## Immediate programme-level next work

The current next-action authority is the v2 master matrix:

1. `PUB-ME`: materialize and qualify the matched B0/B1 research-only harness before confirmatory fault injection;
2. `PUB-SQ`: preregister the inside/boundary/outside admissibility experiment with P2E14 thresholds unchanged;
3. `PUB-GC`: prioritize E2/E3/E4 discriminating coupling experiments, followed by E5 MODFLOW 6 transfer;
4. `PUB-RC`: define a genuinely strong R1 black-box baseline and machine-independent work accounting before R2/R3 primary comparisons;
5. `PUB-SG`: revise the research manifest around dynamic shared-groundwater feedback and add the prescribed-head/one-way causal control before scaling up;
6. preserve negative results and chronology; do not turn exploratory evidence into prospective primary evidence after the fact.

## Experiment start gate

No run should be labelled `PROSPECTIVE_PRIMARY` until:

- the relevant scientific contract exists;
- the relevant experiment matrix exists;
- hypothesis and primary metrics are declared;
- comparator and numerical reference are declared;
- claim ownership is declared;
- the exact code/configuration/input identity can be persisted.

This is the point at which the programme moves from retrospective reconstruction to genuinely prospective doctoral/publication evidence.
