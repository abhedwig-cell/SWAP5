# SWAP5 research publication programme

Status: **living research-design index**

This directory contains the prospective publication and doctoral-research layer for SWAP5. It does not replace capability authority, qualification evidence or canonical scientific documentation.

## Programme documents

| Document | Status | Role |
| --- | --- | --- |
| `PHD_RESEARCH_PROGRAMME.md` | living hypothesis | overarching doctoral question, thesis, research arc and synthesis claims |
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

Already has a real reference solver authority, typed solver seam and admitted restricted RossFast production-selection route.

The experiment matrix now separates contract/fail-closed qualification, common-domain equivalence, admissibility-boundary probing, equal-error cost and whole-trajectory accumulation.

Largest remaining gap: freeze scientifically justified accuracy thresholds and the primary stratified case matrix, then construct `REF-HIGH` numerical references.

### PUB-GC

Already has a bounded admitted Groundwater Coupling v1 basis.

The experiment matrix now separates interface conservation, same-origin replay, whole-window exchange, coupling-window convergence, robustness, minimal MODFLOW 6 transfer and bounded N:1 conservation.

Largest remaining gap: freeze fair comparator definitions, implement/qualify any missing converged replay method and concrete MODFLOW 6 backend, then construct `GC-REF`.

### PUB-RC

Already has a canonically admitted optional groundwater-side response-sensitivity contract (`F-GC29`) and active work toward complementary whole-window response capability.

The standalone paper is conditional. Its comparator must include Aitken and at least one strong generic black-box quasi-Newton route. The question is not whether tangents can accelerate coupling, but how much hydrologically meaningful interface information is worth exposing after acquisition cost and safeguards are counted.

Largest research gap: freeze the response ladder, strong generic baselines, matched-error cost metric and independent holdouts before confirmatory response comparisons.

### PUB-SG

Has MultiSWAP/N:1 structural groundwork but remains intentionally conditional. N:1 mapping itself is established prior art and is not a novelty claim.

The sharpened question is cross-regime transferability: calibrate one equivalent full dynamic column under a declared regime, freeze it, and test whether it remains representative when forcing and groundwater dynamics change.

Largest research gap: define a fair equivalent-column calibration, holdout regimes and hydrologic materiality thresholds above the solver/coupling numerical floor.

## Prospective evidence rule

Before a new experiment or development unit produces publication-relevant evidence, record at least the publication owner, doctoral question, hypothesis, chronology, exact code/configuration identities, comparator, numerical reference, primary metrics and excluded claim owners.

Use `EXPERIMENT_MANIFEST.md` as the controlling schema and `EXPERIMENT_REGISTER.md` as the readiness/next-action authority.

Negative findings and failed hypotheses are evidence and should remain traceable.

## Immediate programme-level next work

The highest-value next steps are now:

1. execute the `EXPERIMENT_REGISTER.md` **Tranche A** as manifest-backed screening/evidence extraction, not yet final manuscript inference;
2. define and freeze `PUB-SQ-REF-HIGH`, `PUB-GC-GW-A` and `PUB-GC-GC-REF` before primary numerical comparisons;
3. select and freeze the `PUB-ME` migration-slice set before detailed historical extraction;
4. introduce shared publication telemetry serialization before new numerical evidence is generated;
5. perform systematic novelty/literature review separately for each paper, with `PUB-ME`, `PUB-SQ` and `PUB-GC` first;
6. audit selected `RETROSPECTIVE_CANDIDATE` evidence before using it in figures or manuscript claims;
7. freeze the five paper-level research manifests before any new confirmatory campaign, including immutable holdout fingerprints and materiality-threshold authority;
8. keep `PUB-RC` and `PUB-SG` dependent on evidence rather than predetermined paper count;
9. mature `PHD_RESEARCH_PROGRAMME.md` into a formal proposal only after supervisor/institutional framing and literature positioning have been added.

## Experiment start gate

No run should be labelled `PROSPECTIVE_PRIMARY` until:

- the relevant scientific contract exists;
- the relevant experiment matrix exists;
- hypothesis and primary metrics are declared;
- comparator and numerical reference are declared;
- claim ownership is declared;
- the exact code/configuration/input identity can be persisted.

This is the point at which the programme moves from retrospective reconstruction to genuinely prospective doctoral/publication evidence.
