# PPA-WU05-A27-PERF06 preregistration — approximate sorptivity panel frontier

Date: 2026-10-02
Status: PREREGISTERED_APPROXIMATE_RESEARCH
Parent: `7d0a22d895263f5589a742cc4ffd5e23da651652`

Exact-preserving PERF02 is qualified. PERF04 exact caching was rejected because it added complexity without measurable end-to-end benefit. PERF06 therefore opens the approximate-performance phase explicitly.

Question: can the current 64-panel RFM sorptivity quadrature be reduced materially while preserving the hydrologic response needed for coupled MultiSWAP use?

Stage 1, constitutive frontier:
- panel counts 64, 32, 16, 8;
- B01 and O05;
- node pressure heads -10000,-3000,-1000,-300,-100,-30,-10,-3,-1 cm;
- actual default-MvG provider;
- surface/node sorptivity only;
- 64 panels is the comparator, not mathematical ground truth.

Record absolute and relative S error and direct timing.

Admission to trajectory stage:
- maximum relative S error <= 2% for 32/16/8 candidate, excluding states where |S64|<1e-10;
- no invalid/nonfinite result.

Stage 2, only candidates passing Stage 1:
- representative ABC keys R2/G1/B01, R4/G2/B01, R5/G1/O05, R6/G2/O05;
- same production C route and all other parameters unchanged;
- compare final storage, drainage, sampled theta, completion and mass closure to the qualified 64-panel PERF02 comparator;
- require mass residual <=1e-6 cm;
- require E1 thresholds from ABC01;
- report timing over five repetitions.

A candidate may be called promising only if it remains E1 in all four representative keys and gives a measurable median C speedup on at least three of four keys. No canonical or production admission follows from PERF06.

Do not tune panel count by regime or soil. One global candidate only.
