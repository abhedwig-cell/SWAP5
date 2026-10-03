# Joint near-saturation transition probe

Date: 2026-10-02
Status: PREREGISTERED_TEST_ONLY_RESEARCH
Scope: one inherited dry, free-drainage, rising-external-head TOP03 trajectory; no production semantics change.

## Hypothesis

The near-saturation difficulty is aggravated by treating water storage and hydraulic conductivity with mismatched abrupt limits. A shared smooth transition in the pressure-head band immediately below saturation may improve the actual Richards solve while preserving soil and surface mass accounting.

This is distinct from smoothing the atmospheric/head boundary switch, reducing the conductivity shortcut alone, partial-contact microrelief, or adding a fixed contact resistance.

## Candidate law

Use a research-only transition width `delta_h = 0.02 cm`, chosen to cover the frozen-origin K-cutoff at approximately `-0.012386 cm`. For `-delta_h < h < 0`, let `s=(h+delta_h)/delta_h` and `w(s)=6s^5-15s^4+10s^3`.

- Water content: blend the unmodified MvG retention curve with `theta_s`, `theta=(1-w) theta_MvG + w theta_s`.
- Newton capacity: use the analytic derivative of that same `theta(h)` curve in the transition interval; retain the existing positive-head diagonal floor outside it.
- Conductivity: calculate the Mualem conductivity from the regularized effective saturation and blend it to `Ks` with the same `w`. Outside the interval, retain the original provider law. This removes the hard near-saturation shortcut only inside the declared transition band.

This one-width probe is a mechanism test, not a calibrated field parameter. It does not alter external head, ponding, runoff, boundary switching, bottom condition, spatial grid, solver tolerances, timestep policy, or transaction behavior. The existing soil storage remains the only soil storage owner; the test's accepted soil/surface ledger is unchanged.

## Target and gates

Target: geometry 2, free-drainage mode 7, initially dry profile 1, ramped external-head history 3, all fixed refinements from the inherited transition harness. The principal counterexample is the 2048-step trajectory that fails at step 86 under the original law.

Report every refinement, stop status, completed steps, Newton iterations, head range, top and bottom transfer, and mass residual. Do not count rejected/failed trials as accepted. Require soil residual and combined surface ledger within the inherited `1e-10 cm` gate. Require bitwise-reproducible numeric records at O0/O2. A successful mechanism probe must complete the full 2048-step trajectory at both optimization levels without smaller-than-declared steps; passing only isolated steps is failure. If this width fails, falsify only this declared joint transition candidate, not the entire class of physically parameterized transition laws.

No Actions run is planned. Production admission requires broader TOP03 preservation, wetting/recession and Ribasim transaction qualification, parameter/physical support, and canonical source reconciliation.
