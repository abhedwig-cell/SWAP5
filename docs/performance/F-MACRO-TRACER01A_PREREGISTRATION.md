# F-MACRO-TRACER01-A — disposable conservative matrix-tracer reference kernel

Date: 2026-10-01

Status: PREREGISTERED_RESEARCH_REFERENCE / NOT_PRODUCTION / RFM_PHYSICS_FROZEN

Branch: research/f-macro-tracer01-reference-kernel

Baseline research authority:
    research/f-macro-alt01-memory-falsification@065fa3c60ea8a194a09ec6744bfdb698ccfa8f6a

Canonical SWAP5 authority:
    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Provide the smallest replaceable conservative matrix-tracer reference kernel needed to execute the Spechtacker/Colpach bromide forward-validation program before ANIMO5 is operational.

This kernel is a validation oracle, not a production subsystem.

## Frozen scope

Included:

- one inert conservative tracer;
- layer water storage supplied by an external hydrology owner;
- ordered interval water-transfer events supplied by that owner;
- first-order upwind / perfectly mixed donor-cell advective tracer movement;
- external tracer input with explicit concentration;
- external tracer export;
- exact water reconstruction check;
- exact tracer mass ledger;
- immutable accepted state and candidate trial result;
- explicit commit as a separate operation.

Excluded:

- dispersion;
- diffusion;
- adsorption;
- degradation;
- reactions;
- density effects;
- macropore physics;
- any calibration parameter inside the tracer kernel;
- timestep selection;
- production ABI;
- replacement of future ANIMO5 transport.

## Ownership

Hydrology owns:

    start water storage
    end water storage
    ordered water transfer events

The tracer kernel owns only:

    tracer mass by matrix layer
    candidate tracer mass by matrix layer
    cumulative external tracer export for the trial

The kernel may reconstruct a scratch water trajectory solely to evaluate donor concentration during the ordered transfers.

That scratch trajectory is not persistent hydrology state.

Hard condition:

    reconstructed end water == hydrology-supplied end water

within floating-point tolerance.

If not, the trial fails closed.

## Transfer event semantics

Each event contains a positive water amount and exactly one route:

    external -> layer
    layer -> layer
    layer -> external

For external -> layer:

    tracer mass input = water amount * explicit tracer concentration.

For a transfer leaving a matrix layer:

    concentration = tracer_mass / water_storage

immediately before that transfer.

Tracer moved:

    min(donor tracer mass, water amount * concentration).

Because concentration is homogeneous within the donor layer, this is the standard donor-cell/upwind conservative reference.

## Numerical interpretation

The event list is ordered.

Therefore this kernel does not invent an ordering for interval-integrated fluxes that were supplied only as unordered totals.

A hydrology adapter must provide either substep-ordered transfers or another explicitly qualified ordering contract.

## Trial semantics

evaluate_trial performs validation, deep-copy trial execution, ledger checks and returns a candidate without mutating accepted state.

commit_trial accepts only a valid candidate and performs no recalculation.

Rejected trials publish nothing into accepted physical state.

## Qualification tests

TRACER01-A must pass at minimum:

1. zero-flow invariance;
2. closed-column internal redistribution conservation;
3. external source mass accounting;
4. external export mass accounting;
5. exact water end-state reconstruction;
6. reject impossible outflow larger than donor water;
7. reject negative/NaN input;
8. repeated evaluation is deterministic;
9. rejected candidate leaves accepted state bit-identical;
10. commit promotes only candidate tracer state.

## Stop rule

Do not add dispersion in TRACER01-A.

TRACER01-B may investigate dispersion only after a real Spechtacker forward run shows a systematic profile-broadening failure of the advection-only reference that cannot be explained by RFM IC endpoint deposition, MB wall exchange, sampling geometry or hydrology transfer resolution.

## Success condition

TRACER01-A closes when the reference kernel exists, contract tests pass locally, ownership and trial semantics are explicit, and no production source/build path is modified.

Then proceed to a source adapter for real SWAP5/Weiherbach hydrology packets.
