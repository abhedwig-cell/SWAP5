# SWAP5 research publication programme

Status: **living research-design index**

This directory contains the prospective publication and doctoral-research layer for SWAP5. It does not replace capability authority, qualification evidence or canonical scientific documentation.

## Programme documents

| Document | Status | Role |
| --- | --- | --- |
| `PHD_RESEARCH_PROGRAMME.md` | living hypothesis | overarching doctoral question, thesis, research arc and synthesis claims |
| `PUBLICATION_PORTFOLIO.md` | working governance contract | ownership/firewall rules across publications |
| `EVIDENCE_INVENTORY.md` | living evidence map | classifies existing and missing evidence across papers and thesis synthesis without rewriting chronology |
| `PUB-ME_SCIENTIFIC_CONTRACT.md` | initial contract | RQ1 / PRESERVE: evidence-preserving scientific model evolution |
| `PUB-SQ_SCIENTIFIC_CONTRACT.md` | initial contract | RQ2 / REPLACE: scientific qualification of alternative Richards solvers |
| `PUB-GC_SCIENTIFIC_CONTRACT.md` | developed initial contract | RQ3 / COUPLE: finite-window conservative groundwater-vadose coupling |
| `PUB-RC_SCIENTIFIC_CONTRACT.md` | initial contract | RQ4 / ACCELERATE: response-assisted nonlinear coupling |
| `PUB-SG_SCIENTIFIC_CONTRACT.md` | conditional contract | RQ5 / SCALE: hydrologic value of explicit subgrid vadose heterogeneity |

## Logical research arc

```text
PRESERVE
  PUB-ME
     |
     v
REPLACE
  PUB-SQ
     |
     v
COUPLE
  PUB-GC
     |
     v
ACCELERATE
  PUB-RC
     |
     v
SCALE (conditional)
  PUB-SG
```

This sequence is conceptual rather than a mandatory publication order. `PUB-ME` and `PUB-SQ` may develop partly in parallel, and later studies may reuse already qualified capabilities as infrastructure.

## One-owner rule

Primary scientific claims, manuscript figures and tables have one publication owner. Shared model cases, benchmark harnesses, telemetry and software infrastructure may support multiple publications.

Thesis-level synthesis claims use `THESIS-SYNTHESIS` and may combine conclusions from multiple papers without reassigning their primary provenance.

## Evidence classes

`EVIDENCE_INVENTORY.md` uses four explicit classes:

- `FOUNDATIONAL_EXISTING`: already existing capability or qualification evidence needed by a paper;
- `RETROSPECTIVE_CANDIDATE`: historical evidence that may be publication-usable after re-audit, but was not designed as a publication experiment;
- `SHARED_INFRASTRUCTURE`: reusable code, cases, telemetry or test surfaces without primary scientific ownership;
- `PROSPECTIVE_REQUIRED`: publication-grade evidence that still has to be generated under a scientific contract.

This distinction prevents the existence of substantial engineering/qualification work from being mistaken for a completed manuscript result.

## Current maturity

### PUB-ME

Already has a substantial real evidence base in the Status-A migration, explicit state/workspace ownership, transactional time stepping, reference preservation, qualification/admission chain and later semantic-successor preservation.

Largest research gap: systematic extraction of a transferable modernization method and selection of representative migration slices rather than narrating the full repository history.

### PUB-SQ

Already has a real reference solver authority, typed solver seam and admitted restricted RossFast production-selection route.

Largest research gap: expand from bounded implementation qualification to publication-quality equal-error/admissibility experiments over scientifically meaningful regimes.

### PUB-GC

Already has the strongest publication-specific contract and a bounded admitted Groundwater Coupling v1 basis.

Largest research gap: concrete MODFLOW 6 scientific backend/admission plus controlled convergence experiments against a declared numerical reference.

### PUB-RC

Already has a canonically admitted optional groundwater-side response-sensitivity contract (`F-GC29`) that binds response to the exact trial/candidate/window provenance and fails closed on unavailable/nonsmooth/invalid response.

Largest research gap: obtain/define the complementary SWAP-side whole-window response or a defensible approximation and demonstrate that response information improves total coupling cost relative to established accelerators.

### PUB-SG

Has MultiSWAP/N:1 structural groundwork but remains intentionally conditional.

Largest research gap: show a material hydrologic effect of explicit dynamic subgrid heterogeneity relative to credible effective representations. If this effect is absent, do not force a paper.

## Prospective evidence rule

Before a new experiment or development unit produces publication-relevant evidence, record:

```yaml
publication_relevance:
  primary: PUB-ME | PUB-SQ | PUB-GC | PUB-RC | PUB-SG | SHARED-INFRASTRUCTURE
  doctoral_rq: RQ1 | RQ2 | RQ3 | RQ4 | RQ5 | null
  thesis_synthesis_relevance:
    - TS1 | TS2 | TS3 | TS4
  hypothesis_status: pre_result | exploratory | post_result
  primary_claim: <one sentence or null>
  evidence:
    - <commit/test/run/artifact>
  excluded_primary_claims:
    - PUB-...
```

Negative findings and failed hypotheses are evidence and should remain traceable.

## Next programme-level work

The highest-value next steps are now:

1. perform a systematic novelty/literature review separately for each paper rather than one blended review;
2. convert the `PROSPECTIVE_REQUIRED` gaps in `EVIDENCE_INVENTORY.md` into explicit experiment matrices, starting with `PUB-ME`, `PUB-SQ` and `PUB-GC`;
3. introduce the publication-evidence metadata/telemetry fields before new publication-relevant runs are generated;
4. audit selected `RETROSPECTIVE_CANDIDATE` evidence before using it in figures or manuscript claims;
5. keep `PUB-RC` and `PUB-SG` dependent on evidence rather than predetermined paper count;
6. mature `PHD_RESEARCH_PROGRAMME.md` into a formal proposal only after supervisor/institutional framing and literature positioning have been added.
