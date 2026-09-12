# F-GC18A — Groundwater Owner-Evidence Canonicalization Audit

## Purpose

F-GC18A is a governance, canonicalization, and evidence-integrity workunit. It does not modify SWAP5 production code, physics, numerical methods, kernel/runtime semantics, state layout, or coupling semantics.

Its purpose is to decide whether the qualified owner result for F-GC18/F-GC18R can currently be treated as current-canonical authority, and to record the exact evidence needed before a later canonical admission may proceed.

## Governing authority

Program authority:

- branch: `regie/f-rg01-post-rb1-program-rebaseline`
- commit: `09ef05c60c5e45af218980001c8ad8ec30da2e9e`

F-RG01 requires groundwater-family implementation work to be followed by independent qualification before canonical admission. An owner workunit cannot promote its own success into canonical authority.

## Current-canonical baseline

Final pre-write recheck for this workunit:

- branch: `integration/f-ci-canonical`
- commit: `eba90d79010b095b6556e93bd8b77a8c28d25560`
- commit message: `F-CI50P R1: finalize post-reconciliation closeout`

This F-GC18A branch is created directly from that exact current-canonical commit.

The current canonical does not contain the `integration/f-gc/` owner-evidence directory and does not itself carry the F-GC18/F-GC18R owner evidence as canonical evidence.

## Pinned owner authority

F-GC18R owner authority:

- branch: `work/f-gc18r-two-phase-commit-readiness`
- exact signed owner head: `7c1c5251a2dff94291db381cf0b66631b81e9f05`
- production authority recorded by F-GC18R: `e96a160dfa6d7202c2ece80306af7282cd40d831`
- exact-head owner workflow run: `34680882694`
- workflow conclusion: `success`

`integration/f-gc/F-GC18R_STATUS.json` at the pinned owner head explicitly records:

- `owner_approved: true`
- `canonical_admission: false`
- canonical and end-to-end admission are outside F-GC18R scope
- the result is ready for later composition, not itself canonical admission

The owner branch therefore provides valid owner evidence for the repaired transactional groundwater exchange contract, but it does not provide independent qualification or canonical authority.

## Production delta represented by the owner line

Relative to the current-canonical baseline, the F-GC18/F-GC18R owner line changes production files including:

- `src/f_driver/calcmodel_driver.f90`
- `src/kernel/kernel_api.f90`
- `src/kernel/kernel_types.f90`

F-GC18A does not copy, modify, merge, or otherwise admit those production files.

## Independent-qualification audit

Live repository checks found F-GC18 and F-GC18R owner branches, but no independent qualification branch or independent qualification authority for the exact F-GC18R owner head.

A newly present verifier branch, `qualification/f-vq59-fpm08d7-fixed-weir-current-canonical`, belongs to the unrelated F-PM08D7 fixed-weir capability. It is not evidence for F-GC18/F-GC18R and is not reused or reinterpreted here.

F-GC18A deliberately does not allocate or invent a verifier workunit number. Independent verification must remain independently owned.

## Canonical-admission precedent

F-CI50/F-CI50P/F-CI50P-R1 provide the current repository precedent for groundwater capability admission:

1. qualification first pins the current-canonical baseline, exact donor authority, production blobs, architecture constraints, and promotion conditions;
2. canonical promotion then preserves both histories in a true two-parent merge;
3. postpromotion reconciliation verifies the resulting current-canonical image and preserves the evidence chain.

Relevant precedent authorities include:

- F-CI50 prepromotion qualification head: `bbdba02d8aa51204191aea8ccb8f0fcfc0d0fb6b`
- F-CI50P reconciliation head: `a8da1d72800df8afd539b21a2040caeed7ead3bd`
- F-CI50P-R1 head: `96d274ddebf7c566dba84cdf9402a41c064978c3`
- resulting current-canonical closeout: `eba90d79010b095b6556e93bd8b77a8c28d25560`

F-GC18R has not yet passed the equivalent independent prepromotion qualification gate. Owner success cannot substitute for that gate.

## Decision

**BLOCKED_PENDING_INDEPENDENT_QUALIFICATION**

F-GC18R remains a valid owner-qualified development authority, but it is not current-canonical authority and is not yet eligible for canonical admission.

The next legally valid step is an independent qualification workunit that starts from the then-current `integration/f-ci-canonical`, pins the exact F-GC18R owner and production authorities, independently rechecks the relevant production delta and transactional/mass-conservation contracts, and emits an explicit admission decision.

Only after a positive independent qualification may a separate canonical-integration workunit perform a true history-preserving admission and postpromotion verification following the F-CI50 precedent.

Downstream owner branches may use F-GC18R as an explicit development dependency where their own scope allows that lineage. They must not cite F-GC18R as current-canonical authority before the missing qualification and admission steps are complete.

## Architecture-invariant assessment

F-GC18A changes no architecture or production semantics. All 30 SWAP core architecture invariants remain unchanged by this workunit.

The fail-closed decision specifically protects the transactional and coupling invariants around checkpoint/trial/commit/rollback, explicit groundwater interface semantics, mass conservation, generic coupling windows, runtime/coupler composition, and the prohibition on silent dependencies. It also satisfies the governance requirement that important architecture changes be explicitly assessed rather than silently promoted.

No claim is made here that the F-GC18R owner scaffold constitutes full real-production-tree, MODFLOW, MultiSWAP, or end-to-end qualification. Those limitations remain exactly as recorded by the owner evidence.
