# PPA-WU05-A21 — live RFM runtime readiness / fast-domain fate audit

Date: 2026-10-01

Status: CLOSED_TRUE_PHYSICS_OWNERSHIP_BLOCKER

Canonical authority:

    integration/f-ci-canonical@4a9878b03791b7b9d43aa34aa70ed7ccdce13b08

Prerequisites:

    PPA-WU05-A11 through A20 canonically admitted in their bounded scopes.

## Question

May the A20 fail-closed runtime guard now be removed so the admitted RFM entry
chain becomes a live production runtime?

## What canonical can already do

The admitted chain now owns:

    A11  unponded activation / matrix-preferential source partition
    A12  accepted hydraulic view -> K_surface and sorptivity inputs
    A13  transactional surface-event age
    A15  common unponded effective-supply receipt
    A16  matrix-share rebound through the existing B1.10 dynamic-top owner
    A17  explicit-parameter MB/IC endpoint routing receipt
    A19  dedicated RFM candidate state and exactly-once dt integration
    A20  dedicated optional-state carrier/checkpoint/storage topology

This is sufficient to admit and store preferential inflow conservatively.

## Canonical inventory after A20

The canonical RFM implementation paths are limited to:

    src/process/macropore/mod_rfm_unponded_activation.f90
    src/process/macropore/mod_rfm_surface_event_age.f90
    src/process/macropore/mod_rfm_surface_sorptivity.f90
    src/process/macropore/mod_rfm_preferential_router.f90
    src/runtime/mod_fmr_rfm_activation_binding.f90
    src/runtime/mod_rfm_unponded_surface_composition.f90
    src/runtime/mod_rfm_matrix_share_dynamic_top_binding.f90
    src/runtime/mod_rfm_physical_state.f90

There is no canonical RFM owner for:

    endpoint-class water -> matrix release/deposition
    MB wall exchange
    MB/deep-path bottom export or breakthrough
    fast-domain transit/residence time

## Why a live runtime would currently be physically incomplete

A17 produces positive preferential rates:

    MB rate
    endpoint-class IC rates

A19 integrates those rates exactly once into:

    mb_water_cm
    endpoint_water_cm(:)

but A19 has no admitted outflow or exchange term.

Therefore repeated live RFM intervals with preferential input would satisfy a
formal mass identity only by:

    fast_storage(t+dt) = fast_storage(t) + preferential_input

with no physically admitted fate for that water.

That is a valid storage bookkeeping identity, but it is not the reduced RFM
physical model established by the research line, where terminating paths must
ultimately deposit/exchange water and the persistent/deep fraction needs an
explicit deep-path fate.

Removing the A20 runtime guard at this point would therefore promote an
incomplete physical model merely because it conserves mass.

## Rejected shortcuts

### Reuse standard SWAP macropore exchange/state

Rejected.

A18 canonically established that the standard SWAP macropore continuation
state and topology are not a semantically neutral container for RFM endpoint
classes.

Using its exchange processes implicitly would reintroduce the existing SWAP
domain geometry into the reduced RFM model.

### Treat A10 rapid drain as RFM MB bottom export

Rejected.

A10 is an admitted standard-SWAP rapid-drain process with its own drain
topology, level, resistance and ownership semantics. It is not a generic
continuous RFM deep-path breakthrough boundary.

### Leave all preferential water in storage indefinitely

Rejected for live production admission.

This would change the physical meaning of both the terminating IC route and the
persistent/deep MB route and would make long simulations accumulation-driven.

## Required missing owners

At minimum, live RFM execution requires independently qualified owners for:

1. **terminating-path fate**
   - endpoint-class release/deposition into the matrix;
   - explicit timing/rate law;
   - exact equal-and-opposite fast-domain/matrix receipt;

2. **persistent/deep MB fate**
   - wall exchange and/or deep/bottom export consistent with the frozen f_MB
     semantics;
   - explicit external-vs-internal mass ownership;
   - no residual balancing against observed recovery;

3. **candidate/commit integration**
   - outputs/exchanges computed from accepted/candidate state without mutating
     committed state on rejected trials;
   - whole-column storage and external-flux closure.

## Decision

    SURFACE_ENTRY_CHAIN = READY
    DEDICATED_RFM_STATE_AND_CHECKPOINT = READY
    LIVE_RFM_RUNTIME = BLOCKED
    BLOCKER_CLASS = MISSING_FAST_DOMAIN_FATE_OWNER
    A20_RUNTIME_REJECT_GUARD = MUST_REMAIN
    STANDARD_MACROPORE_STATE_REUSE = FORBIDDEN
    A10_RAPID_DRAIN_AS_RFM_BOTTOM = FORBIDDEN
    STORAGE_ONLY_LIVE_ROUTE = REJECTED

## Resume condition

The live-runtime line may resume only when a source-backed, preregistered
fast-domain fate contract is available that defines at least the terminating
endpoint release/deposition semantics and the persistent/deep MB fate without
fitting a residual mass term.

A sensible successor split is:

    PPA-WU05-A22A — RFM terminating-endpoint release/deposition owner
    PPA-WU05-A22B — RFM MB wall/deep-path fate owner

Only after those owners are qualified should a later workunit remove the A20
runtime-reject guard and compose the complete live runtime.

## Stop rule

    TRUE_PHYSICS_OWNERSHIP_BLOCKER
