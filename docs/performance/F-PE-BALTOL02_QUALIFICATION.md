# F-PE-BALTOL02 admission qualification result

Date: 2026-09-26

Status: `G1_G3_PASS_G4_PENDING`

## Production implementation

The serialized Reference backend now derives effective balance-rate tolerances per physical solve:

`effective_compartment = max(configured_compartment, 2.8e-16 / dt)`

`effective_total = max(configured_total, 2.8e-16 / dt)`

The immutable configured parameter values remain unchanged.

Only compartment and total balance convergence tolerances are affected.

Head tolerances, ponding tolerance, mass acceptance, temporal budget and nonlinear/backtracking controls are unchanged.

The effective values are exposed in the serialized physical observation for qualification and diagnostics.

## G1/G2 effective-request guards

Passed.

Verified examples:

- dt=1e-3 d, configured 1e-12 -> effective 1e-12;
- dt=1e-4 d, configured 1e-12 -> effective 2.8e-12;
- dt=6.25e-6 d, configured 1e-12 -> effective 4.48e-11, within floating representation;
- dt=6.25e-6 d, configured 1e-10 -> effective 1e-10.

This confirms both strict preservation and the qualified scaled-floor branch.

## G3 BALTOL01 replay

Passed.

- broad difficult replay: green;
- recovered fixed-substep oracle replay: green;
- P2R N=64 terminal-flux refinement: green.

## Broader workflow note

Several old preservation workflows on the deeply stacked PR report preregistration/source-delta failures because their frozen guards require exact historical production file sets. Those failures are not physical solver mismatches and predate interpretation of BALTOL02's new authorized production delta.

They are not counted as G4 passes.

G4 remains pending on the current canonical/reconstructed authority jobs that are designed to qualify the current source lineage.


## Regression attribution

The broad pull-request fanout includes historical preservation workflows whose contract is exact source/blob identity with an earlier admitted backend.

Those workflows fail by construction after the authorized BALTOL02 production delta. Sample failure modes are explicit:

- `D1 changed production/reference source`;
- `admitted ... backend successor drift`;
- exact equality of `src/runtime/mod_fmr_serialized_reference_backend.f90` against an older frozen authority;
- exact historical owner-surface/file-set comparison.

These failures are evidence that the production backend changed, not evidence of a physical or semantic regression.

They are therefore superseded for this admission decision by current-lineage qualification that actually recompiles/replays the present source.

Current-lineage status on this head:

- BALTOL02 G1/G2 effective-request guard: PASS;
- BALTOL02 broad difficult replay: PASS;
- BALTOL02 oracle replay including N=64 refinement: PASS;
- F-CI canonical current-lineage jobs completed so far: PASS;
- F-CI110 reconstructed performance jobs completed so far: PASS;
- F-PE-APPROX02 default-exact, multistep and application-sequence jobs completed so far: PASS;
- zero-waste poison/runtime and current performance recomposition jobs completed so far: PASS.

At this point the remaining admission dependency is completion of the last current canonical jobs, not reinterpretation of frozen exact-source preservation guards.
