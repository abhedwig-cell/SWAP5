# PPA-WU05-A22A result — RFM terminating-endpoint release owner

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Baseline: integration/f-ci-canonical@81b7feda17f53a94ab4e5877467cc4499de6f568
Qualified postimage: ac46ed334707cc80f21325f1668787aca33adf4f
Qualification run: 36871141024 — SUCCESS

Focused gate:

    PPA_WU05A22A_RFM_ENDPOINT_RELEASE=PASS

## Result
The ALT34 fixed 100 cm/h IC transit velocity is not required in the bounded production route.

A22A treats vertical delivery to a terminating endpoint as instantaneous on the SWAP model time scale, consistent with the existing SWAP advanced-macropore conceptualisation. Endpoint storage then releases to the matrix with the reduced ALT27/28 wall law:

    Philip = chi_wall*(4/ell_ex)*S_wall*Delta sqrt(t)*dz
    Darcy  = 8*K*Delta_h/ell_ex^2*Delta t*dz
    release = min(endpoint_storage,max(Philip,Darcy)).

ell_ex remains independently derived/measured structural geometry under ALT29. The narrow Darcy shape correction is fixed at its leading theoretical value 1.

## Qualified semantics
- exact endpoint storage/release closure;
- release cannot exceed accepted storage;
- persistent contact advances wall-event age and retains event sorptivity;
- emptied endpoint resets wall-event age/sorptivity;
- invalid exchange length fails closed;
- no accepted-state mutation is required by the operator.

## Oracle
Endpoint 1: Darcy potential 0.2 cm dominates and releases 0.2 cm from 0.5 cm storage.
Endpoint 2 is storage-limited, empties exactly and resets wall history.
Aggregate start 0.6 cm = release 0.3 cm + end storage 0.3 cm.

## Boundary
A22A owns terminating IC endpoint -> matrix release only. It does not own MB wall/deep fate and does not remove the A20 live-runtime guard by itself.

## Decision

    ALT34_FIXED_IC_VELOCITY_100_CM_H = REMOVED_FROM_PRODUCTION_ROUTE
    TERMINATING_ENDPOINT_RELEASE_OWNER = QUALIFIED
    MB_FATE_BLOCKER = REMAINS
