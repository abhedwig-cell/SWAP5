# F-ROM0TA3 fixed-resolution Reference-floor adjudication

## Decision

**REFERENCE_FIXED_RESOLUTION_TRAJECTORY_NO_GO_FOR_PREREGISTERED_THREE_LEVEL_LADDER**

The new qualification-only sample capability works as designed. The scientific three-level ladder does not.

## Capability result

F-ROM0TA3 adds a separate kernel/FMR reference-floor sample path rather than a third ordinary temporal-acceptance mode. A successful sample performs exactly one prescribed physical advance, requires Reference convergence and complete hard mass accounting, materializes a separate typed candidate, and can only be committed through a dedicated lineage/revision/time-guarded commit method.

No application head budget is involved. The normal canonical interval runtime, canonical numerical configuration, transaction temporal modes, Reference solver and physics are unchanged.

Run 35368615413 is bitwise reproducible over two complete executions.

## Frozen three-level matrix

All four B01/B14 TOP_PLUS/TOP_MINUS trajectories complete the full 0.0128-day perturbation horizon at both 0.0016 d and 0.0008 d.

All four fail later in the trajectory at 0.0004 d. Each failure is the same class:

- one requested physical advance;
- `SW_SOLVE_RETRY_ADVISED`;
- route `legacy-reference-retry`;
- frozen 16 nonlinear iterations exhausted;
- one internal retry request;
- candidate not promoted;
- no mass acceptance claim on the failed solve.

The failure steps differ by material/sign, so this is not an artifact of one absolute time boundary.

## Interpretation of the smaller-dt failure

This does not support the simple interpretation that Reference validity improves monotonically when dt is reduced.

That conclusion is independently consistent with PUB-P2E16C and PUB-P2E16D1, which preregistered fixed-step/duration ladders before the ROM work and found reproducible non-monotone Reference convergence: some cases converge at larger durations but request retry at smaller durations, always through the same 16-iteration `legacy-reference-retry` mechanism.

Therefore no local numerical repair is justified. Increasing iteration limits or importing a different balance policy here would violate the frozen F-ROM0TA3 controls.

PUB-P2E21 separately qualifies a representation-derived research total-balance policy for a different frozen solver-seam population. It is useful evidence that fine-route loss can have a numerical representation component, but it is not silently transferred into ROM-0: F-ROM0TA3 did not preregister that policy, its controls are frozen, and B14 is not in the P2E21 population.

## Useful floor evidence retained

The failed third level does not erase the successful first refinement pair.

For the four B01/B14 perturbation trajectories, 0.0016 d versus 0.0008 d supplies eight common observation times per trajectory. The maximum differences are:

- pressure-head profile infinity norm: 4.0975027690848265e-05 cm;
- water-content profile infinity norm: 1.115318385980224e-07;
- total storage: 1.4210854715202004e-14 cm;
- upper 0-40 cm storage: 4.2075996020685125e-09 cm;
- lower 40-160 cm storage: 4.2075996020685125e-09 cm;
- top exchange: 1.3877787807814457e-17 cm;
- bottom outward exchange: 6.938893903907228e-18 cm.

These are measured numerical differences, not application tolerances.

## Higher-level authority after TA3

The original ROM-0 preregistration, written before all TA3 results, requires at least one controlled temporal refinement comparison and explicitly names 0.0016 d versus 0.0008 d as its observation-interval comparison.

R2 also froze 0.0008 d as the refined transient timestep before the temporal-authority work began.

Therefore retaining 0.0008 d as the pre-existing refined ROM-0 resolution candidate is not post-result timestep tuning. The new 0.0004 d level was an additional TA3 strengthening level and its failure remains failed evidence.

The next permitted step is not to replace the failed 0.0004 d level. It is to qualify reproducibility and restart/continuation for the already pre-authorized 0.0008 d refined candidate, while retaining the 0.0016 versus 0.0008 output-specific floor above.

ROM-1A remains blocked until that authority is closed and the remaining ROM-0 Reference-floor obligations are reconciled.
