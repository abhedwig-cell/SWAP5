# F-PE-REPRO02 R5 result — inactive boundary carriers

Date: 2026-09-26

Status: `INACTIVE_BOUNDARY_CARRIERS_NOT_CAUSAL`

## Protocol

Starting from the successful P0 direct request, with serialized legacy-context binding applied in every arm, four boundary-carrier variants were compared:

- BASE: bottom_flux = 0, top_head = 0;
- QBOT: bottom_flux = -K(h0), top_head = 0;
- TOPHEAD: bottom_flux = 0, top_head = h0;
- BOTH: bottom_flux = -K(h0), top_head = h0.

Bottom mode remained 5 and top mode remained explicit flux.

Six difficult origins and offsets -0.001, 0 and +0.001 cm were tested with three repetitions per point.

## Result

All four arms converged at every point:

- BASE: 18/18;
- QBOT: 18/18;
- TOPHEAD: 18/18;
- BOTH: 18/18.

Per-point nonlinear and backtracking counts were identical across all four arms.

## Conclusion

The participant/direct-solver divergence is not caused by the nominally inactive mode-5 bottom-flux carrier or explicit-flux top-head carrier.

Together R1-R5 have now excluded:

- temporal acceptance;
- nonlinear iteration cap;
- backtracking cap;
- minimum-step duration;
- legacy-context binding itself;
- inactive bottom-flux carrier;
- inactive top-head carrier.

The next diagnostic must compare the actual direct and serialized physical solve requests/state/provider context rather than varying more scalar controls.
