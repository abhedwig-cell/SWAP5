# F-MACRO-TRACER01-C — accepted SWAP5 water-transfer observer

Date: 2026-10-01

Status: RESEARCH_OBSERVER_IMPLEMENTED / INTERNAL_NET_FLUX_RECONSTRUCTION_QUALIFIED

## Purpose

Provide the ordered hydrology packet required by TRACER01-A without exposing or modifying HeadCalc internal scratch flux arrays.

## Canonical information available

The typed SWAP5 soil-water solve result already publishes:

    accepted candidate water content by node
    top flux
    bottom flux

while layer geometry supplies dz.

The scientific convention is:

    q > 0 upward.

Source providers distinguish nonnegative source and sink magnitudes.

## Reconstruction

For layer i:

    dS_i/dt = q_lower - q_upper + source_i - sink_i.

Therefore:

    q_lower = q_upper + dS_i/dt - source_i + sink_i.

Starting from the accepted top flux, every internal net interface flux is uniquely reconstructed from accepted start/end storage and explicit sources/sinks.

The final reconstructed lower interface must equal the accepted solver bottom flux.

Failure to close bottom flux rejects the observer packet.

## Event ordering

The observer emits a deterministic research transfer sequence per accepted hydrology substep:

1. top external inflow/outflow;
2. distributed sources;
3. downward internal transfers top-to-bottom;
4. upward internal transfers bottom-to-top;
5. distributed sinks;
6. bottom inflow/outflow.

This ordering is a numerical reference convention, not a claim about substep-resolved physical event chronology.

For that reason TRACER01 use must retain the accepted hydrology substep resolution and later demonstrate timestep/refinement stability before using the tracer result quantitatively.

## Scope

The observer reconstructs NET interface transfer over one accepted substep.

It is most defensible for the Spechtacker research case with no root uptake, no drainage and no subsurface irrigation during the short sprinkler experiment.

More complex source/sink topologies remain allowed only when all terms are explicitly supplied.

## Transaction rule

Only accepted hydrology endpoints may be observed.

Rejected solver trials generate no tracer-driving transfer packet.

## Decision

    INTERNAL_NET_INTERFACE_FLUX = RECONSTRUCTIBLE_FROM_ACCEPTED_BALANCE
    HEADCALC_INTERNAL_FLUX_ACCESS = NOT_REQUIRED
    BOTTOM_CLOSURE = HARD_GUARD
    ORDERED_RESEARCH_PACKET = AVAILABLE
    PRODUCTION_SOLVER_PHYSICS = UNCHANGED

## Next

TRACER01-D should construct the actual Spechtacker SWAP5 matrix-only case from source-backed initial theta, hydraulic parameters and irrigation forcing, run accepted hydrology substeps, pass each accepted packet through TRACER01-C and then through the TRACER01-A tracer kernel.

Before fitting RFM parameters, perform timestep-refinement of the reconstructed transfer/tracer trajectory.
