# PPA-WU05-MIGMAC01 G6 stable storage-increment preregistration

Date: 2026-10-02
Status: PREREGISTERED_NUMERICAL_REPAIR
Owning branch observed before preregistration: f4391c007941517ffb7ed5b0b31252856db47edb
Diagnostic run: 36975432340
Work unit: PPA-WU05-MIGMAC01

## Falsified explanation

The corrected-source Reference replay is not blocked because the native
1e-12 cm/day compartment criterion is physically unattainable at node 36.

At O0 and O2 the final node-36 residual is
+2.5128787939365793e-12 cm/day. The exact source matrix fraction is
0.96714285714285719. One adjacent representable water-content value downward
changes the storage-rate term by -2.8991096603938156e-12 cm/day and would give
a residual of -3.8623086645723625e-13 cm/day, inside the unchanged criterion.

The final Newton correction is +1.0791420113109419e-13 cm in the sign that
reduces head and water content. The local water-content ULP divided by capacity
corresponds to about 1.2755508595964370e-13 cm. The continuous Newton correction
therefore stops just short of the next absolute-theta representation.

## Root cause hypothesis

The time-step storage term currently forms

    (theta(h_new) - theta(h_old)) * matrix_area * dz / dt

from two separately rounded absolute real64 water contents. For the frozen event
at node 36 theta changes by about 1.88919e-7, but one absolute-theta ULP is
5.5511151231257827e-17. The very small dt amplifies that absolute rounding
quantum to about 2.8991e-12 cm/day after matrix-area weighting.

This is a storage-difference cancellation/representation floor. It is not a
macropore-physics falsification and is not evidence for relaxing the convergence
criterion.

## Bounded repair

Add a non-breaking constitutive-provider operation that returns water-content
increment directly from current and previous pressure head/state.

- Base-provider fallback is exactly current_water_content - previous_water_content.
- The B1.10/B1.11 default MvG provider overrides it with a cancellation-resistant
  analytical delta for two heads that remain in the same retention branch.
- Branch crossings fall back to the existing absolute-water-content difference.
- The explicit Reference/provider HeadCalc route uses this increment in the
  compartment storage residual.
- Legacy module-global/source HeadCalc remains on its historical theta subtraction.
- No tolerance, iteration limit, forcing, dt, event, macropore formula, CALCGWL
  correction or physical parameter changes are allowed.

For same-branch standard MvG, compute the effective-saturation difference via
log1p/expm1 algebra rather than subtracting two O(1) theta values. Linear and
rational near-saturation branches use algebraic delta forms. Elastic saturated
storage, when active and both heads are nonnegative, uses Ss*(h_new-h_old).

## Falsification gates

1. Ordinary frozen corrected-source replay must converge at the original
   max_iterations=64 and unchanged 1e-12 native criterion.
2. O0/O2 must agree.
3. The solution must remain close to the frozen corrected Reference state; no
   head/input/tolerance tuning is permitted.
4. Active macro replay must then be rerun unchanged. A remaining failure must be
   diagnosed separately.
5. Existing ordinary Reference/provider and PERCH preservation gates must be
   rerun before qualification.
6. Any material hydrologic change outside the precision-floor regime blocks
   admission pending attribution.

This preregistration does not qualify the repair or MIGMAC01.
