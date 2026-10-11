# TRACE Exposure Batch 01

Date selected: 2026-09-19
Model: SWAP
Selection ref: `1720abc365a9d0a65ea8253df2f94c991f2b9fc1`
Status: `SELECTED_BEFORE_DETAILED_INSPECTION`

## Purpose

Create the first prospective denominator exposure without selecting components because they are suspected to contain discrepancies.

## Selection rule

Batch 01 uses three scientific-representation strata:

1. process/constitutive relation;
2. boundary/transfer relation;
3. numerical-scientific convention.

Selection used repository directory/file names only. Detailed document contents, source implementations and executable evidence for these selected elements are inspected only after this batch is persisted.

Known TRACE historical-pilot discrepancies are not eligible for confirmatory counting even if they fall inside a selected element.

## Selected elements

| Element ID | Stratum | Surface used to identify element |
|---|---|---|
| TRACE-ELEM-SWAP-B01-001 | process relation | `docs/science/drainage-formulations.md` |
| TRACE-ELEM-SWAP-B01-002 | boundary relation | `docs/science/hydrological-boundary-conditions.md` |
| TRACE-ELEM-SWAP-B01-003 | numerical-scientific convention | `docs/numerics/richards-solver.md` |

## Prospective handling

For each element, reconciliation follows theory/documentation -> implementation trace -> pre-existing executable/regression evidence. If a previously unknown possible discrepancy is encountered, inspection stops at the point needed to describe the conflict, a TRACE candidate is registered and pre-resolution evidence is frozen before resolution work continues.

An element with no confirmed discrepancy remains part of the denominator and is closed with `no_discrepancy_observed=true`.

This batch is not a random sample of SWAP science. It is a planned, stratified exposure batch intended to make the inspection process observable and prevent result-driven component selection.
