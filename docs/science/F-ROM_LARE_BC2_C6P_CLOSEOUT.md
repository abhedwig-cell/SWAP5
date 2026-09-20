# F-ROM-LARE BC2-C6P root-uptake state sufficiency closeout

## Decision

C6P establishes a structural result:

**neither retained layer storage alone nor storage plus the centered geometric first water-content moment uniquely determines general drought-only Feddes uptake.**

This does not make those states unusable for ET modelling. It means any ET feedback computed from them is deliberately approximate unless additional root-specific information is introduced.

## Frozen response-free test

C6P uses no hydrological time trajectory.

For B01 and B14, synthetic fine profiles are constructed on the same existing R4/R8/U4/U8/P4/R16 partitions. Profile families are matched to the same retained layer storage. A second pair is additionally matched to the same centered first water-content moment.

Root weighting is tested with uniform, shallow and deep root distributions. Three synthetic demand classes use fixed constitutive-normalized Feddes thresholds.

These thresholds are structural probes, not crop calibration.

## Exact matching

All hard checks pass.

Maximum storage mismatch between nominally identical coarse states:

[
1.42\times10^{-14} mathrm{cm}.
]

Maximum first-moment mismatch for the equal-(S+M) pair:

[
1.71\times10^{-13} mathrm{cm^2}.
]

Root weights sum exactly to one and all synthetic effective saturations remain inside the frozen domain.

## Storage-only ambiguity

Fine profiles with exactly the same coarse storage produce different exact Feddes uptake.

The largest actual/potential uptake-fraction span on the frozen synthetic domain is approximately:

- **0.300** for B01;
- **0.121** for B14.

Therefore storage alone is not an exact root-feedback state.

## Equal S and M ambiguity

The more stringent P2 pair has the same retained storage **and** the same centered geometric first water-content moment.

Its maximum uptake-fraction difference remains approximately:

- **0.125** for B01;
- **0.041** for B14.

Even R16 retains nonzero equal-(S+M) ambiguity in this synthetic test.

Thus the geometric first moment is useful hydrological shape information, but it is not the exact sufficient statistic for root-weighted threshold stress.

## Why

The result follows the C6O theory.

Feddes uptake depends on root-weighted fractions of the profile occupying the unstressed, transition and wilted branches, plus a root-weighted pressure-head moment inside the transition branch.

A geometric water-content moment constrains a different projection of the state.

## Deliberately approximate next route

The Layer-ROM program is no longer seeking exact equivalence at every purpose.

Therefore C6P does **not** authorize adding a root-specific state merely to force exact root-feedback closure.

The minimum no-new-state approximation remains:

1. aggregate the prescribed root fraction exactly over each retained layer;
2. infer one representative pressure head from layer-average storage using the frozen retention relation;
3. evaluate the existing drought-only Feddes factor at that pressure head;
4. use the resulting layer sink conservatively.

C6P already preregistered this mean-storage route as a diagnostic before seeing the ambiguity result. It is demonstrably not exact, but it is parameter-free and physically interpretable.

C6Q may select it as a deliberately approximate candidate for prospective falsification, provided a root-active high-resolution Reference is qualified first.

No ET application tolerance, performance screen or production implementation follows from C6P.
