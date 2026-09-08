# F-WOF06 potential crop shadow-state ownership

## Source baseline

Supplied SWAP 4.3.1 archive SHA-256:

`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`

Extracted legacy `wofost.f90` SHA-256:

`3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b`

SWAP5 baseline for this resolution:

`135823ddcacef14dca4d2805277a4ace20e18b75`

## Legacy ownership audit

The supplied SWAP 4.3.1 source maintains separate `s_pot` and `s_act` WOFOST states and updates the potential trajectory before the actual trajectory.

A source-wide static reference inventory gives:

- `s_pot`: 24 references, 10 in `wofost.f90`, 14 in `swapoutput.f90`;
- `r_pot`: 7 references, all in `wofost.f90`;
- `m_pot`: 14 references, 7 in `wofost.f90`, 7 in `swapoutput.f90`;
- no `s_pot`, `r_pot` or `m_pot` references in any other legacy process module.

Within `wofost.f90`, the potential trajectory uses its own LAI for assimilation and its own rate/state update. The actual trajectory independently uses `s_act%lai`, `s_act` organ biomass and stress-reduced assimilation. No physical actual-state update consumes the potential WOFOST state.

`swapoutput.f90` consumes the potential state for restart/output persistence. That is an output/restart capability dependency, not evidence that potential crop state is required to advance the actual physical crop trajectory.

## Resolution

The F-WOF05 two-track pair is a valid qualification/composition harness, but it is not the mandatory final SWAP5 per-column state layout.

For SWAP5:

1. actual crop state is the primary committed physical crop state;
2. potential crop state is an optional shadow/reference trajectory;
3. a model template that does not request potential crop reference outputs must not allocate persistent potential crop state merely for legacy compatibility;
4. when potential crop reference output is requested across transaction boundaries, its shadow state must itself obey checkpoint/trial/commit semantics;
5. a rejected trial may not advance either actual state or an enabled potential shadow state;
6. immutable crop parameters remain shared between actual and potential trajectories;
7. the potential shadow may be recomputed rather than persisted only when the runtime can do so without changing scientific semantics and without unacceptable cost;
8. legacy restart/output adapters may expose potential-state fields when that capability is enabled, without forcing those fields into every SWAP5 column.

## Invariant assessment

- Invariant 3: actual state and optional reference results/state remain explicit data categories.
- Invariant 4: only physical state required for the configured trajectory is persistent.
- Invariant 7: enabled shadow trajectories remain transactional.
- Invariant 16: MultiSWAP does not pay mandatory duplicate crop-state memory per column.
- Invariant 25: potential/reference trajectories can remain available as a qualified reference capability.
- Invariant 27: optional reference functionality incurs state and compute only when active.
- Invariant 29: legacy restart fields do not become hidden kernel requirements.

## Decision

`ACTUAL_PRIMARY_POTENTIAL_OPTIONAL_SHADOW`

This resolution does not remove potential production capability. It changes its ownership from unconditional legacy state to an explicit optional model capability.
