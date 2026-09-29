# F-PE-ELASTIC01D — near-saturation descriptor result

Date: 2026-09-29

Status: MECHANISTIC_DESCRIPTOR_HYPOTHESIS_SUPPORTED

## Method correction

The descriptor calculation uses the exact B1.10 default-MvG capacity semantics, including the near-saturation continuation at `Hcrit = -0.01 cm`.

For the current BOFEK screening fixtures `h_enpr = 0`, so:

- at and below `Hcrit`, use the analytical MvG capacity;
- for `-0.01 < h < 0`, use the B1.10 constant linear-continuation slope `c27`;
- at `h >= 0`, ELAS-on uses `C = ELAS`.

This supersedes any descriptor number computed from an unmodified textbook MvG derivative inside `(-0.01,0)`.

## Material descriptors

For ELAS = `1e-6`, define `R = ELAS / C_native(h)`.

### B01

- alpha = 0.021659 1/cm
- n = 1.734737
- Ksat = 31.225016 cm/d
- lambda = 0.98087
- 1/alpha = 46.17 cm
- C(-1 cm) = 3.87456e-4 1/cm; R = 2.58e-3
- C(-0.1 cm) = 7.14943e-5 1/cm; R = 1.40e-2
- C(-0.01 cm) = 1.31689e-5 1/cm; R = 7.59e-2
- B1.10 near-saturation continuation C(-0.001 cm) = 7.59129e-6 1/cm; R = 1.317e-1

### B12

- alpha = 0.016562 1/cm
- n = 1.090671
- Ksat = 2.245895 cm/d
- lambda = -4.493581
- 1/alpha = 60.38 cm
- C(-1 cm) = 5.31568e-4 1/cm; R = 1.88e-3
- C(-0.1 cm) = 4.36308e-4 1/cm; R = 2.29e-3
- C(-0.01 cm) = 3.54424e-4 1/cm; R = 2.82e-3
- B1.10 near-saturation continuation C(-0.001 cm) = 3.24972e-4 1/cm; R = 3.08e-3

### O05

- alpha = 0.030304 1/cm
- n = 2.887502
- Ksat = 17.418504 cm/d
- lambda = 0.0736
- 1/alpha = 33.00 cm
- C(-1 cm) = 2.54294e-5 1/cm; R = 3.93e-2
- C(-0.1 cm) = 3.29506e-7 1/cm; R = 3.03
- C(-0.01 cm) = 4.26935e-9 1/cm; R = 234.2
- B1.10 near-saturation continuation C(-0.001 cm) = 1.47856e-9 1/cm; R = 676.3

### O14

O14 dynamic holdout cases remain unopened. Only its already-preregistered material parameters are used here.

- alpha = 0.003288 1/cm
- n = 1.616573
- Ksat = 2.495984 cm/d
- lambda = 0.514012
- 1/alpha = 304.14 cm
- C(-1 cm) = 2.29118e-5 1/cm; R = 4.36e-2
- C(-0.1 cm) = 5.54042e-6 1/cm; R = 1.80e-1
- C(-0.01 cm) = 1.33959e-6 1/cm; R = 0.746
- B1.10 near-saturation continuation C(-0.001 cm) = 8.28658e-7 1/cm; R = 1.207

## Interpretation

H-D1 and H-D2 are supported by the screening evidence.

O05 is qualitatively different from B01 and B12: for ELAS around `1e-6`, the activated saturated capacity is hundreds of times larger than the native B1.10 capacity immediately below saturation. Crossing h=0 therefore introduces a very large constitutive-derivative jump.

This provides a concrete mechanism for the observed O05/POND solver-path transitions and non-monotone convergence.

B12 is the opposite extreme: native near-saturation capacity remains much larger than ELAS, so turning on ELAS changes the derivative only weakly. That matches the smooth response and absence of solver-work benefit.

B01 is intermediate: ELAS is a noticeable but not dominant fraction of near-saturation native capacity. This is consistent with its smooth physical response and large ponding-work reduction without the O05 convergence gaps.

H-D3 is also supported descriptively: Ksat ordering does not match the numerical-behaviour ordering. B01 has higher Ksat than O05 but does not show O05's non-monotone failure band.

## Candidate explanatory variable

The leading mechanistic descriptor is therefore not a raw soil parameter but a dimensionless near-saturation contrast such as

`R_crit = ELAS / C_native(Hcrit+)`

or an equivalent measure based on the B1.10 near-saturation continuation.

This does not yet define a production rule. It identifies the quantity that should be tested on a larger material population.

## Important O14 prediction boundary

Because O14 has `R` near unity very close to saturation, it is prospectively informative for falsifying the descriptor hypothesis. Its dynamic holdout cases remain unopened until a candidate response classification is frozen.
