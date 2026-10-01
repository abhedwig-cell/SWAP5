# PPA-WU05-A9 preregistration — source-faithful surface-connected macropore top input

Date: 2026-10-01

Status: PREREGISTERED / POST-A8 CAPABILITY EXPANSION / NOT_ADMITTED

Baseline: integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e

## Purpose

Extend the canonically admitted bounded A8 macropore FMR route with source-faithful surface-connected top input.

## Scope

This work unit owns only the top-input forcing and ownership chain:
- precipitation;
- irrigation;
- snowmelt;
- runon;
- accepted surface/ponding availability;
- macropore vertical/lateral top-input request;
- cross-domain redistribution;
- returned surface receipt.

## Fixed inherited authority

A8 remains authority for:
- standard swmbf=1 storage canonicalization;
- dynamic hydraulic views;
- Reference-Richards outer coupling;
- seven-field continuation state;
- transaction/rollback/restart ownership.

## Hard invariants

- no water source may be counted both in matrix top boundary and macropore top input;
- macropore top input is a partition of already owned surface supply, never a new source;
- rejected trials publish neither accepted macropore input nor returned-surface receipts;
- unused/rejected macropore share returns to the surface owner before final accepted boundary accounting;
- disabled top-input route must preserve A8 bitwise within the qualified envelope;
- physical forcing stays separate from numerical coupling policy.

## Explicit non-scope

- perched-zone physics;
- rapid drainage;
- within-corrector dynamic crack-geometry feedback;
- RossFast;
- parallel/concurrent MultiSWAP.

## Qualification path

1. reconcile current FMR/dynamic-top-boundary forcing ownership;
2. define immutable/step forcing carrier for source-faithful top supply;
3. derive top-input request without double counting;
4. compose returned-surface receipt back into the surface owner;
5. qualify local conservation and disabled preservation;
6. qualify real Reference Richards + FMR transaction/restart;
7. only then declare admission candidate.