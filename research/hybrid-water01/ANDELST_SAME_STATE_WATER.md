# Andelst same-state water comparison

Evidence pin: canonical `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
See [spring comparison](ANDELST_SPRING_DRAINAGE.md) for the B0 source,
accepted day-365 checkpoint and V9 archive. All numerical probes are
standalone and leave the original model equations untouched.

## Lower boundary, March 30 through April 2

An O2 B0 worker emitted the accepted clock, dt, qbot, aquifer head,
bottom cell pressure and elevation, external resistance, boundary
distance and conductivity immediately before SoilWater(3).
The compiled SWAP5 `evaluate_resistive_bottom_boundary` consumed the
same 12,423 accepted states. Both O0 with runtime checks and O2
returned bit-identical fluxes for every row, totaling
0.50599970839113806 cm. The aquifer head was -68.6 cm, the external
resistance 10 d and the half cell 2.5 cm in every sample.
The V9 input also ends the aquifer table at -68.6 cm, enables the
half-cell resistance and disables the additional Q4 flux.
The remaining 6.795 mm excess archived V9 bottom inflow therefore
cannot be attributed to the evaluated law on the measured B0 inputs.
The current comparison does not provide V9 bottom pressures and
conductivities during the target window.

## Rapid drainage on identical B0 states

A read-only call to the compiled SWAP5 `evaluate_rapid_drain` was
inserted next to B0 RAPIDDRAIN. It used the legacy inputs, first
including the legacy undrainable capacity and then replacing only
that capacity by the SWAP5 cell-face integral. The B0 published
daily rows were identical with and without instrumentation.
All 106,743 potential-rate calls matched the B0 potential exactly
with the legacy capacity. On the 12,423 accepted steps, the legacy
capacity exceeded main-domain stock by 0.00818 to 0.03171 cm.
The cell-face capacity instead left 0.01829 to 0.04182 cm available.

The cell-face variant would request 0.9150 mm of potential drainage
on the frozen B0 states. The earlier closed-loop B0 perturbation
exported 0.2770 mm over the window. These are distinct measurements.
Neither accounts for the full 5.8476 mm accepted V9 excess.
This comparison covers the potential law, not the subsequent
macropore flow limiter on matched V9 states.

## V9 native checkpoint and observation control

The reviewed upper-support V9 source was rebuilt on Linux with GNU
Fortran 13.3 O2 and read the archived Windows day-365 checkpoint
(SHA-256 `1ee453329a650b0fdf4017b59bd6d1f2b4927de0b8aefeff2b51c21fee08f1d5`).
Original inputs, binding and native execution options came from
the archived day-365-to-367 launch. Both days completed.
The 1005 source-interval count, daily bottom and rapid flux totals,
and reported daily groundwater levels matched the archived run.
Endpoint nodal heads differed by at most 7.11e-15 cm and native
checkpoint bytes differed across platforms. This is not byte-exact
cross-platform restart equivalence.

A second build changed only the main water driver to print the
already accepted water receipt: interval, bottom flux, main-domain
stock at both ends, rapid outflow, direct and pond-fed macro supply,
and integrated main-domain matrix exchange. It also printed the
day-end nodal heads. It reproduced the first Linux build's budget,
progress, diagnostics, state and ending restart byte for byte.
Maximum daily water residual was 2.561e-13 cm.

This run reaches day 367. Obtaining the native V9 state in the dry
window requires carrying the validated restart through days 454–457.
There is no matching checkpoint for those dates in the archived set.
Compare the native states there before selecting a production change.
