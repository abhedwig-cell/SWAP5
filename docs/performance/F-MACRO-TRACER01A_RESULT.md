# F-MACRO-TRACER01-A — conservative matrix-tracer reference kernel

Date: 2026-10-01

Status: RESEARCH_REFERENCE_IMPLEMENTED / CONTRACT-TESTABLE / PRODUCTION_UNCHANGED

## Purpose

Implement the disposable matrix-tracer validation oracle preregistered for the RFM bromide forward-validation program.

## Implementation

Added:

    tools/research/macropore_tracer01_matrix_reference.py

The kernel transports one inert tracer through an externally supplied ordered water-transfer journal.

It owns no hydrology.

Inputs are accepted tracer mass by layer, start/end water storage by layer and ordered transfer events.

For donor-layer transfers the advected tracer mass is determined by the donor concentration immediately before the transfer:

    c_i = M_i / W_i
    dM = dW * c_i.

This is a deliberately minimal donor-cell / well-mixed-layer reference.

## Water ownership guard

Water storage is reconstructed only as scratch state.

After all events, reconstructed end water must equal the hydrology-owned end water. Any mismatch fails the trial.

## Exact tracer ledger

For every valid trial:

    M_initial + M_external_input - M_external_output - M_final = 0

to floating-point tolerance.

No residual mass is assigned to f_MB or any other RFM parameter.

## Transaction semantics

The accepted tracer state is immutable. Evaluation returns a candidate without mutating accepted state. Commit is a separate explicit operation.

## Qualification surface

A standard-library contract test covers zero-flow invariance, internal redistribution, external input/export, hydrology mismatch, impossible outflow, invalid numeric input, deterministic replay, rollback preservation and explicit commit.

## Scientific limitation

The reference kernel assumes complete mixing within each matrix layer for the advective transfer sequence.

It contains no dispersion, molecular diffusion, immobile-water exchange, sorption or reaction.

This is intentional. TRACER01-A establishes the no-dispersion baseline.

## Replacement rule

Future ANIMO5 may replace this kernel behind the same contract:

    hydrology packet -> conservative matrix tracer profile -> ALT55 tracer ledger.

No RFM physics should depend on implementation details of this reference kernel.

## Decision

    DISPOSABLE_REFERENCE_KERNEL = IMPLEMENTED
    HYDROLOGY_OWNERSHIP = PRESERVED
    TRACER_MASS_CONSERVATION = HARD_CONTRACT
    ROLLBACK_SEMANTICS = EXPLICIT
    DISPERSION = NOT_IMPLEMENTED
    PRODUCTION_BUILD = UNCHANGED

## Next

TRACER01-B should bind a real, source-backed Weiherbach/Spechtacker hydrology packet to this kernel.

The first test is deliberately no-dispersion. If the hydrology source does not expose a defensible ordered transfer sequence, stop on that interface blocker rather than inventing one.
