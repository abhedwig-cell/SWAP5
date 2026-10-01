# PPA-WU05-A21 — live RFM runtime release/exchange ownership audit

Date: 2026-10-01

Status: TRUE_PHYSICS_OWNERSHIP_BLOCKER / LIVE_RFM_RUNTIME_NOT_AUTHORIZED

Canonical authority:

    integration/f-ci-canonical@4a9878b03791b7b9d43aa34aa70ed7ccdce13b08

Canonically admitted bounded prerequisites:

    A11 unponded activation
    A12 hydraulic K/S binding
    A13 surface-event age
    A15 unponded surface composition receipt
    A16 matrix-share dynamic-top rebinding
    A17 explicit-parameter preferential routing
    A19 dedicated RFM physical state
    A20 optional-state carrier/checkpoint topology

A20 still intentionally enforces:

    FMR_OPTIONAL_STATE_LAYOUT_RFM
      -> KERNEL_STATUS_NOT_ADMITTED

for live execution.

## Purpose

Determine whether the A20 runtime guard can now be removed without inventing
new fast-domain physics.

The missing question is what physically owns release from:

    MB fast storage
    terminating endpoint-class storage

after A17/A19 have admitted and stored preferential input.

## ALT34 end-to-end research composition

The strongest end-to-end research composition is F-MACRO-ALT34.

It is conservative, but its fast-domain release layer contains two explicit
research assumptions:

    VELOCITY_CM_H = 100

for terminating-path transit/deposition, and:

    release fraction = 1 - exp(-1 * dt_hour)

for MB release, equivalent to a fixed MB release rate of 1 h^-1.

The script then publishes:

    MB bottom receipt
    IC deposition
    residual fast storage.

Those release laws are what turn routed fast storage into downstream physical
receipts.

## Why those laws cannot be promoted implicitly

The final ALT30 parameter contract contains the leading free/derived roles:

    sigma_B
    f_MB
    p
    optional chi_wall
    ell_ex from structure
    Z_AH / Z_IC from profile structure
    K_surface / S_surface from hydraulics

It does not admit:

    a universal 100 cm/h transit velocity
    a universal 1 h^-1 MB release constant.

No independent production qualification was found for those two constants.

Therefore A21 may not silently embed them merely because ALT34 used them for a
research composition screen.

## Wall exchange is not yet a replacement release owner

ALT27/28 and ALT29 establish a plausible reduced wall-exchange theory:

    q_philip ~ chi_wall * (4/ell_ex) * S_wall * Delta sqrt(t)
    q_darcy  ~ f_shape * 8*K*|Delta h|/ell_ex^2 * Delta t

and the canonical standard FMR runtime already has source-owned wall-water
exchange for the standard SWAP macropore geometry.

However, the RFM-specific production state needed for this path is incomplete.

ALT30 explicitly lists persistent RFM wall history:

    wall-event sorptivity
    wall-event age

while A19 deliberately admits only:

    mb_water_cm
    endpoint_water_cm(:)
    tau_surface_day.

A21 therefore cannot compose a production RFM wall-exchange path without first
admitting the missing wall-contact state and mapping its geometry/ownership.

## Why a storage-only live route is rejected

A technically mass-conservative implementation could simply accumulate all A17
preferential input forever in A19 fast storage.

That is not the qualified RFM physical semantics.

ALT34's intended downstream roles are:

    terminating IC -> deposition into matrix/profile
    persistent MB -> continuing/deep receipt
    residual fast storage -> transient remainder.

Treating all routed water as permanent storage would replace the RFM routing
model by a different physical model.

Therefore:

    STORAGE_ONLY_LIVE_RFM = REJECTED_SEMANTIC_MISMATCH.

## Why direct instantaneous endpoint deposition is also not yet authorized

A17 provides endpoint-class routing weights and rates, but it does not define
an instantaneous matrix-source injection operator.

ALT34 includes finite transit before deposition.

Replacing that by immediate endpoint deposition would remove a research
information role and is a new approximation requiring its own qualification.

Therefore:

    INSTANT_ENDPOINT_DEPOSITION = NOT AUTHORIZED.

## MB bottom/deep ownership remains unresolved

The tracer/source audit already established that standard canonical FMR has no
independent continuous macropore bottom-export owner.

Rapid drainage has separate drain semantics and cannot be relabeled as MB
bottom breakthrough.

Thus the MB fraction cannot currently be given a source-faithful continuous
deep-export owner in production.

## Decision

    A11_TO_A20_UPSTREAM_COMPOSITION = PRODUCTION_GRADE_PRIMITIVES_AVAILABLE
    LIVE_RFM_EXECUTION_GUARD = KEEP
    ALT34_IC_VELOCITY_100_CM_H = RESEARCH_ASSUMPTION_NOT_ADMITTED
    ALT34_MB_RELEASE_1_PER_H = RESEARCH_ASSUMPTION_NOT_ADMITTED
    RFM_WALL_EVENT_STATE = NOT YET ADMITTED
    STORAGE_ONLY_RUNTIME = REJECTED
    INSTANT_ENDPOINT_DEPOSITION = NOT AUTHORIZED
    STANDARD_FMR_MB_BOTTOM_OWNER = ABSENT
    LIVE_END_TO_END_RFM_RUNTIME = BLOCKED

## Resume conditions

A21 may resume only after at least one physically complete downstream route is
independently admitted.

Valid routes include:

1. qualify an RFM transit/release model with independently justified parameters
   for IC deposition and MB continuation;

2. admit RFM wall-contact state and source-backed wall exchange, plus a separate
   owner for any surviving/deep MB water;

3. obtain direct observations sufficient to qualify the required transit,
   deposition and/or deep-release parameters.

A restricted future mode may also be considered if it is separately
preregistered and scientifically meaningful, but it must not be obtained by
silently setting unqualified release times to zero or infinity.

## Stop rule

    TRUE_PHYSICS_OWNERSHIP_BLOCKER

The A20 runtime fail-closed guard remains the correct production state.
