# F-GC49B — Handle-based FMR groundwater participant registry

## Purpose

Stage B replaces qualification-specific direct access to individual FMR participant objects with one production registry that exposes opaque handles while preserving existing SWAP ownership.

The registry is not a new transaction owner. It delegates capture, trial, rollback/discard, publication preflight and commit to the already admitted `fmr_groundwater_swap_participant_t`.

## Ownership

The registry stores no copy of committed SWAP state. Active slots retain Fortran pointer associations to production-owned backend, parameters, committed state and groundwater-head forcing materializer. Column/template/config/datum metadata are copied as immutable binding metadata.

Kernel revision, committed time and physical state remain owned exclusively by the existing FMR/kernel path.

## Handles

Each registration receives a monotonically increasing opaque 64-bit handle. Handles are never recycled within a registry lifetime. Released slots are not reused. A full registry may be reinitialized only when no active registrations remain; the handle counter is deliberately not reset, so stale handles cannot become valid after reinitialization.

Tile ids must be unique among active registrations.

## Operations

The registry exposes: initialize, bind, release, capture_origin, trial_from_origin, discard_candidate, publication_ready, commit_candidate, identity, active_count, capacity and quiescent.

Release fails closed when a live candidate exists. A released handle cannot resolve. Reinitialization fails while registrations remain active.

## Scope boundary

F-GC49B owns no predictor/tangent construction, MODFLOW/XMI session, ledger, topology composition, timestep control or publication ordering. No C ABI/global singleton is introduced yet; F-GC49C will bind this registry into the generic live application context after Stage B is admitted.
