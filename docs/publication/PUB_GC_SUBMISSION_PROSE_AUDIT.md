# PUB-GC submission-prose audit

## Status

**JOURNAL-FACING SCIENTIFIC PROSE CLEANED WITHOUT CHANGING CLAIMS OR EVIDENCE**

Date: 2026-09-18.

Canonical basis at workunit start: `integration/f-ci-canonical@fb882329124297e9b21ae1816fbafc9debfed3fa`.

## Purpose

The repository manuscript must remain auditable, but a journal reader should not need to understand internal SWAP5 workunit identifiers to follow the science. This audit separates journal-facing scientific prose from repository evidence pointers.

## Changes applied

In the manuscript body before the References section:

- internal `F-GCxx` workunit identifiers: reduced from 30 occurrences to 0;
- `FMR` implementation label: reduced from 2 occurrences to 0;
- `PUB-GC` internal publication-line label: reduced from 4 occurrences to 0;
- `canonical` repository-governance wording: reduced from 4 occurrences to 0;
- repository-specific `qualification` wording was replaced by scientific descriptions such as controlled case, tested profile, response characterization, reproducible acceptance rule or component domain where those terms were more accurate;
- exact machine status `KERNEL_STATUS_NOT_ADMITTED` was retained because it is an observed result, not editorial governance language.

The exact repository workunit identifiers remain available after the References section under **Internal repository evidence pointers**, and in the claim/evidence ledger, preregistrations and result files.

## Scientific wording preserved

The cleanup does not weaken these central distinctions:

- candidate versus accepted state;
- trial flux versus authoritative whole-window transfer;
- prescribed-flux predictor map versus prescribed-head corrector map;
- valid component-domain failure versus outer coupling failure;
- fixed numerical interface criterion versus hydrological materiality;
- bounded E1–E6 evidence versus still-open E7 transferability.

## Deliberately retained technical terms

`production`, `qualified` and `admissibility` remain where they describe an actual deployed implementation, a fixed tested numerical criterion or the scientific availability domain of a component. They were not mechanically removed.

## Verdict

**NO SCIENTIFIC CLAIM CHANGE.**

The main manuscript is now journal-facing while the repository evidence layer remains fully traceable.
