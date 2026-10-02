# TOP03 finite surface-contact resistance preregistration

Date: 2026-10-02
Status: PREREGISTERED_RESEARCH_ONLY
Starting TOP03 head: `af5986bf09b895805f3aecd5cee60b54c3b2a290`
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Question

The fixed-stage microrelief experiment showed that partial areal hydraulic contact can regularize shallow inundation onset. The subsequent stage-evolution experiment falsified the simple rule `K_contact = f_wet K_face`: the nonlinear failure returns as wetted fraction and effective contact conductance increase.

This experiment tests a narrower physical hypothesis. The unresolved soil-water interface has both:

1. a stage-dependent wetted fraction from microrelief; and
2. a finite hydraulic contact resistance representing a thin surface transition layer, crust, roughness/contact geometry or other unresolved near-surface resistance between open water and the matrix.

The resistance is tested as a physical Robin/Cauchy contact, not as an arbitrary numerical conductivity cap.

## Contact law

Let:

- `d` be the distance from the surface to the top soil node;
- `K_face` be the same saturated/top-node arithmetic face conductivity used by the existing TOP03 research fixture;
- `R_s` be an additional surface-contact resistance in days;
- `f_wet` and `h_wet` be the microrelief wetted fraction and mean wet-area water head.

The soil-face hydraulic resistance is `d/K_face`. Add the contact resistance in series:

```
R_total = d/K_face + R_s
G_wet   = 1/R_total
K_eff   = d/R_total = K_face / (1 + R_s K_face/d)
```

The areal-average boundary is:

```
K_contact = f_wet K_eff
q_top = -K_contact * ((h_wet-h_top)/d + 1)
```

For `R_s=0`, this reduces exactly to the previously tested microrelief law. For `D=0, R_s=0`, it reduces exactly to the current flat imposed-head control.

The local surface-storage relation remains the preregistered uniform-microrelief law. Resistance changes exchange kinetics, not storage geometry.

## Fixed physical fixture and stage forcing

Preserve the preceding stage-evolution experiment exactly:

- same MOD_grid geometry and B1.10 MVG soil;
- initial pressure head -123 cm;
- initial groundwater level -2.25 cm;
- initial local surface storage 0;
- bottom mode 7 and the same initial conductivity-derived bottom flux;
- Reference Richards;
- max 80 nonlinear iterations and 16 backtracking attempts;
- no roots, drainage response, macropores, snow, thermal process, rain, irrigation, runon, evaporation or runoff;
- positive accepted qtop remains outside the bounded inundation profile.

Use the same event-aligned external-stage trajectory:

`H = [0.005, 0.020, 0.050, 0.100, 0.200, 0.300] cm`

with each event lasting `0.03125 day`.

Within each event use independently `1, 2, 4, 8` equal substeps.

## Parameter sweep

Microrelief amplitudes:

`D = [0, 0.02, 0.05, 0.10, 0.25] cm`

Surface-contact resistances:

`R_s = [0, 0.05, 0.10, 0.25, 0.50, 1.00] day`

These are mechanism probes, not calibrated or proposed production defaults.

The `R_s=0` cases must reproduce the previously persisted stage-evolution result. In particular, none of those controls may become a newly complete full trajectory.

## Recorded observables

For every `D, R_s, refinement` trajectory record:

- completion or failing event/substep;
- nonlinear iterations;
- cumulative signed top transfer;
- cumulative bottom transfer;
- total soil+local-surface storage change;
- whole-trajectory ledger residual;
- maximum accepted soil mass residual;
- final pressure/water state and local surface storage.

For adjacent temporal refinements record:

- pressure-head infinity difference;
- water-storage L1 and maximum-cell difference;
- local surface-storage difference;
- groundwater-level difference;
- cumulative top-transfer difference;
- cumulative bottom-transfer difference.

## Hard gates

Usable trajectories require:

- every solve converged;
- accepted soil mass residual <= 1e-10 cm;
- surface materializer closure <= 1e-12 cm;
- whole-trajectory ledger residual <= 1e-10 cm;
- admitted qtop sign throughout;
- exact O0/O2 numerical output identity.

## Decision rule

The finite-contact-resistance hypothesis is supported as a robust research direction only if:

1. at least two distinct nonzero microrelief amplitudes have a positive-resistance setting that completes the full six-event trajectory through 8 substeps per event;
2. for each supporting amplitude, at least two successive adjacent temporal refinement pairs are complete and show simultaneous contraction of state, cumulative top transfer and cumulative bottom transfer;
3. the supporting behavior is not an isolated single resistance point: either an adjacent tested positive resistance also completes the full trajectory, or the same resistance succeeds for at least three distinct amplitudes;
4. mass/sign gates remain closed.

Report the `D=0` resistance-only cases separately. If resistance alone repairs the flat surface, do not attribute the numerical effect uniquely to microrelief.

A positive result authorizes a separate surface-contact design and qualification step only. It does not select `D` or `R_s`, does not qualify a temporal tolerance, and does not admit TOP03 to production.
