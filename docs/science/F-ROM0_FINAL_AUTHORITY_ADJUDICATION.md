# F-ROM0 final authority adjudication

## Decision

**NO_GO_REFERENCE_AUTHORITY**

ROM-0 does not authorize ROM-1A.

This is the close decision defined by the original accepted full-order authority when the required accepted Reference trajectory / floor instrument cannot be completed reproducibly without changing the frozen scientific or numerical controls.

## Evidence chain

### Initial ROM-0

The first preregistered laboratory failed before accepted state formation for all 18 B01/B14 cases under the canonical external-full/half transaction. An independent accepted-runtime control passed. The correct decision was therefore not a general Reference failure but `EXPAND_ACCEPTED_TRAJECTORY_DOMAIN`.

### ROM-0R R1

A gravity-consistent steady seed was then constructed with uniform pressure head and `q_top=q_bottom=-K(h0)`.

B01 and B14 both produced accepted, mass-complete, storage-stable seed trajectories.

### ROM-0R R2 and F-ROM0TA1/TA2

Symmetric one-percent top-flux perturbations still could not be admitted through the application temporal policy.

F-ROM0TA1 showed that the F-SI38 temporal certificate is locally conservative but strongly non-tight on the frozen B01/B14 matrix.

F-ROM0TA2 reconciled this with F-GC application-accuracy governance and established that inventing a ROM head budget from the observed numerical error would be circular and forbidden.

### F-ROM0TA3

A separate research Reference-floor sample capability was therefore qualified under F-KT ownership.

It commits exactly one solver-valid, mass-complete prescribed-resolution Reference sample without claiming application temporal adequacy or silently reducing dt.

The capability itself is valid.

The first temporal ladder showed:

- 0.0016 d: 4/4 B01/B14 plus/minus trajectories complete;
- 0.0008 d: 4/4 complete;
- 0.0004 d: 0/4 complete, each ending in a genuine `legacy-reference-retry`.

The failed 0.0004 d level remains retained evidence.

### F-ROM0TA4

The already pre-authorized 0.0008 d refined candidate was then qualified for restart/replay.

Run 35372014491 on exact pre-TA5 source head `0037635443454ce6b7e6d4fe56534874451f8a92` passed:

- 4/4 B01/B14 TOP_PLUS/TOP_MINUS cases;
- 32/32 post-restart replay points;
- pressure head, water content, ponding, groundwater level, mass residual, lineage, revision and committed time bit-identical;
- fresh backend after restore;
- no worker/solver scratch persisted;
- wrong parameter identity failed closed;
- repeated stdout bit-identical.

Thus the retained 0.0008 d candidate is deterministic and restartable.

### F-ROM0TA5

The research sample binding was extended only to already admitted prescribed-head Reference mode 5.

Run 35370006629 passed B01/B14 for mode 2 and mode 5 at O0/O2, with the Reference solver, kernel sample core, transaction core and canonical interval runtime unchanged.

This proves the mode-5 sample seam itself is not the blocker.

### ROM-0R R3

R3 reused the originally preregistered lower-boundary directions:

- `BOTTOM_HEAD_RISE = 0.75*h0`;
- `BOTTOM_HEAD_FALL = 1.25*h0`.

The amplitude and retained `dt=0.0008 d` were fixed before R3 results and may not be retuned afterward.

Run 35372347484 produced:

- B14 rise: full-horizon PASS;
- B14 fall: full-horizon PASS;
- B14 directional separation: PASS;
- B01 rise: `legacy-reference-retry` at perturbation step 11;
- B01 fall: `legacy-reference-retry` at perturbation step 10.

The B01 failures occur after multiple accepted samples, with no mass failure and with the sample binding already independently qualified. They are therefore genuine failures of the frozen fixed-resolution Reference trajectory authority for the required prescribed-head domain.

## Final ROM-0 gate adjudication

### Q0.1 Ownership

**PASS.**

The research sample path remains F-KT-owned and cannot promote a rejected candidate.

### Q0.2 Reproducibility

**PASS for the retained 0.0008 d flux-perturbation authority.**

F-ROM0TA4 proves exact restart/replay identity.

### Q0.3 Conservation

**PASS for every retained accepted sample.**

Mass-incomplete or failed samples are excluded and preserved as diagnostics.

### Q0.4 Bidirectional reachability

**FAIL for the preregistered two-material domain.**

B14 demonstrates both prescribed-head directions and the expected directional separation, but B01 cannot complete either frozen full-horizon prescribed-head trajectory.

The R3 preregistration explicitly required both directions to complete for both materials. Post-result amplitude or dt tuning is forbidden.

### Q0.5 Reference floor

**INCOMPLETE AND NO LONGER AUTHORIZED FOR EXPANSION IN THIS WORKUNIT.**

A temporal floor component exists for the successful 0.0016 versus 0.0008 d flux-perturbation trajectories.

The complete ROM-0 floor cannot be established for the preregistered domain because the required lower-boundary accepted Reference authority fails for B01.

The remaining 16x10 cm versus 32x5 cm vertical diagnostic cannot repair Q0.4 and, after the R3 no-go, is not an authorized route to `PROCEED_TO_ROM1A`.

### Q0.6 Non-mutation

**PASS WITH RESEARCH-SAMPLE SCOPE.**

No Reference Richards equations, solver controls or ordinary application temporal policy were changed. F-ROM0TA3/TA5 add only the governed research sample seam required to expose the Reference limitation.

## Why this is NO_GO rather than another expansion

The programme already used the allowed expansion sequence to:

1. repair the physically inconsistent seed;
2. isolate temporal-authority circularity;
3. add a governed fixed-resolution research sample capability;
4. qualify restart/replay;
5. qualify prescribed-head sample binding;
6. execute the original pre-result lower-boundary amplitudes.

The remaining failure is not an unobserved seam or an unqualified wrapper. It is the Reference solver asking for a smaller step in both B01 prescribed-head directions under frozen controls.

Changing dt, amplitudes, iteration limits, backtracking limits, mass gates or material selection now would be post-result tuning and would violate the preregistered experiment.

Therefore the current ROM-0 scientific instrument cannot support the intended two-material accepted-Reference domain.

## Consequence

`ROM1A_AUTHORIZED = false`.

No reachable-state library, state-compression, predictive-ambiguity, POD, memory-state or reduced-closure work may use this ROM-0 authority as its prerequisite.

A future reopening is possible only through a **new Reference-authority workstream** with independently justified numerical/solver semantics and a new preregistration. It may not reinterpret or overwrite the failed ROM-0/ROM-0R evidence.

The F-ROM0 branch remains scientifically valuable because it now localizes the blocker: the issue is not state ownership, restart persistence, mass accounting, mode-5 binding or a missing application head budget. It is the inability of the frozen Reference trajectory authority to span the required B01 prescribed-head domain.
