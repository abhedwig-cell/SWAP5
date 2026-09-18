# ROM-1B3 local-contrast enrichment authority

B2 falsified every reduced member of the original nested Z1/Z2/Z4/Z8 aggregation
hierarchy on discovery future probes. B3 therefore asks a narrower state-design
question before any held-out data are opened: can the 8-band water-content state be
made state-separating with only a small number of physically local profile-shape
coordinates?

The base state remains the eight 20-cm pair means. The only allowed enrichment
components are the eight within-band half-contrasts

`G_i = 0.5 * (theta_upper_cell - theta_lower_cell)`.

The factor 0.5 matters: both a pair mean and a half-contrast have an L1 coefficient
sum of one with respect to the underlying theta cells. They can therefore use the
same independently measured B01 theta Reference scale without inventing a new
component-specific multiplier.

All 256 subsets of G1..G8 are evaluated on D01-D08 only. No future-probe magnitude,
held-out state, held-out probe or B14 result may influence subset selection.

A pair is still a hidden-state collision when the enriched coordinate is
indistinguishable at the frozen theta floor while the 16-cell theta state is
distinguishable beyond that floor.

Selection is deterministic:
1. fewest added contrasts among zero-collision subsets;
2. largest minimum discovery separation margin among full-state-distinguishable pairs;
3. lexicographically smallest G-index tuple.

With all eight contrasts, Z8+G1..G8 is exactly invertible to Z16. If that full set is
the first zero-collision candidate, the result is not a reduced-state success.
