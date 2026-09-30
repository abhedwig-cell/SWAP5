# PPA-WU05-A4 preregistration — R2 coupled single-column prototype

Date: 2026-09-30

Status: `PREREGISTERED / RESEARCH_ONLY`

Baseline: `PPA-WU05-A3@8a3e4f4fe47ca211629a1ac297f692bc9b699320`

## Purpose

Construct the first transactionally correct R2 single-column macropore prototype using the interim R1 process map.

A4 starts with prescribed matrix/Richards state. It does not initially call the production Richards solver.

## Inherited authority

A4 inherits:

- exact B1.11 source authority from A1;
- seven-field typed continuation state and rollback/restart contract from qualified A2;
- interim R1 process map from A3;
- refined moving-interface rule from E7;
- locally conservative accepted vertical-flux reconstruction from R1-MSTATE02.

## First target

One accepted candidate step shall:

1. read immutable matrix hydraulic state and macropore committed state;
2. compute source-shaped macropore top inflow and matrix exchange;
3. update matrix water storage and macropore storage conservatively;
4. update all applicable continuation-history fields;
5. construct a separate candidate state;
6. support accept and reject without hidden state mutation;
7. publish one explicit mass receipt with internal exchange cancelling exactly.

## Hard holds

- no production activation;
- no direct mutation of committed state during trial;
- no hidden module-global continuation state;
- no timestep-policy tuning;
- no parameter calibration;
- no weakening of mass checks;
- no full Richards coupling before the prescribed-state prototype closes.

## Required first gates

- A4-G1 one-step two-reservoir mass closure;
- A4-G2 candidate isolation;
- A4-G3 reject/retry identity;
- A4-G4 sorptivity-memory regression against A3 E3;
- A4-G5 crack-history regression against A3 E4;
- A4-G6 interface reconstruction regression against A3 E7/R1-MSTATE02;
- A4-G7 bounded extreme-input behavior against A3 E9.

## Exit

The prescribed-state phase may close as:

`QUALIFIED_R2_PRESCRIBED_STATE_SINGLE_COLUMN_READY_FOR_RICHARDS_COUPLING`.

This is still a research qualification, not production admission.
