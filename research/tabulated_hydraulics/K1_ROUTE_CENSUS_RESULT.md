# TAB-HYD K1 route census result

Date: 2026-09-23

Status: **K1 BROAD ENVELOPE BLOCKED BY ROUTE RUNTIME; NOT TABLE-FALSIFIED**

Controlling workflow:

- `TAB-HYD K1 route census`
- run `35879745205`
- conclusion: PASS as a diagnostic census

## Purpose

Classify the earlier expanded SWKIMPL=1 failure without assuming that the first timeout belonged uniquely to the analytical reference.

Three derivative-consistent routes were run independently for each of the five existing TAB-HYD envelope scenarios:

1. corrected analytical MvG;
2. bounds-safe raw-head400 table;
3. raw-head400 plus exact theta/C reuse.

Each route had an independent 120 s cap.

## Result

| scenario | analytical | raw-head | raw-head+capacity |
| --- | --- | --- | --- |
| coarse_dry_free | normal, 1.67 s | normal, 1.47 s | normal, 1.45 s |
| loam_mid_free | timeout >120 s | timeout >120 s | timeout >120 s |
| clay_wet_free | timeout >120 s | timeout >120 s | timeout >120 s |
| coarse_dry_pulse | normal, 1.62 s | normal, 1.44 s | normal, 1.45 s |
| loam_capillary | timeout >120 s | timeout >120 s | timeout >120 s |

The two coarse routes reproduce the previously observed K1 acceleration tendency.

The three difficult scenarios are not discriminating because **all three routes** fail to complete within the same bound.

## Interpretation

The earlier expanded K1 qualification failure is not evidence that the table representation loses K1 fidelity.

It is also not sufficient evidence that the table route is broadly correct for K1.

The selected five-scenario legacy-input envelope is simply not a tractable broad SWKIMPL=1 qualification authority:

- loam_mid_free: analytical, raw and raw+capacity all time out;
- clay_wet_free: all three time out;
- loam_capillary: all three time out.

Therefore no route-specific scientific comparison exists for those cases.

## Final K1 disposition for this workstream

Supported only in bounded coarse/Hupsel-like routes:

- derivative-consistent table route completes;
- coarse trajectory differences remain small;
- material runtime reductions are observed.

Not supported as a production claim:

- generic SWKIMPL=1;
- broad soil-envelope K1 qualification;
- production dK/dh admission.

Required before reopening K1:

1. an independently justified tractable K1 reference testbank, or
2. an admitted current-SWAP5 K1 production/reference authority.

Until then:

**K1_REFERENCE_ENVELOPE_RUNTIME_BLOCKED / NOT_TABLE_FALSIFIED / OUTSIDE K0 HANDOFF**

This is not a blocker for F-TAB02 generated K0 production work.
