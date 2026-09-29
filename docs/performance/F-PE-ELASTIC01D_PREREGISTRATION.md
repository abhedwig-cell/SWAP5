# F-PE-ELASTIC01D — near-saturation descriptor hypothesis

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_DESCRIPTOR_RESULT

Parent: F-PE-ELASTIC01R.

## Motivation

The refinement showed monotone physical response for B01/B12 but non-monotone ponding convergence for O05.

A mechanistic hypothesis is that ELAS response is governed less by any one raw MvG parameter than by the relative magnitude of ELAS versus the native MvG differential capacity immediately below saturation.

## Frozen hypothesis

Define, for material m and pressure head h < 0:

`R_ELAS(h) = ELAS / C_MvG(h)`.

Hypothesis H-D1:
materials with very large `R_ELAS` near saturation are more likely to exhibit abrupt solver-path changes when the state crosses h=0 because the constitutive derivative changes sharply from native MvG capacity to ELAS.

Hypothesis H-D2:
O05 will have much larger `R_ELAS` near h=0 than B01 and B12 for ELAS around `1e-6`.

Hypothesis H-D3:
raw Ksat alone will not explain the ordering because B01 has larger Ksat than O05 but did not show the same non-monotone ponding failure pattern.

## Frozen descriptors

For B01, B12, O05 and O14 compute:

- theta_r, theta_s;
- alpha;
- n and m=1-1/n;
- Ksat;
- lambda;
- characteristic head 1/alpha;
- analytical MvG C at h = -20, -5, -1, -0.1, -0.01, -0.001 cm;
- K/Ksat at the same heads;
- R_ELAS(h) for ELAS = 1e-6.

No rule or threshold is selected before these descriptors are recorded.

## Claim boundary

This is mechanistic screening on hydraulic archetypes, not a fitted BOFEK production relation.
