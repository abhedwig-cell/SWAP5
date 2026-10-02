# PPA-WU05-A27-ABC01 result — current production RFM versus standard macropore

Date: 2026-10-02  
Status: SCREEN_COMPLETED; RFM_RUNTIME_STABILITY_BLOCKED; NO_SPEEDUP_CLAIM

Preregistration: `docs/audits/PPA_WU05A27_ABC01_PREREGISTRATION.md`  
Production screen run: `36991919530`  
Screen postimage: `41daf2c62f9c74a0310a1443f1cf92000c7565d3`  
Evidence artifact: `11220260500`  
Artifact digest: `sha256:4d48cce68c030c09658dc5465cc9ba13ab0f7de521601d63ea6236cfb986ab2e`

## Comparator validity

Comparator B is the current standard macropore serialized Reference route. Comparator C is the admitted A26 RFM route plus the DEP01 live-layout reachability repair. No A27 pressure-aware research code is present in C.

Comparator A, as initially preregistered, is **not a valid matrix-only comparator in this screen**. The ordinary base physical carrier's external full/half temporal hook accepts only bit-identical states. Thirty of 32 A records therefore fail on temporal rejection at the first interval; the two wettest fail on the solver. This is a benchmark-policy mismatch, not evidence that Reference Richards generally cannot run those cases. A must be rerun later through a qualified matrix Reference temporal route.

The B/C conclusions below do not use A.

## B/C completion envelope

The screen contains 2 soils x 2 geometries x 8 regimes = 32 B/C keys.

- B completes 29/32.
- C completes 8/32.
- Every B/C key where both complete is E1 under the preregistered thresholds: 8/8.
- Corrected classification of the full screen is 8 E1, 21 C_RUNTIME_FAILED and 3 B_RUNTIME_FAILED.
- No C failure is an admission failure after DEP01.

C completes only:
- R4 long moderate rainfall;
- R6 continuous low flow;

for both soils and both geometries.

C fails in R1, R2, R3, R5, R7 and R8. All 24 C failures have solver rejections and zero admission, temporal and mass rejections.

For pulsed regimes R1/R2, R5 and R7/R8, C fails respectively on steps 5, 4 and 9: exactly the first interval after the rainfall pulse stops. R3 is the separate near-saturated storm case and fails during the wet phase.

This pattern is consistent across soils and geometries. It identifies wet-to-dry continuation with stored terminating-endpoint water as the next stability target. It does not yet prove endpoint release is the sole cause.

## Hydrologic agreement where both routes complete

Across the eight E1 overlap cases:

- final total-storage difference: 6.54e-5 to 2.78e-3 cm, median 4.67e-4 cm;
- total-drainage difference: 6.54e-5 to 2.78e-3 cm, median 4.67e-4 cm;
- maximum sampled theta difference: 9.45e-5 to 1.97e-3, median 5.65e-4.

These results support bounded hydrologic similarity only for the low/moderate continuous-forcing cases that both implementations complete. They do not establish equivalence in the failed pulse or wet regimes.

## Performance

On the eight successful B/C screen cases, C wall time is 3.69x to 5.18x B, median 4.36x.

The preregistered repeated timing set has only two cases where C completes all repetitions:

- B01 / G2 / R4: B median 0.003122 s, C median 0.015486 s, so C is about 4.96x slower;
- O05 / G2 / R6: B median 0.002864 s, C median 0.011563 s, so C is about 4.04x slower.

Nonlinear iteration counts are nearly identical in these successful cases. The measured slowdown therefore is not explained by extra Richards iterations. Source inspection identifies a zero-waste candidate: the live RFM wall-hydraulic binder evaluates MB wall sorptivity on every step even though the A26 production composer treats leading MB as fast-through and does not consume the MB wall-sorptivity result. This is an attribution candidate, not yet a measured decomposition.

The RFM configuration here uses 64 sorptivity panels as preregistered. Timing is CI-machine-specific and does not establish a portable factor.

## Production interpretation

The original A27 proposition is not supported by this screen in its present form.

Current production RFM is hydrologically close to standard macropore in the narrow regimes where it completes, but:
- its completion envelope is much narrower in this stress screen;
- pulsed wet-to-dry continuation is a repeatable solver blocker;
- it is substantially slower than B in the successful timing cases under the fixed 64-panel configuration.

No production speedup, stability advantage, E1 production envelope or canonical A27 admission is claimed.

## Next experiment

Before pressure-aware wall research or parameter tuning, isolate the RFM first-dry-step source transition from a successfully accepted wet trajectory. The diagnostic should retain the production accepted state and quantify:
- endpoint storage and wall age at rain cessation;
- exact endpoint-to-matrix release amount/rate;
- Reference solve with the production release source;
- a no-release diagnostic solve from the same matrix state;
- a fixed source-scale ladder for attribution only.

Separately, performance attribution should measure the cost of surface/endpoint/unused-MB sorptivity quadrature without changing ABC01.
