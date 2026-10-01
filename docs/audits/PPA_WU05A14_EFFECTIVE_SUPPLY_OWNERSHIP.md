# PPA-WU05-A14 — RFM effective infiltrating-supply ownership audit

Date: 2026-10-01

Status: TRUE_OWNERSHIP_BLOCKER / EFFECTIVE_INFILTRATING_SUPPLY_RECEIPT_ABSENT

Canonical authority:

    integration/f-ci-canonical@ad0737b1a9968ba7a14933dd8332b37f94ad8a37

Prerequisites already canonical and closed:

    PPA-WU05-A11 — bounded unponded RFM activation
    PPA-WU05-A12 — hydraulic-view / K / sorptivity binding
    PPA-WU05-A13 — transaction-safe surface-event age

## Purpose

Determine whether canonical already exposes a transactionally owned surface receipt that can be supplied to A11/A12/A13 as effective infiltrating supply after surface-boundary handling, without inventing another ponding/runoff law or reversing solver ownership.

## Canonical surface-boundary owner

The B1.10 dynamic-top provider already owns the matrix surface-boundary calculation. It consumes precipitation, irrigation, snowmelt, runon, evaporation demands, previous ponding, runoff parameters and matrix hydraulic state, and publishes actual_top_flux, candidate ponding, runoff, net potential surface flux and surface regime/head.

## Why actual_top_flux is not the missing RFM source receipt

actual_top_flux is produced by evaluating the dynamic top boundary against the matrix hydraulic state/candidate. It is therefore already the result of the matrix boundary problem.

Using that value as the source that is then partitioned into matrix + preferential would be circular:

    matrix-only boundary solve
      -> actual matrix top flux
      -> RFM repartition
      -> altered matrix top flux.

That reverses ownership. A new coupled surface/RFM solve could be designed, but that is a new composition contract and is not authorized by A11-A13.

## Why A9 top input is not the missing receipt

The admitted A9/FMR carrier provides source-faithful net rain, net irrigation, melt and lateral overland input. mod_fmr_macropore_top_input converts those source terms into requested macropore input before the standard macropore limiter.

It does not publish a common post-boundary quantity equivalent to total effective infiltrating supply available for subsequent matrix-versus-RFM partition. Its accepted/returned-surface receipt is produced only after the standard macropore route has already applied its own area partition and capacity limiter.

Therefore neither the A9 requested source nor its post-limiter receipt can be silently reinterpreted as the RFM activation source.

## Surface-water coupling does not close the gap

The admitted surface-water participant/materializer owns resolved external surface-water heads and soil-to-surface exchange for its bounded profile. It does not expose the required common atmospheric effective-infiltration receipt for RFM activation.

## Required missing contract

Before runtime RFM source partition can be admitted, one explicit surface composition owner must publish for the same physical interval and accepted origin:

1. atmospheric/runon source available to the soil surface;
2. evaporation ownership;
3. prior/candidate ponding ownership;
4. runoff ownership;
5. the quantity that RFM is allowed to partition while still unponded;
6. a fail-closed transition when head-controlled/ponded semantics take over;
7. exactly-once whole-column mass receipts;
8. candidate-only publication with reject/retry/restart semantics.

This owner must compose matrix and RFM capacities together. It cannot first solve the matrix boundary and repartition the matrix result afterwards.

## Decision

    A11_ACTIVATION_SERVICE = CANONICAL
    A12_HYDRAULIC_BINDING = CANONICAL
    A13_EVENT_AGE_SERVICE = CANONICAL
    MATRIX_DYNAMIC_TOP_OWNER = AVAILABLE
    A9_SOURCE_COMPONENT_CARRIER = AVAILABLE
    COMMON_POST_BOUNDARY_RFM_PARTITION_SUPPLY = ABSENT
    MATRIX_ACTUAL_TOP_FLUX_AS_RFM_SOURCE = REJECTED_CIRCULAR
    A9_REQUESTED_MACRO_SOURCE_AS_RFM_SOURCE = REJECTED_SEMANTIC_MISMATCH
    A9_POST_LIMITER_RECEIPT_AS_RFM_SOURCE = REJECTED_AFTER_DIFFERENT_PARTITION
    ACTUAL_RUNTIME_RFM_SOURCE_PARTITION = BLOCKED
    NEW_RUNOFF_LAW = NOT_AUTHORIZED
    EXISTING_A8_A9_A10_BEHAVIOR = PRESERVED

## Resume condition

Resume production runtime integration only under a new, preregistered surface-composition workunit that freezes one joint ownership contract for external source -> surface storage/runoff/evaporation -> unponded matrix/RFM partition -> transition to head-controlled surface regime.

That workunit must preserve existing Reference dynamic-top behavior and qualify exact mass, reject/retry and restart behavior. No further RFM physics or empirical parameter fitting is required to resolve this blocker. The blocker is architecture/ownership.