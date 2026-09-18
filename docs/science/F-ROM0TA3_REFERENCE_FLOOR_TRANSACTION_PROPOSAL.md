# F-ROM0TA3 successor proposal — Reference-floor qualification transaction

## Status

**DESIGN PROPOSAL ONLY. IMPLEMENTATION NOT YET AUTHORIZED.**

## Problem statement

The existing transaction modes answer an application-runtime question: whether a trial is temporally accurate enough to commit.

ROM-0 needs a different qualification question before any application/ROM error envelope exists: whether a prescribed fixed-resolution Reference trajectory is a valid committed numerical sample that can participate in a cross-resolution floor study.

Conflating these questions creates the F-ROM0TA2 circularity.

## Candidate semantic

Introduce a qualification-only temporal mode, provisionally named:

`TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION`

The mode would not assert temporal adequacy. It would assert only:

- the prescribed interval is part of an immutable preregistered resolution ladder;
- the Reference solve converged;
- mass accounting is complete and inside the unchanged hard mass gate;
- state/checkpoint ownership remains transactional;
- one successful candidate is committed exactly once;
- solver failure remains fail-closed;
- no automatic retry changes the requested fixed resolution unless the preregistration explicitly defines that retry as a separate resolution sample.

The resulting committed trajectory is labelled `REFERENCE_FLOOR_SAMPLE`, never ordinary application-accepted temporal authority.

## Why this is narrower than a new production policy

It introduces no new physics, no new nonlinear controls and no application tolerance. It exists to construct evidence about numerical resolution. Normal application execution continues to require the admitted external-full/half or model-certificate semantics.

The qualification mode must be inaccessible from ordinary application configuration unless an explicit qualification context is bound.

## Required design questions before implementation

1. Where should qualification-context authority live so that ordinary runtime cannot accidentally select this mode?
2. Can the existing transaction executor be parameterized without weakening the invariant that accepted production states have temporal acceptance evidence?
3. Should the committed-state status carry an explicit authority class, or is a qualification receipt external to state sufficient?
4. How should prescribed fixed-dt failure be represented: terminal failed sample, or a separately preregistered finer-resolution row?
5. Can restart/replay preserve the qualification authority class without adding physical state?
6. Which existing canonical diagnostics are sufficient to prove that the selected resolution was not silently subdivided?

## Proposed first qualification matrix after authority is approved

Reuse B01/B14 R1 seed and the already frozen symmetric 1% perturbation, but do not reuse R2 results as pass/fail tuning.

Temporal ladders:

- 0.0016 d;
- 0.0008 d;
- 0.0004 d;
- optionally 0.0002 d only if preregistered before first execution and needed to demonstrate an asymptotic range.

For each resolution, cover the same physical horizon and retain:

- pressure-head and theta profiles as diagnostic state;
- total storage;
- upper 0–40 cm storage;
- lower 40–160 cm storage;
- top/bottom accepted exchange;
- mass residual;
- solver work;
- exact interval count and requested/committed dt;
- replay/restart identity.

Cross-resolution analysis is performed only after each ladder trajectory has independently qualified as a valid fixed-resolution committed sample.

## Close criterion for the successor design

Implementation may start only after repository authority resolves the six design questions above and proves that the new authority class cannot be mistaken for normal production temporal acceptance.
