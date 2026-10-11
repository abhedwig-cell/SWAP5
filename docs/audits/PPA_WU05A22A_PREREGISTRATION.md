# PPA-WU05-A22A preregistration — RFM terminating-endpoint release owner

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@81b7feda17f53a94ab4e5877467cc4499de6f568
Parent blocker: PPA-WU05-A21

## Purpose
Admit a candidate-only terminating endpoint storage -> matrix release owner without the ALT34 research transit velocity.

## Frozen physics
Vertical delivery to the terminating endpoint is instantaneous on the SWAP model time scale. Matrix uptake at the endpoint uses the reduced ALT27/28 wall law:

    dW_philip/dz = chi_wall*(4/ell_ex)*S_wall*Delta sqrt(t)
    dW_darcy/dz  = 8*K*Delta_h/ell_ex^2*Delta t

with the leading theoretical shape factor fixed at 1.

For caller-owned endpoint contact thickness dz:

    potential_release = max(dW_philip/dz,dW_darcy/dz)*dz
    actual_release = min(accepted_endpoint_storage,potential_release).

ell_ex is derived/measured structural geometry under ALT29. No transit-speed or residence-time parameter is introduced.

## Wall-event state
A22A returns candidate endpoint storage, wall-event age and wall-event sorptivity. If storage remains positive, age advances by dt and event sorptivity is retained. If storage empties, both reset to zero. The caller owns first-contact S_wall seeding from accepted matrix hydraulics.

## Mass contract

    storage_start - release_to_matrix - storage_end = 0

The release is an internal whole-column transfer, not an external loss.

## Hard boundaries
No ALT34 100 cm/h default. No legacy SWAP domain mapping. No accepted-state mutation. No MB/deep fate. No inference of chi_wall or ell_ex.

## Qualification oracle
Endpoint 1: storage 0.5 cm, dz 20 cm, ell_ex 20 cm, chi=1, S=0.2 cm/sqrt(d), K=0.1 cm/d, Delta h=50 cm, age=0.1 d, dt=0.1 d. Darcy potential=0.2 cm and dominates Philip; release=0.2 cm; end storage=0.3 cm.

Endpoint 2 is storage-limited and must empty exactly and reset wall-event history.

## Exit criteria
QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_ENDPOINT_RELEASE, explicit falsification, or true blocker.
