# ROM-1B3Q1 coordinate-invariant induced theta norm

ROM-1B3 remains valid evidence for its preregistered componentwise coordinate metric.
It is not rewritten.

Its full control exposed a structural metric problem: Z8 plus all eight local
half-contrasts is algebraically invertible to the 16-cell theta vector, but a
componentwise L-infinity ball in mean/contrast coordinates is not the image of a
cellwise L-infinity ball. A coordinate system could therefore appear to lose state
information solely because of the choice of equivalent parameterization.

Q1 removes that coordinate artifact without changing the physical numerical floor.

For a candidate coordinate map A_S, define

`q_S(dz) = min ||dtheta||_inf  subject to A_S dtheta = dz`.

For each 20-cm two-cell band:
- if only the pair mean is retained, the minimum compatible cellwise norm is
  `|dmean|`;
- if the half-contrast is also retained, the two cell differences are fixed as
  `dmean + dcontrast` and `dmean - dcontrast`, so the band norm is
  `max(|dmean+dcontrast|, |dmean-dcontrast|) = |dmean|+|dcontrast|`.

The candidate induced norm is the maximum band norm.

This norm is in theta units, introduces no fitted multiplier, equals the original Z8
metric when no G is present, and becomes exactly the cellwise Z16 theta-Linf norm when
all G components are present.

The same ROM-0V1 theta floor and the same 256 candidate subsets are retained.
