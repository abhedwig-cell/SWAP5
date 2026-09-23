# ROM-PURPOSE P1 Reference failure diagnosis

## Decision

P1 remains **fail closed**. The persisted Reference result is `P1_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES`. No S4, G4 or U4 response may be generated under the P1 authority.

This is not a Layer-ROM falsification. No P1 candidate response exists.

## What qualified

The groundwater/lower-boundary Reference route qualifies for both B01 and B14. Its cumulative bottom exchange, interval flux, mapped profile, total storage and sign/reversal guards all satisfy the bound Reference qualification.

For the surface/profile route, most hydrologically varying observables also converge cleanly. B01 qualifies for 0-20 cm, 0-40 cm, 0-80 cm and mapped 10-cm moisture, with zero extremum-timing mismatch. B14 qualifies for 0-20 cm, 0-40 cm and mapped 10-cm moisture.

## Why SURF_P fails

B01 fails only because total-storage differences do not admit a positive monotone observed order. The relevant coarse/fine discrepancies are approximately (2.73\times10^{-13}) and (9.57\times10^{-13}) cm in space, and (8.99\times10^{-14}) and (2.45\times10^{-13}) cm in time. The gate therefore fails exactly as preregistered, but the failure is at a numerical floor rather than at a hydrologically resolved response scale.

B14 has the same total-storage issue. Its temporal 0-80 cm discrepancy is also non-monotone at roughly (10^{-14}) cm. In addition, the bound global extremum-timing guard reports 114 observation steps spatially and 50 temporally.

Direct inspection of the immutable Reference routes shows why that timing diagnostic is unstable. During the hold phase, the B14 upper-zone storage is effectively a plateau. For S02 at R2048_T32 the complete 513-1024 hold range is only (1.78\times10^{-14}) cm, while the selected global argmax moves from observation 880 at R1024_T32 to 994 at R2048_T32. The reported 114-step timing mismatch is therefore an index selection within a numerically flat plateau, not a 114-step hydrological event shift.

This observation diagnoses the Reference gate. It does not authorize changing the gate after seeing the response.

## Scientific consequence

P1 cannot answer H1-H4. In particular:

- the positive GW Reference qualification does not authorize a GW-only candidate run because the frozen P1 gate was global and fail closed;
- the surface failure does not support a conclusion that S4, G4 or U4 is insufficient;
- no closure conclusion can be drawn;
- no application sufficiency or performance claim is allowed.

## Next authority boundary

A new prospective Reference authority is required before candidate execution. Two scientifically defensible directions remain open:

1. define numerical-indistinguishability and plateau/extremum-observability semantics prospectively, then validate them on fresh surface Reference histories;
2. define a fresh surface forcing/event workload whose timing observables are non-degenerate, then requalify the Reference route.

Choosing between these is a new experimental-design decision. The exposed P1 surface histories must not become the validation set for whichever replacement rule is selected.

The current P1 failure is therefore a natural research boundary, not a reason to tune thresholds or partitions post hoc.
