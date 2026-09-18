# ROM-1B1 nested aggregation collision census

B1 is a projection audit, not a ROM fit.

Only D01-D08 are regenerated under the already frozen ROM-1A Reference policy. The
candidate hierarchy is basis-free and nested: one profile-average water content,
surface/deep two-band averages, four 40-cm bands, eight 20-cm bands and the complete
16-cell water-content vector as a full-state control.

The collision scale is not learned from the ROM-1 library. It is the independently
measured B01 vertical Reference floor from ROM-0V1:
`epsilon_theta = 5.420462931603476e-4`.

For states from different discovery histories, a hidden-state collision exists when
the candidate-coordinate L-infinity distance is at or below epsilon while the full
16-cell theta-profile L-infinity distance is above epsilon.

This criterion identifies loss under projection rather than simply asking whether two
full states are close. Collision pairs are ranked without any future-probe outcome.
The top eight per candidate are frozen for ROM-1B2.

B1 does not declare a coordinate sufficient. A zero-collision candidate is only
state-separating on discovery data at this numerical floor. Predictive sufficiency
remains a later probe/held-out question.
