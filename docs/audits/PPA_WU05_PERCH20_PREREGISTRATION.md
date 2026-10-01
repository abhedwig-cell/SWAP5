# PPA-WU05-PERCH20 preregistration — macropore reduction numerical continuation

Date: 2026-10-01

Status: `PREREGISTERED / RESTART_LAYOUT`

Baseline:
`integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`

Source authority:

- A18 solver-stable Andelst perched fixture;
- PERCH19 exact `FrReduQ` controller;
- canonical Restart-v1 numerical-continuation axis.

## Purpose

Persist the accepted PERCH19 reduction controller continuation through the serialized FMR
transaction and Restart-v1 boundary without adding fields to the seven-field macropore
physical continuation state.

## Ownership

The continuation is numerical, not physical.

A new numerical continuation layout owns exactly:

- reduction level / legacy `IDecMpRat`;
- stable accepted-step counter / legacy `NStep`;
- previous accepted timestep / legacy `dtold`;
- whether previous timestep authority is available.

The existing macropore seven-field state remains unchanged.

## Transaction rule

A trial receives the accepted numerical continuation by value.

Retries may mutate only trial-local continuation.

On successful candidate publication, the resulting continuation is carried by the
candidate state.

Rejected/discarded candidates never alter committed continuation.

Commit publishes physical and numerical continuation atomically through the existing
kernel candidate/commit boundary.

## Restart rule

The template explicitly selects the new numerical-continuation layout.

Restart-v1 must:

- accept the matching typed state family;
- reject layout mismatches;
- export the committed controller continuation;
- restore it exactly into a fresh committed runtime;
- start the next interval from the restored factor/counter/dtold.

No solver/Newton scratch is persisted.

## Gates

1. exact typed layout and template matching;
2. commit-only publication;
3. rejected-candidate isolation;
4. uninterrupted versus restarted continuation identity;
5. recovery semantics across restart;
6. A18/PERCH19 active perched result preservation;
7. A8-A10 default-route preservation.

## Decision

Only after all gates pass may PERCH20 become the production-admission candidate for the
perched inner-callback route.
