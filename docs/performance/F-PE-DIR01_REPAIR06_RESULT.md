# F-PE-DIR01 Repair06 result

Date: 2026-09-26

Status: `REJECTED_STALE_WORKSPACE_PROVENANCE`

Repair hypothesis:
reuse the Reference Richards workspace capacity at the accepted candidate state to compute the outgoing water-content direction as

`dtheta_out = C * dh_out`

and thereby remove the final default-MvG water-content directional pass.

## Why the hypothesis was tested

On the Repair01 + Repair03 + Repair05 postimage, gprof still shows
`evaluate_b110_default_mvg_water_content_direction` approximately three times per application interval and at about 4.8% of directional self-time.

That made accepted-capacity reuse the only remaining constitutive shortcut large enough to justify an exact DIR01 experiment.

## Provenance audit

The Reference HeadCalc path proves that the workspace capacity is not guaranteed to correspond to the accepted candidate pressure head.

For provider-backed hydraulics, after the Newton head update:

- `provider_tuple_valid` is cleared;
- for `SwKimpl == 0` and the admitted bottom-head route, the candidate update calls
  `evaluate_demand(...CONSTITUTIVE_DEMAND_WATER_CONTENT...)`;
- the default-MvG implementation of the WATER_CONTENT-only demand writes only `water_content`;
- it does not write `capacity`.

Therefore `fsi_ws%provider_capacity` after the accepted candidate update may still represent the preceding Jacobian/base state.

If another nonlinear iteration occurs, capacity may be refreshed for that iteration, but after its subsequent accepted candidate update the same provenance problem exists again.

The workspace array is consequently solver scratch with last-use semantics, not an accepted-candidate capacity publication.

## Decision

Repair06 is rejected before production experimentation.

Using the existing workspace capacity for

`C(h_candidate) * dh_out`

would rely on stale-state data and can change the accepted outgoing water-content derivative.

No production source is changed for Repair06.

## Implication for DIR01

This closes the most plausible remaining constitutive reuse shortcut.

The remaining exact overhead is now dominated by:

- physically required tangent assembly and constitutive directional mathematics;
- generic transaction context required for rollback/commit semantics;
- relatively small remaining allocation/publication chains.

Previous evidence already showed:
- Repair04 context-byte compaction was only about 0.3-0.4%;
- raw tridiagonal backsolve cost is small;
- publication/copy sites are small in gprof self-time;
- the remaining outgoing/publication allocations are limited in count and are unlikely to provide a new large exact gain.

Repair06 therefore supports DIR01 closeout rather than another speculative exact repair.
