# F-PE-PROFILE04 — initial canonical rebaseline results

Date: 2026-09-26

Measurement run: GitHub Actions `36220439795`

Status: `INITIAL_MEASUREMENT_PASS`

No production source changes.

## Setup

PLANVALID paired application setup:
- N=1,000: median candidate/base init ratio `0.794129647` (~20.6% lower);
- N=10,000: median ratio `0.331913495` (~66.8% lower);
- repeated runtime remains approximately neutral: median `0.997181068` at N=1,000 and `1.009564701` at N=10,000.

F-AHL50 direct-retention application initialization overhead relative to analytical:
- N=1: `5.782847486`;
- N=100: `1.522545495`;
- N=1,000: `1.115894884`;
- N=10,000: `1.029505412`.

Thus the shared immutable representation has approximately 3.0% setup overhead at N=10,000, while the fixed cost dominates tiny N.

## Repeated Reference / directional runtime

ZERO-WASTE paired Reference:
- mean ratio `0.726864148`;
- median ratio `0.726495766`;
- mean speedup ~27.31%.

ZERO-WASTE paired directional:
- mean ratio `0.759275664`;
- median ratio `0.761371085`;
- mean speedup ~24.07%.

These are historical-baseline paired measurements of the admitted exact-P0 stack, not yet a full MultiSWAP end-to-end speedup.

## Interpretation

The initial canonical rebaseline confirms:
1. large-N setup is no longer the dominant scaling concern after PLANVALID/B2;
2. F-AHL50 representation construction amortizes strongly at large N;
3. substantial exact repeated-runtime gains remain reproducible after canonical admission;
4. the next PROFILE04 measurement must directly compare default analytical versus F-AHL50 opt-in repeated solver/application runtime on the same canonical postimage, because the current ZERO-WASTE paired runner does not measure AHL's incremental runtime benefit.

Do not claim a total 20-35% end-to-end application speedup from this run alone.
