# PPA-WU05-A6 R6 contract — accepted vertical macropore flux reconstruction

Date: 2026-09-30

Status: CORRECTED_REFERENCE_CONTRACT / TYPED_IMPLEMENTATION_IN_PROGRESS

## Authority

A1 proved the B1.11 standard-route icgwl defect.

A3 R1-MSTATE02 proved that the historical split reconstruction of QTopMpDmCp is locally inconsistent when a saturation interface crosses a compartment boundary, although whole-domain mass remains closed.

A3 selected one universal accepted-state conservation reconstruction as the corrected reference.

## Local identity

For each active domain/compartment:

DeltaW/dt = Q_top - Q_bottom - Q_exchange_to_matrix - Q_external_out.

Therefore:

Q_bottom = Q_top - Q_exchange_to_matrix - Q_external_out - DeltaW/dt.

Positive Q_exchange_to_matrix leaves the macropore system for the matrix.

Positive Q_external_out leaves the complete soil column through the named external macropore owner, e.g. rapid drainage.

## Reconstruction

Start at each domain's accepted top inflow rate.

Apply the same local identity monotonically top-to-bottom through the active domain.

Do not split reconstruction at a moving saturation interface.

Do not persist reconstructed vertical faces as continuation state.

## Qualification properties

- exact local mass balance in every active compartment;
- exact whole-domain balance;
- stationary-interface cases reproduce the historical standard route;
- moving-interface cases remain locally conservative;
- rapid drainage enters exactly once as an external compartment sink.