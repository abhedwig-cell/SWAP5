# F-HYDROFIT01 P5B — function-space representative selection preregistration

Authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Purpose

Reduce the qualified primary objective envelope to a small set of hydraulically diverse representatives for later SWAP numerical probing.

Raw parameter distance is not the selection criterion because correlated parameter changes can produce nearly identical constitutive curves.

## Function grid

Use a fixed pressure-head grid containing saturation/near-saturation points and logarithmic unsaturated coverage:

`h = [0, -1e-3, -1e-2, -1e-1] cm` plus 61 logarithmically spaced negative magnitudes from `1` to `1e6 cm`.

For every primary-envelope member evaluate SWAP-native:

- `theta(h)`;
- `log10(K(h))`.

## Function feature scaling

Define a concatenated feature vector from:

- theta deviations divided by a fixed scale of `0.01 m3/m3`;
- log10(K) deviations divided by `0.25 decade`.

These scales define diversity for representative selection only. They do not alter the fit objective.

## Selection

Always include the optimum.

Then perform deterministic farthest-point traversal in function-feature space among primary-envelope members until either:

- 8 representatives are selected; or
- every remaining member lies within feature distance 1.0 of an already selected representative.

Ties resolve by candidate order.

## Gates

F0. Optimum is always representative 0.

F1. Selection is deterministic.

F2. Every representative is a primary-envelope member.

F3. If more than one representative is selected, each added representative was the farthest remaining candidate at its selection step.

F4. Function envelope min/max contains the optimum curves at every grid point.

F5. Parameter extremes alone do not control selection.

## Interpretation

The selected set is a deterministic coverage set for constitutive-function diversity inside the objective envelope. It is not a probability-weighted sample.
