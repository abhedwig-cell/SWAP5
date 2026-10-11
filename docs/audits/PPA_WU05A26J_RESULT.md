# PPA-WU05-A26J result — IC endpoint storage geometry

Date: 2026-10-01
Status: QUALIFIED
Qualified postimage: 7a0bb1fbbf4b732aa13c0c0c8b196df3dca36bf7
Qualification run: 36895382532 — SUCCESS

Focused gate:

    PPA_WU05A26J_IC_STORAGE_GEOMETRY=PASS

## Result

The minimum structural mapping from areic endpoint storage W to a vertical macropore water-column height H is:

    H = W / a_mp

where a_mp is an explicit caller-owned macropore area fraction for the endpoint contact segment.

No default a_mp is admitted.

Qualified:
- exact reconstruction W = a_mp * H;
- monotonic H(W);
- fail closed for a_mp <= 0 or a_mp > 1;
- fail closed when H exceeds endpoint contact thickness;
- no calibration against mass residual.

This supplies the missing storage geometry required by A26I to derive a hydrostatic macropore water level and local macropore pressure head for terminating IC endpoint exchange.

## Decision

    IC_STORAGE_GEOMETRY = QUALIFIED
    MACROPORE_AREA_FRACTION = EXPLICIT_STRUCTURAL_INPUT
    DEFAULT_AREA_FRACTION = NONE
    NEXT = derive and qualify hydrostatic endpoint head, then resume A26
