# F-PE-REPRO02 R7 result — serialized versus direct solver-request identity

Date: 2026-09-26

Status: `ACTIVE_REQUEST_SURFACE_IDENTICAL`

## Protocol

The first full-window mode-5 corrector request from the serialized FGC44 route was captured immediately before the physical Reference solve and compared with the successful direct P0 request.

Controls were aligned to the already-qualified R2/R3 envelope:

- max nonlinear iterations = 48;
- max backtracking = 16;
- minimum step duration = 1e-10 day.

Six difficult PROFILE06 origins were tested at -0.001, 0 and +0.001 cm, with three repetitions per point.

The comparison included:

- step duration and node count;
- z, dz and node-distance arrays;
- pressure-head and water-content base state;
- ponding depth and groundwater level;
- boundary modes and carriers;
- numerical controls and tolerances;
- macropore flag;
- constitutive theta, K, C and dK/dh evaluated at the base-state heads;
- source and sink provider outputs;
- fixed top-boundary provider outputs.

## Result

All active physical request fields and provider evaluations were identical between direct and serialized routes.

No node-level divergence was found in:

- geometry;
- pressure head;
- water content;
- constitutive response;
- source/sink response.

Three metadata differences were observed.

### Inactive top-head carrier

Direct P0:

`top_head = 0`

Serialized FGC44:

`top_head = h0`

R5 already demonstrated that this carrier is inactive under explicit-flux top mode and does not change convergence.

### Inactive bottom-flux carrier

Direct P0:

`bottom_flux = 0`

Serialized FGC44:

`bottom_flux = -K(h0)`

R5 already demonstrated that this carrier is inactive under prescribed-head bottom mode 5 and does not change convergence.

### Mid-regime bottom-head roundtrip

For B01-mid and O14-mid at +/-0.001 cm, the interface-head m -> pressure-head cm conversion produces a bit-level difference of about 1.4e-14 cm relative to the direct decimal construction.

This difference is absent in the wet cases, while the wet serialized participant still fails. It therefore cannot explain the common cross-case failure mechanism.

## Conclusion

The participant/direct divergence is not located in the explicit active physical solver request or provider inputs measured by R7.

Together R1-R7 now exclude:

- temporal acceptance as the first rejection;
- effort caps;
- minimum-step duration;
- legacy-context binding as an isolated operation;
- inactive boundary carriers;
- optional direction processing;
- active request-state, geometry, numerical controls and provider evaluation differences.

The next discriminator is process history.

The FGC44 participant executes a predictor solve before the corrector. Although predictor and corrector own separate backend/workspace objects, the legacy Reference path still contains process-global legacy state. A prior predictor solve may therefore affect a later physically identical corrector despite a fresh corrector workspace.

R8 tests this directly with a clean direct corrector versus the same corrector after a predictor-like mode-2 solve in the same process, using separate solver/workspace instances.

No production defect claim is made by R7 alone.
