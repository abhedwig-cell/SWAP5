# PPA-WU05-A25 preregistration — bounded live RFM runtime orchestrator

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e

## Purpose
Replace the A20 fail-closed RFM runtime guard only after a real orchestrator exists that composes the canonically admitted A11-A24 primitives.

A25 is not a one-line guard removal.

## Admitted dependency chain
A11 activation; A12 hydraulic binding; A13 event age; A15 surface receipt; A16 matrix-share dynamic-top rebinding; A17 preferential routing; A19/A20 dedicated state/checkpoint carrier; A22A terminating endpoint release; A22B MB wall/deep fate; A23 whole-column ledger; A24 frozen accepted-state matrix-source/Richards split.

## Bounded runtime scope
Initial A25 runtime is only:
- unponded, runoff-free B1.10 flux regime;
- explicit caller/config-owned sigma_B, f_MB, p, Z_AH, Z_IC, ell_ex/chi_wall and endpoint structure;
- no standard SWAP macropore route simultaneously active;
- Reference Richards matrix solver;
- accepted-state frozen first-order RFM/Richards split;
- candidate-only RFM state mutation;
- deep MB receipt explicit and separate from matrix qbot;
- fail closed to NOT_ADMITTED/Reference for ponded/head-controlled unsupported cases.

## Admission rule
The A20 guard may be removed only in the same qualified postimage that contains the orchestrator and proves:
1. RFM physics is actually invoked;
2. accepted origin remains immutable;
3. candidate commit/discard uses existing transaction ownership;
4. exact whole-column water ledger;
5. retry replay identity;
6. zero-RFM limit reproduces the ordinary matrix route;
7. unsupported surface regime fails closed.

## First implementation slice
Create a pure/trial-local orchestrator data contract that composes already-qualified receipts and builds:
- matrix surface share;
- RFM matrix node-source additions;
- candidate endpoint state;
- MB deep receipt;
- A23 ledger.

Do not edit the backend guard until this slice is executable and qualified.
