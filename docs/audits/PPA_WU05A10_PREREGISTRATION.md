# PPA-WU05-A10 preregistration — FMR rapid macropore drainage

Date: 2026-10-01

Status: PREREGISTERED / POST-A9 CAPABILITY EXPANSION / NOT_ADMITTED

Baseline: integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5

## Purpose

Admit the already source-mapped A6 rapid-drainage physics into the bounded serialized single-column FMR macropore route.

## Fixed inherited authority

A8/A9 remain authority for:
- standard swmbf=1 macropore state and hydraulic views;
- Reference-Richards outer coupling;
- transaction/retry/rollback ownership;
- seven-field persistence/restart;
- source-faithful top input and external-source accounting.

## A10 owned scope

- main-domain rapid drainage only;
- source-bound multi-compartment kD weighting;
- drain-type/domain-depth activation;
- drainable-storage cap;
- one external rapid-drain receipt;
- FMR whole-column mass ledger inclusion exactly once.

## Hard invariants

- rapid drainage may only be owned by domain 1;
- the same water may not appear as matrix exchange and rapid external outflow;
- rejected trials publish no rapid-drain receipt;
- retry/rollback restores accepted macropore storage exactly;
- no new continuation state;
- disabled rapid drainage preserves A9 bitwise within the qualified envelope.

## First qualification envelope

- standard swmbf=1;
- surface-connected macropores;
- Reference Richards;
- serialized single-column FMR;
- no perched-zone physics;
- fixed dynamic crack geometry during one corrector;
- no RossFast;
- no parallel/concurrent MultiSWAP.

## Qualification path

1. reconcile current A9 production rapid-drain hold and mass ledger;
2. define immutable rapid-drain physical configuration;
3. derive dynamic rapid-drain view from accepted storage/geometry;
4. feed existing A6 rapid-drain evaluator through FMR;
5. book external rapid outflow once in transaction mass;
6. qualify positive drainage, storage cap, disabled preservation, retry/rollback and restart;
7. qualify A9 top-input + A10 rapid-drain composition;
8. only then form an admission candidate.