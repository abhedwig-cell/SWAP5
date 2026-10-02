# TOP03 microrelief surface-contact hypothesis

Date: 2026-10-02
Status: PREREGISTERED_RESEARCH_ONLY
Starting TOP03 head: `ff6dfe975aec4885e3c0f6ace59b16e5d3b404d7`
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Motivation

The current bounded external-inundation route activates a full-area imposed-head boundary as soon as the external surface-water stage exceeds the flooding sill. For the real FAPP09 fixture this produces a large dry-to-wet transient. The subsequent full/half refinement evidence is non-contracting and cannot justify a finite BASE temporal tolerance.

Earlier TOP03 research showed that merely making the external head rise gradually is not a sufficient repair. This work therefore tests a different physical hypothesis: an unresolved soil surface is not a perfectly flat plane. At shallow external stages only part of the surface is in hydraulic contact with surface water, while the remaining area is exposed to air. The areal hydraulic contact and local surface-water storage should increase continuously with stage.

This is a physical surface-representation experiment, not a numerical acceptance relaxation.

## Microrelief model

Let the unresolved surface elevation `zeta` be uniformly distributed over `[0,D]`, where `D` is a microrelief amplitude in cm and the external water stage relative to the lowest contact level is `H >= 0`.

For `D > 0`:

```
f_wet(H,D) = min(1, H/D)
```

For `0 < H < D`, the wet-area mean local water depth and total-area surface storage are

```
h_wet_mean = H/2
S_surface   = H^2/(2D)
```

For `H >= D`:

```
h_wet_mean = H - D/2
S_surface   = H - D/2
```

The sharp flat-surface limit `D=0` is defined as

```
f_wet       = 1
h_wet_mean  = H
S_surface   = H
```

so the existing imposed-head formulation is an exact limiting control.

## Areal hydraulic boundary

Within the research model the top-node state remains a single areal-mean matrix state. The dry fraction carries zero atmospheric flux in this zero-rain/zero-evaporation fixture. The wet fraction obeys the same Darcy contact law as the existing external-head route.

Because the current saturated-face law is linear in surface head for fixed top-node state, the areal-average wet-contact flux can be represented exactly under this homogenization as

```
K_contact = f_wet * K_face
q_top = -K_contact * ((h_wet_mean - h_top)/d_top + 1)
```

where `K_face` is the same saturated/top-node face conductivity used by the existing external route.

This is a finite-contact/Robin interpretation. It is not an interpolation between two accepted solutions and it does not change the constitutive soil law.

The candidate local surface storage is `S_surface`, not the external stage `H`. The external system remains the owner of the represented larger surface-water body. As in current TOP03, any later production design must prevent duplicate ownership of the same surface-water volume.

## Fixed fixture

The experiment keeps the actual TOP03 problem fixed except for the surface geometry hypothesis:

- same `MOD_grid` column;
- same B1.10 MVG parameters;
- initial pressure head -123 cm;
- initial groundwater level -2.25 cm;
- initial local surface storage 0;
- external stage `H = 0.02 cm`;
- bottom mode 7 and the same initial conductivity-derived bottom flux;
- Reference Richards;
- max 80 nonlinear iterations, max 16 backtracking attempts;
- no root extraction, drainage response, macropore, snow, thermal, evaporation, precipitation, irrigation, runon or runoff;
- no positive accepted qtop.

The lower boundary and initial soil state must not be changed to obtain convergence.

## Parameter sweep

Test microrelief amplitudes

`D = 0, 0.02, 0.05, 0.10, 0.25 cm`.

`D=0` is the exact sharp-boundary control. The other values are mechanism probes, not calibrated field parameters.

For each D test independent same-origin windows

`0.25, 0.125, 0.0625, 0.03125 day`

with

`1, 2, 4, 8, 16` equal substeps.

## Recorded observables

For each path:

- solve completion and failure step;
- nonlinear iterations;
- wet fraction, mean wet head and local surface storage;
- integrated signed external top transfer;
- integrated bottom transfer;
- soil+local-surface storage change;
- whole-path ledger residual;
- maximum accepted soil mass residual.

For each adjacent complete refinement pair:

- pressure-head infinity difference;
- water-storage L1 difference;
- maximum cell water-storage difference;
- local surface-storage difference;
- groundwater-level difference;
- integrated top-transfer difference;
- integrated bottom-transfer difference.

## Hard gates

Every usable path must retain:

- soil mass residual <= 1e-10 cm per accepted solve;
- post-solve surface closure <= 1e-12 cm;
- whole-path soil+local-surface ledger residual <= 1e-10 cm;
- admitted inundation sign;
- exact O0/O2 numerical output identity.

The `D=0` control must reproduce the sharp-boundary research trajectory at the same discretization within roundoff. Failure of that control invalidates interpretation of the microrelief comparison.

## Decision rule

The hypothesis is **supported as a numerical/physical research direction**, not production-qualified, only if at least one nonzero D:

1. supplies at least three successive complete refinement levels for a tested window;
2. shows contraction in state, integrated top transfer and integrated bottom transfer across at least two successive adjacent refinement pairs;
3. preserves the hard mass and sign gates;
4. does not rely on changing the lower boundary or initial soil state.

The hypothesis is falsified as a sufficient TOP03 prerequisite if no nonzero D meets those conditions.

A positive result authorizes a separate design/qualification step for surface geometry and ownership. It does not authorize production admission, a new temporal tolerance, or canonical merge.
