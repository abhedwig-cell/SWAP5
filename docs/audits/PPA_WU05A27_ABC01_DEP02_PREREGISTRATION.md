# PPA-WU05-A27-ABC01-DEP02 preregistration — RFM full/half temporal error

Date: 2026-10-02
Status: PREREGISTERED_SHARED_BACKEND_DEPENDENCY
Baseline: `f022c90866cc4157ae5c70d7e9cb5c577500d042`

## Trigger

After DEP01, ABC01 run 36991383638 proves that RFM reaches real solver trials. Comparator C fails all 32 cases with retry exhaustion at step 1, 5 attempts, 4 retries, positive nonlinear work, zero admission/solver/mass rejections, and exactly 5 temporal rejections.

Standard macropore B completes 29/32 because it already has a continuous full/half error metric.

## Source defect

`fmr_serialized_temporal_identity()` returns zero for RFM only when the complete base state and RFM state are bit-identical, and `huge()` otherwise. RFM has no admitted model-certificate route. Nontrivial RFM evolution is therefore structurally rejected by the available full/half transaction route.

## Authorized repair

Replace only the RFM exact-identity temporal branch with a continuous full/half metric analogous to the admitted standard-macropore metric.

The metric is the maximum of absolute pressure-head difference [cm], ponding difference [cm], groundwater-level difference [cm], theta difference times dz [cm water], MB storage difference [cm], and endpoint-water difference [cm].

Require exact RFM carrier types, matching configured node count, valid matrix arrays, ready RFM states and equal endpoint count. Do not mix standard macropore, snow or thermal state.

Wall age, wall sorptivity and surface-event age are deliberately excluded from this centimetre-scale norm because they have different dimensions. Their state remains transactionally replayed and checked.

Do not change benchmark tolerance, forcing, RFM physics, storage, source ownership or retry policy.

## Qualification

Backend O0/O2 compile and A26 live-preparer preservation must pass. ABC01 C must no longer fail solely because every non-identical full/half pair maps to `huge()`. Mass failure remains hard. Standard macropore B must remain at least 29/32. Any remaining C failures are retained.

This is a branch-local repair candidate, not canonical admission.
