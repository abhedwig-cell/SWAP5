# PPA-WU05-A27-PERF07 result — state-adaptive surface sorptivity quadrature

Date: 2026-10-02
Status: QUALIFIED_APPROXIMATE_RESEARCH_CANDIDATE
Production default: NO

## Frozen policy

- h < -300 cm: 64 panels
- -300 <= h < -100 cm: 32 panels
- -100 <= h < -30 cm: 16 panels
- h >= -30 cm: 8 panels

The policy is global across soils and regimes and was frozen before trajectory execution.

## Stage 1

Run 37003772183, artifact 11224463522, digest sha256:e3abe0b016a17c522b0def0ee7cadf777cd4f2a69cdf1c33eaafcee102535954.

Across B01 and O05 at 15 pressure heads from -500 to -1 cm, maximum relative surface-sorptivity error against 64 panels is 0.811968%, at B01 h=-300 cm. This passes the preregistered <=1% gate.

## Stage 2

Run 37004153225, artifact 11225216343, digest sha256:f3f316d685a4de2365c8aa3d48cb921a9f679badc7096d7e8f3f37482f95001e.

The full 32-case ABC screen was run, which is stronger coverage than the four required representative keys:
- B completes 29/32;
- adaptive C completes 30/32;
- all 29 jointly completed B/C cases remain E1.

Against the qualified PERF02 64-panel owner artifact from run 36999473010, the four preregistered C trajectory keys show:

| key | total-storage diff cm | max sampled theta diff | nonlinear/retry change |
| --- | ---: | ---: | --- |
| R2/G1/B01 | 4.9231e-7 | 1.6385e-7 | none |
| R4/G2/B01 | 6.6562e-10 | 9.9366e-11 | none |
| R5/G1/O05 | 2.0101e-10 | 7.7382e-11 | none |
| R6/G2/O05 | 0 | 0 | none |

These are far inside the preregistered 0.02 cm storage/drainage and 0.01 theta gates. Mass residuals remain near machine precision.

## Timing

C median self-speedup relative to qualified PERF02 64-panel C:
- case 1: 1.20x;
- case 2: 1.35x;
- case 3: 1.30x;
- case 4: 1.72x.

All four cases improve, exceeding the preregistered requirement of at least three.

Within the adaptive run:
- case 1: C is about 1.24x faster than B;
- case 2: C remains about 2.22x slower than B;
- case 3: C is about 1.02x faster than B;
- case 4: C remains about 1.16x slower than B.

CI timing is machine-specific; these ratios are research evidence, not portable production guarantees.

## Decision

PERF07 passes its preregistered research gates and is a qualified approximate-mode candidate.

It is not exact-preserving and is not made the production default by A27. The temporary adaptive patch is reverted after evidence capture so the branch production authority returns to qualified PERF02.

A production approximate mode would need an explicit opt-in configuration, persisted mode semantics, broader soil/state qualification and canonical admission.
