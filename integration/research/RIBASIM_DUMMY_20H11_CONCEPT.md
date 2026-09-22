# RIBASIM-DUMMY-20H11

H10 showed a hydrologically material 5 h versus 6 h clock alias in the real
RibaMod product. H11 tests whether that behavior generalizes to the exact
clock-lattice rule implied by the bundled Ribasim v2026.1.1 BMI source.

For a regular 6 h BMI call-start grid, a fixed allocation solve is expected
only where both clocks coincide:

```text
allocation 4 h  ∩ BMI 6 h -> 0, 12, 24, ...  effective 12 h
allocation 5 h  ∩ BMI 6 h -> 0, 30, ...      effective 30 h
allocation 8 h  ∩ BMI 6 h -> 0, 24, ...      effective 24 h
allocation 6 h  ∩ BMI 6 h -> 0, 6, 12, ...   effective 6 h
```

For integer-hour regular grids this is the least-common-multiple relation.
H11 tests record times directly on the exact bundled release through BMI
`update_until` calls at 6 h intervals.

H11 is a release-level generalization anchored by H10 actual-product evidence.
It is not a production design recommendation.
